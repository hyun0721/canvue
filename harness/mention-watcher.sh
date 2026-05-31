#!/bin/bash
# =============================================================================
# harness/mention-watcher.sh
# channel.md의 새 @mention을 감지해서 해당 에이전트 pane에 자동 dispatch
#
# Orchestrator의 자동 루프에서 호출하거나 독립 실행 가능
# 사용법: bash harness/mention-watcher.sh
# =============================================================================

SESSION="vue-pkg"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANNEL="$PROJECT_ROOT/harness/workspace/chat/channel.md"
PROCESSED="$PROJECT_ROOT/harness/workspace/chat/.processed_msgs"

# 처리된 메시지 ID 추적 파일
touch "$PROCESSED"

declare -A PANE_MAP
PANE_MAP[orchestrator]=0
PANE_MAP[architect]=1
PANE_MAP[implementer]=2
PANE_MAP[planner]=3
PANE_MAP[designer]=4
PANE_MAP[reviewer]=5

dispatch_to() {
  local pane="$1"
  local message="$2"
  tmux send-keys -t "$SESSION:agents.$pane" "$message"
  sleep 0.3
  tmux send-keys -t "$SESSION:agents.$pane" "" Enter
}

process_mentions() {
  [[ -f "$CHANNEL" ]] || return

  # 아직 처리 안 된 메시지 블록 파싱
  # 포맷: [SENDER] msg_id: msg_XXX
  while IFS= read -r line; do
    # 메시지 ID 라인 감지
    if [[ "$line" =~ ^\[([A-Z]+)\].*msg_id:\ (msg_[0-9]+) ]]; then
      sender="${BASH_REMATCH[1],,}"   # 소문자로
      msg_id="${BASH_REMATCH[2]}"

      # 이미 처리된 메시지 스킵
      grep -qF "$msg_id" "$PROCESSED" && continue

      # 이 메시지 블록에서 @mention 수집
      mentions=()
      content_lines=()
      in_block=false
      next_block=false

      while IFS= read -r inner_line; do
        if [[ "$inner_line" =~ ^\[([A-Z]+)\].*msg_id: ]]; then
          [[ "$in_block" == true ]] && { next_block=true; break; }
          [[ "$inner_line" =~ msg_id:\ $msg_id ]] && in_block=true
        fi
        if [[ "$in_block" == true ]]; then
          # @mention 추출 (여러 개 가능)
          while [[ "$inner_line" =~ @([a-z]+) ]]; do
            target="${BASH_REMATCH[1]}"
            [[ "$target" != "$sender" ]] && mentions+=("$target")
            inner_line="${inner_line#*@${BASH_REMATCH[1]}}"
          done
          content_lines+=("$inner_line")
        fi
      done < "$CHANNEL"

      # @mention된 에이전트들에게 dispatch
      for target in "${mentions[@]}"; do
        pane="${PANE_MAP[$target]}"
        [[ -z "$pane" ]] && continue

        dispatch_to "$pane" \
          "harness/workspace/chat/channel.md 파일을 읽어줘. ${sender^^}가 너에게 메시지를 남겼어 (${msg_id}). 읽고 필요하면 channel.md에 답변을 추가해줘. 다른 에이전트가 필요하면 @mention으로 호출해."

        echo "📨 [$(date +%H:%M:%S)] $sender → @$target (${msg_id}) dispatch 완료"
      done

      # 처리 완료 기록
      echo "$msg_id" >> "$PROCESSED"
    fi
  done < "$CHANNEL"
}

# 단발 실행 모드 (루프에서 호출 시)
process_mentions
