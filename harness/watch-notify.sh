#!/bin/bash
# =============================================================================
# harness/watch-notify.sh
# notify/ 디렉토리를 fswatch로 감시 — .done 파일 생성 시 on-task-done.sh 호출
# Claude 폴링 루프 없이 이벤트 기반으로 phase 전환 처리
#
# 사용법: bash harness/watch-notify.sh   (start.sh에서 백그라운드 실행)
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PROJECT_ROOT/harness"
NOTIFY_DIR="$HARNESS_DIR/workspace/notify"

mkdir -p "$NOTIFY_DIR"

# 이미 처리한 task_id 추적 — fswatch 중복 이벤트 방지
PROCESSED="$HARNESS_DIR/workspace/.processed_done"
touch "$PROCESSED"

echo "🔍 [watch-notify] notify/ 감시 시작 (fswatch) — PID $$"

fswatch -0 --event Created --event Renamed "$NOTIFY_DIR" \
| while IFS= read -r -d '' event; do
  filename=$(basename "$event")

  # .done 파일만 처리
  [[ "$filename" == *.done ]] || continue

  task_id="${filename%.done}"

  # 중복 이벤트 방지: 이미 처리한 task_id 스킵
  if grep -qxF "$task_id" "$PROCESSED" 2>/dev/null; then
    echo "⏭  [watch-notify] 중복 이벤트 스킵: $task_id"
    continue
  fi
  echo "$task_id" >> "$PROCESSED"

  echo "📬 [watch-notify] $(date +%H:%M:%S) .done 감지: $task_id"
  bash "$HARNESS_DIR/on-task-done.sh" "$task_id"
done
