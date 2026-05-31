#!/bin/bash
# =============================================================================
# harness/on-task-done.sh <task_id>
# .done 파일 생성 시 watch-notify.sh가 호출
# 순수 쉘로 phase 전환 처리 — Claude 토큰 소모 없음
#
# 담당:
#   1. task 정보 읽기 (tasks/ 또는 archive/)
#   2. Orchestrator pane에 Slack 알림 위임 (최소 1회 MCP 호출)
#   3. 다음 phase task 자동 생성 + 에이전트 pane에 dispatch
# =============================================================================

TASK_ID="${1:-}"
[[ -z "$TASK_ID" ]] && { echo "사용법: bash on-task-done.sh <task_id>"; exit 1; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PROJECT_ROOT/harness"
TASKS_DIR="$HARNESS_DIR/workspace/tasks"
ARCHIVE_DIR="$HARNESS_DIR/workspace/archive"
RESULTS_DIR="$HARNESS_DIR/workspace/results"
NOTIFY_DIR="$HARNESS_DIR/workspace/notify"
SESSION="vue-pkg"

# ── pane 맵 ──────────────────────────────────────────────────────────────────
pane_for() {
  case "$1" in
    orchestrator) echo 0 ;;
    architect)    echo 1 ;;
    implementer)  echo 2 ;;
    planner)      echo 3 ;;
    designer)     echo 4 ;;
    reviewer)     echo 5 ;;
    *)            echo ""  ;;
  esac
}

# ── tmux dispatch ─────────────────────────────────────────────────────────────
dispatch() {
  local pane="$1"
  local msg="$2"
  tmux send-keys -t "$SESSION:agents.$pane" "$msg" Enter
}

# ── task 파일 찾기 ─────────────────────────────────────────────────────────────
TASK_FILE="$TASKS_DIR/${TASK_ID}.json"
[[ ! -f "$TASK_FILE" ]] && TASK_FILE="$ARCHIVE_DIR/${TASK_ID}.json"
if [[ ! -f "$TASK_FILE" ]]; then
  echo "⚠️  [on-task-done] task 파일 없음: $TASK_ID"
  exit 1
fi

ASSIGNED_TO=$(jq -r '.assigned_to // ""' "$TASK_FILE")
TITLE=$(jq -r '.title // ""' "$TASK_FILE")

echo "✅ [on-task-done] $(date +%H:%M:%S) $TASK_ID (→ $ASSIGNED_TO)"

# ── Orchestrator에 Slack 알림 위임 (단 1회 MCP 호출) ─────────────────────────
dispatch 0 "#canvue 채널에 Slack 전송해줘 (짧게): ✅ \`$TASK_ID\` 완료 — $TITLE"

# ── Reviewer 완료 처리 ────────────────────────────────────────────────────────
if [[ "$ASSIGNED_TO" == "reviewer" ]]; then
  RESULT_FILE="$RESULTS_DIR/${TASK_ID}.md"

  if grep -q "APPROVED" "$RESULT_FILE" 2>/dev/null; then
    echo "🎉 [on-task-done] APPROVED — 전체 완료"
    dispatch 0 "#canvue 채널에 Slack 전송해줘: 🎉 *Phase 3 완료 — APPROVED* 배포 준비 완료."

  elif grep -q "CHANGES_REQUESTED" "$RESULT_FILE" 2>/dev/null; then
    echo "🔄 [on-task-done] CHANGES_REQUESTED — Implementer 수정 task 생성"
    TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
    # 기존 fix task 수 기반으로 ID 생성
    FIX_COUNT=$(ls "$TASKS_DIR"/task_fix_*.json 2>/dev/null | wc -l | tr -d ' ')
    FIX_ID="task_fix_$(printf '%03d' $((FIX_COUNT + 1)))"

    cat > "$TASKS_DIR/${FIX_ID}.json" << EOF
{
  "task_id": "$FIX_ID",
  "assigned_to": "implementer",
  "priority": "high",
  "status": "pending",
  "title": "Reviewer CHANGES_REQUESTED 수정 ($(date +%m/%d))",
  "description": "Reviewer의 지적 사항을 수정하라. 리뷰 결과 파일을 먼저 읽고 Critical 항목부터 처리해.",
  "context_refs": [
    "$RESULT_FILE",
    "harness/workspace/shared/interfaces.md",
    "harness/workspace/shared/decisions.md"
  ],
  "expected_output": "Critical 항목 전부 수정 + 빌드/테스트 통과 + harness/workspace/results/${FIX_ID}.md 작성",
  "created_at": "$TIMESTAMP"
}
EOF

    dispatch 2 "harness/workspace/tasks/${FIX_ID}.json 읽고 즉시 수정 시작해줘."
    dispatch 0 "#canvue 채널에 Slack 전송해줘: 🔄 *CHANGES_REQUESTED* — Implementer에게 수정 task 생성됨 (\`${FIX_ID}\`)"
  fi

  exit 0
fi

# ── Phase 1 완료 감지 (architect + planner + designer) ─────────────────────────
# Phase 1 task는 아카이브에 있으므로 archive/에서 done 상태 확인
phase1_agents=("architect" "planner" "designer")
phase1_done=0

for role in "${phase1_agents[@]}"; do
  # tasks/ 또는 archive/ 에서 해당 role의 task가 done인지 확인
  for dir in "$TASKS_DIR" "$ARCHIVE_DIR"; do
    for f in "$dir"/task_*.json; do
      [[ -f "$f" ]] || continue
      file_role=$(jq -r '.assigned_to // ""' "$f" 2>/dev/null)
      file_status=$(jq -r '.status // ""' "$f" 2>/dev/null)
      if [[ "$file_role" == "$role" ]] && [[ "$file_status" == "done" ]]; then
        phase1_done=$((phase1_done + 1))
        break 2
      fi
    done
  done
done

if [[ "$phase1_done" -ge 3 ]]; then
  # Phase 2 task가 아직 없으면 생성
  impl_exists=$(ls "$TASKS_DIR"/task_impl_*.json 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$impl_exists" -eq 0 ]]; then
    echo "▶ [on-task-done] Phase 1 완료 → Phase 2 task 생성"
    TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
    cat > "$TASKS_DIR/task_impl_001.json" << EOF
{
  "task_id": "task_impl_001",
  "assigned_to": "implementer",
  "priority": "high",
  "status": "pending",
  "title": "Phase 2: 핵심 컴포넌트 구현",
  "description": "Phase 1 결과물 기반으로 구현 시작. shared/ 파일 모두 참고.",
  "context_refs": [
    "harness/workspace/shared/decisions.md",
    "harness/workspace/shared/roadmap.md",
    "harness/workspace/shared/interfaces.md"
  ],
  "expected_output": "src/ 하위 컴포넌트 구현 및 테스트 완료. harness/workspace/results/task_impl_001.md 작성",
  "created_at": "$TIMESTAMP"
}
EOF
    dispatch 2 "harness/workspace/tasks/task_impl_001.json 읽고 즉시 구현 시작해줘."
    dispatch 0 "#canvue 채널에 Slack 전송해줘: ▶ *Phase 1 완료 → Phase 2 시작* Implementer 구현 task 생성됨."
  fi
  exit 0
fi

# ── Phase 2 완료 감지 (모든 implementer task done) ─────────────────────────────
if [[ "$ASSIGNED_TO" == "implementer" ]]; then
  # 아직 pending/in_progress 상태인 implementer task가 있으면 대기
  remaining=$(grep -rl '"assigned_to": "implementer"' "$TASKS_DIR" 2>/dev/null \
    | xargs -I{} jq -r '.status' {} 2>/dev/null \
    | grep -c 'pending\|in_progress' || echo 0)

  if [[ "$remaining" -eq 0 ]]; then
    # Phase 3 reviewer task가 아직 없으면 생성
    review_exists=$(ls "$TASKS_DIR"/task_review_*.json 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$review_exists" -eq 0 ]]; then
      echo "▶ [on-task-done] Phase 2 완료 → Phase 3 (Reviewer) task 생성"
      TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
      # 가장 최근 implementer task들 참조
      LATEST_RESULTS=$(ls "$RESULTS_DIR"/task_impl_*.md 2>/dev/null | tail -3 | tr '\n' ',' | sed 's/,$//')

      cat > "$TASKS_DIR/task_review_001.json" << EOF
{
  "task_id": "task_review_001",
  "assigned_to": "reviewer",
  "priority": "high",
  "status": "pending",
  "title": "Phase 3: 코드 리뷰 및 QA",
  "description": "Phase 2 구현 결과물 전체를 리뷰하라. APPROVED 또는 CHANGES_REQUESTED 판정.",
  "context_refs": [
    "harness/workspace/shared/interfaces.md",
    "harness/workspace/shared/decisions.md"
  ],
  "expected_output": "harness/workspace/results/task_review_001.md — 판정 및 항목별 코멘트",
  "created_at": "$TIMESTAMP"
}
EOF
      dispatch 5 "harness/workspace/tasks/task_review_001.json 읽고 즉시 리뷰 시작해줘."
      dispatch 0 "#canvue 채널에 Slack 전송해줘: ▶ *Phase 2 완료 → Phase 3 시작* Reviewer 리뷰 task 생성됨."
    fi
  fi
fi
