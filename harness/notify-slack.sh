#!/bin/bash
# =============================================================================
# harness/notify-slack.sh
# Orchestrator가 Slack #canvue-agents 채널에 알림을 보내는 헬퍼
# Slack MCP를 Claude Code bash 도구로 직접 호출할 수 없으므로
# Orchestrator Claude Code가 이 스크립트를 실행하면
# 메시지를 큐 파일에 저장 → Orchestrator가 Slack MCP로 직접 전송
#
# 사용법: bash harness/notify-slack.sh "<메시지>"
# =============================================================================

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUE_DIR="$HARNESS_DIR/workspace/slack-queue"
MESSAGE="${1:-}"

[[ -z "$MESSAGE" ]] && { echo "사용법: bash harness/notify-slack.sh \"<메시지>\""; exit 1; }

mkdir -p "$QUEUE_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
QUEUE_FILE="$QUEUE_DIR/msg_${TIMESTAMP}.txt"

echo "$MESSAGE" > "$QUEUE_FILE"
echo "📨 Slack 큐 저장: $QUEUE_FILE"
echo "   Orchestrator가 다음 루프에서 Slack MCP로 전송합니다."
