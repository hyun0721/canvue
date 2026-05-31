#!/bin/bash
# =============================================================================
# harness/watch-channel.sh
# channel.md 변경 시 mention-watcher.sh 호출
# Orchestrator 루프의 mention 감시를 이벤트 기반으로 대체
#
# 사용법: bash harness/watch-channel.sh   (start.sh에서 백그라운드 실행)
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PROJECT_ROOT/harness"
CHANNEL="$HARNESS_DIR/workspace/chat/channel.md"

# channel.md가 없으면 생성
mkdir -p "$(dirname "$CHANNEL")"
[[ -f "$CHANNEL" ]] || touch "$CHANNEL"

echo "📡 [watch-channel] channel.md 감시 시작 (fswatch) — PID $$"

fswatch -0 --event Updated --event Created "$CHANNEL" \
| while IFS= read -r -d '' event; do
  echo "💬 [watch-channel] $(date +%H:%M:%S) channel.md 변경 감지"
  bash "$HARNESS_DIR/mention-watcher.sh"
done
