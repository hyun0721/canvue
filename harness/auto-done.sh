#!/bin/bash
# =============================================================================
# harness/auto-done.sh
# PostToolUse hook — Write/Edit 도구로 result 파일 저장 시 자동으로 .done 생성
# stdin으로 Claude Code hook JSON 페이로드를 받음
#
# 처리 대상: harness/workspace/results/task_*.md
# Reviewer 특이사항:
#   - APPROVED     → .done 생성 (Phase 전환 트리거)
#   - CHANGES_REQUESTED / BLOCKED → .done 생성 안 함
#     (on-task-done.sh에서 수정 task 자동 생성됨)
# 다른 에이전트:
#   - 결과 파일 저장 즉시 .done 생성
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PROJECT_ROOT/harness"
NOTIFY_DIR="$HARNESS_DIR/workspace/notify"
TASKS_DIR="$HARNESS_DIR/workspace/tasks"

# stdin에서 hook 페이로드 읽기
PAYLOAD=$(cat)

# tool_name 확인 (Write 또는 Edit만 처리)
TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // ""' 2>/dev/null)
[[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]] || exit 0

# file_path 추출
FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# results/task_*.md 패턴인지 확인
if [[ "$FILE_PATH" != */harness/workspace/results/task_*.md ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")
TASK_ID="${FILENAME%.md}"
DONE_FILE="$NOTIFY_DIR/${TASK_ID}.done"

# 이미 .done이 있으면 스킵
[[ -f "$DONE_FILE" ]] && exit 0

# task의 assigned_to 확인
TASK_FILE="$TASKS_DIR/${TASK_ID}.json"
if [[ ! -f "$TASK_FILE" ]]; then
  # archive에서도 찾기
  TASK_FILE="$HARNESS_DIR/workspace/archive/${TASK_ID}.json"
fi

ASSIGNED_TO=""
[[ -f "$TASK_FILE" ]] && ASSIGNED_TO=$(jq -r '.assigned_to // ""' "$TASK_FILE" 2>/dev/null)

# Reviewer: 결과 파일의 판정에 따라 .done 생성 여부 결정
if [[ "$ASSIGNED_TO" == "reviewer" ]]; then
  # APPROVED 포함 시에만 .done 생성
  if grep -q "APPROVED" "$FILE_PATH" 2>/dev/null && ! grep -q "CHANGES_REQUESTED\|BLOCKED" "$FILE_PATH" 2>/dev/null; then
    mkdir -p "$NOTIFY_DIR"
    touch "$DONE_FILE"
    echo "🔔 [auto-done] APPROVED 판정 감지 → $TASK_ID.done 생성"
  else
    echo "⏭  [auto-done] Reviewer 미승인(CHANGES_REQUESTED/BLOCKED) — .done 생성 안 함"
  fi
else
  # 다른 에이전트: 결과 파일 저장 즉시 .done 생성
  mkdir -p "$NOTIFY_DIR"
  touch "$DONE_FILE"
  echo "🔔 [auto-done] $TASK_ID.done 생성 ($ASSIGNED_TO)"
fi

# task JSON status도 done으로 업데이트
if [[ -f "$TASKS_DIR/${TASK_ID}.json" ]]; then
  sed -i.bak 's/"status": "in_progress"/"status": "done"/' "$TASKS_DIR/${TASK_ID}.json"
  sed -i.bak 's/"status": "pending"/"status": "done"/'     "$TASKS_DIR/${TASK_ID}.json"
  rm -f "$TASKS_DIR/${TASK_ID}.json.bak"
fi
