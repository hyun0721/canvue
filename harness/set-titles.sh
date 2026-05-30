#!/bin/bash
# harness/set-titles.sh
# 실행 중인 세션에 pane 타이틀 즉시 적용
# pane_index 기반 고정 포맷 사용 → Claude Code 덮어쓰기 원천 차단

SESSION="vue-pkg"

tmux has-session -t "$SESSION" 2>/dev/null || { echo "❌ 세션 '$SESSION'이 없습니다."; exit 1; }

# 프로그램의 타이틀 변경 시도 차단
tmux set-option -t "$SESSION" -g allow-rename off
tmux set-option -t "$SESSION" -g automatic-rename off
tmux set-option -t "$SESSION" -g set-titles off

# pane 테두리 상단 표시 활성화
tmux set-option -t "$SESSION" -g pane-border-status top

# pane_index 기반 고정 레이블 (pane_title을 읽지 않으므로 덮어쓰기 불가)
tmux set-option -t "$SESSION" -g pane-border-format \
  "#{?pane_active,#[fg=colour226 bold],#[fg=colour245]}#{?#{==:#{pane_index},0}, ORCHESTRATOR ,#{?#{==:#{pane_index},1}, ARCHITECT ,#{?#{==:#{pane_index},2}, PLANNER ,#{?#{==:#{pane_index},3}, DESIGNER ,#{?#{==:#{pane_index},4}, IMPLEMENTER ,#{?#{==:#{pane_index},5}, REVIEWER , pane#{pane_index} }}}}}}#[default]"

echo "✅ 타이틀 고정 완료 (pane_index 기반 / 덮어쓰기 차단)"
echo ""
echo "  pane 0 → ORCHESTRATOR"
echo "  pane 1 → ARCHITECT"
echo "  pane 2 → PLANNER"
echo "  pane 3 → DESIGNER"
echo "  pane 4 → IMPLEMENTER"
echo "  pane 5 → REVIEWER"