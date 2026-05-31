#!/bin/bash
# =============================================================================
# harness/dispatch.sh
# Claude Code tmux pane에 메시지를 신뢰할 수 있게 전달
#
# 문제: tmux send-keys "text" Enter
#   - 멀티바이트(한글) 문자를 글자별로 전송 → 레이스 컨디션 가능
#   - Enter 키가 터미널 모드에 따라 \n(줄바꿈)으로 처리 → Claude Code 미제출
#
# 해결: paste-buffer + C-m
#   - load-buffer: 문자열을 tmux 버퍼에 통째로 저장 (인코딩 안전)
#   - paste-buffer: 버퍼를 pane에 한 번에 붙여넣기
#   - C-m: 명시적 Carriage Return (0x0D) → Claude Code에서 항상 제출로 처리
#
# 사용법: bash harness/dispatch.sh <pane_index> "<메시지>"
# 예시:   bash harness/dispatch.sh 2 "task_fix_001.json 읽고 즉시 수정 시작해줘."
# =============================================================================

SESSION="vue-pkg"
PANE="${1:-}"
MESSAGE="${2:-}"

[[ -z "$PANE" || -z "$MESSAGE" ]] && {
  echo "사용법: bash harness/dispatch.sh <pane_index> \"<메시지>\""
  echo "  pane: 0=Orchestrator 1=Architect 2=Implementer 3=Planner 4=Designer 5=Reviewer"
  exit 1
}

TARGET="${SESSION}:agents.${PANE}"

# pane 존재 확인
tmux list-panes -t "${SESSION}:agents" -F "#{pane_index}" 2>/dev/null | grep -q "^${PANE}$" || {
  echo "❌ pane ${PANE}이 존재하지 않습니다 (세션: ${SESSION})"
  exit 1
}

# 1. 메시지를 tmux 버퍼에 저장 (멀티바이트 문자 안전)
printf '%s' "$MESSAGE" | tmux load-buffer -

# 2. 버퍼를 pane에 한 번에 붙여넣기 (send-keys 글자별 전송 대비 안전)
tmux paste-buffer -t "$TARGET"

# 3. 입력 완료 대기
sleep 0.2

# 4. C-m (Carriage Return 0x0D) 으로 명시적 제출
#    → Enter 키(터미널 모드에 따라 \n 가능)와 달리 항상 CR로 전달됨
tmux send-keys -t "$TARGET" C-m

echo "📨 dispatch → pane ${PANE}: $(echo "$MESSAGE" | head -c 60)..."
