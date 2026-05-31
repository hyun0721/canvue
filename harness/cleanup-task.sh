#!/bin/bash
# =============================================================================
# harness/cleanup-task.sh
# task 완료 후 관련 파일(notify, chat 메시지, task JSON) 정리
#
# 사용법:
#   bash harness/cleanup-task.sh <task_id>        # 특정 task 정리
#   bash harness/cleanup-task.sh --all            # done 상태 task 전체 정리
#   bash harness/cleanup-task.sh --dry-run        # 삭제 대상만 미리 확인
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PROJECT_ROOT/harness"
TASKS_DIR="$HARNESS_DIR/workspace/tasks"
NOTIFY_DIR="$HARNESS_DIR/workspace/notify"
RESULTS_DIR="$HARNESS_DIR/workspace/results"
CHAT_FILE="$HARNESS_DIR/workspace/chat/channel.md"
ARCHIVE_DIR="$HARNESS_DIR/workspace/archive"

DRY_RUN=false
MODE="single"
TASK_ID=""

# ── 인자 파싱 ────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --all)     MODE="all" ;;
    task_*)    TASK_ID="$arg" ;;
  esac
done

[[ "$MODE" == "single" && -z "$TASK_ID" ]] && {
  echo "사용법:"
  echo "  bash harness/cleanup-task.sh <task_id>     # 특정 task"
  echo "  bash harness/cleanup-task.sh --all         # 완료된 task 전체"
  echo "  bash harness/cleanup-task.sh --dry-run --all  # 삭제 대상 미리 확인"
  exit 1
}

# ── 함수 ─────────────────────────────────────────────────────────────────────
log()     { echo -e "\033[0;32m▶\033[0m $1"; }
warn()    { echo -e "\033[1;33m⚠\033[0m  $1"; }
drylog()  { echo -e "\033[0;36m[dry-run]\033[0m $1"; }

do_remove() {
  local target="$1"
  if [[ "$DRY_RUN" == true ]]; then
    drylog "삭제 예정: $target"
  else
    rm -f "$target" && log "삭제: $(basename $target)"
  fi
}

do_archive() {
  local target="$1"
  local dest="$ARCHIVE_DIR/$(basename $target)"
  if [[ "$DRY_RUN" == true ]]; then
    drylog "아카이브 예정: $target → archive/"
  else
    mkdir -p "$ARCHIVE_DIR"
    mv "$target" "$dest" && log "아카이브: $(basename $target)"
  fi
}

# channel.md에서 특정 msg_id 블록 삭제
clean_channel_msgs() {
  local task_id="$1"
  [[ -f "$CHAT_FILE" ]] || return

  # task_id가 context로 언급된 메시지 블록 추출 후 삭제
  # 블록 구조: [AGENT] msg_id: msg_XXX ~ 다음 [AGENT] 또는 EOF
  local tmp_file=$(mktemp)
  python3 - "$CHAT_FILE" "$task_id" "$tmp_file" << 'PYEOF'
import sys, re

chat_file = sys.argv[1]
task_id   = sys.argv[2]
out_file  = sys.argv[3]

with open(chat_file, 'r') as f:
    content = f.read()

# [AGENT] msg_id: ... 블록 단위로 분리
blocks = re.split(r'(?=\n\[)', content)
kept = []
removed = 0

for block in blocks:
    # task_id가 포함된 블록은 제거
    if task_id in block:
        removed += 1
    else:
        kept.append(block)

with open(out_file, 'w') as f:
    f.write(''.join(kept))

print(f"channel.md: {removed}개 메시지 블록 제거")
PYEOF

  if [[ "$DRY_RUN" == true ]]; then
    drylog "channel.md에서 ${task_id} 관련 메시지 블록 제거 예정"
    rm -f "$tmp_file"
  else
    mv "$tmp_file" "$CHAT_FILE"
  fi
}

# ── 단일 task 정리 ────────────────────────────────────────────────────────────
cleanup_task() {
  local tid="$1"
  local task_file="$TASKS_DIR/${tid}.json"

  echo ""
  echo "━━━ $tid 정리 시작 ━━━"

  # task JSON 상태 확인
  if [[ -f "$task_file" ]]; then
    status=$(grep '"status"' "$task_file" | grep -oE '"[a-z_]+"' | tail -1 | tr -d '"')
    if [[ "$status" != "done" ]]; then
      warn "$tid 상태가 '$status'예요. done 상태만 정리 가능해요."
      warn "강제 정리하려면 먼저 status를 done으로 변경하세요."
      return 1
    fi
  else
    warn "$tid task 파일이 없어요: $task_file"
  fi

  # 1. notify 파일 삭제
  do_remove "$NOTIFY_DIR/${tid}.done"

  # 2. task JSON 아카이브
  [[ -f "$task_file" ]] && do_archive "$task_file"

  # 3. result 파일 아카이브
  for result in "$RESULTS_DIR"/${tid}*.md; do
    [[ -f "$result" ]] && do_archive "$result"
  done

  # 4. channel.md 관련 메시지 정리
  clean_channel_msgs "$tid"

  echo "━━━ $tid 정리 완료 ━━━"
}

# ── 전체 정리 ────────────────────────────────────────────────────────────────
cleanup_all() {
  echo ""
  log "done 상태 task 전체 정리 시작"

  local count=0
  for task_file in "$TASKS_DIR"/*.json; do
    [[ -f "$task_file" ]] || continue
    status=$(grep '"status"' "$task_file" | grep -oE '"[a-z_]+"' | tail -1 | tr -d '"')
    if [[ "$status" == "done" ]]; then
      tid=$(basename "$task_file" .json)
      cleanup_task "$tid"
      count=$((count + 1))
    fi
  done

  [[ "$count" -eq 0 ]] && warn "정리할 done 상태 task가 없어요."
  [[ "$count" -gt 0 ]] && log "총 ${count}개 task 정리 완료"
}

# ── 실행 ─────────────────────────────────────────────────────────────────────
[[ "$DRY_RUN" == true ]] && echo -e "\033[0;36m[dry-run 모드] 실제 삭제 없이 대상만 표시해요\033[0m"

if [[ "$MODE" == "all" ]]; then
  cleanup_all
else
  cleanup_task "$TASK_ID"
fi

echo ""
log "archive 위치: $ARCHIVE_DIR"
