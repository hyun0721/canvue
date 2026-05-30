#!/bin/bash
# =============================================================================
# harness/start.sh  (macOS / zsh 호환 수정판)
# =============================================================================

set -e

SESSION="vue-pkg"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PROJECT_ROOT/harness"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${GREEN}▶${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✖${NC}  $1" >&2; exit 1; }

# ── 사전 검사 ────────────────────────────────────────────────────────────────
check_deps() {
  command -v tmux   >/dev/null 2>&1 || err "tmux가 없습니다: brew install tmux"
  command -v claude >/dev/null 2>&1 || err "claude CLI가 없습니다: npm i -g @anthropic-ai/claude-code"
  [[ -f "$HARNESS_DIR/CLAUDE.md" ]] || err "CLAUDE.md가 없습니다: $HARNESS_DIR/CLAUDE.md"

  command -v watch >/dev/null 2>&1 || err "watch가 없습니다: brew install watch"

  # 스크립트 실행 권한 자동 보정
  chmod +x "$HARNESS_DIR"/*.sh 2>/dev/null || true

  log "의존성 확인 OK"
}

# ── workspace 초기화 ─────────────────────────────────────────────────────────
init_workspace() {
  mkdir -p \
    "$HARNESS_DIR/workspace/tasks" \
    "$HARNESS_DIR/workspace/results" \
    "$HARNESS_DIR/workspace/shared" \
    "$HARNESS_DIR/workspace/notify"

  [[ -f "$HARNESS_DIR/workspace/shared/decisions.md" ]] || cat > "$HARNESS_DIR/workspace/shared/decisions.md" <<'EOF'
# 기술 결정 로그
> Architect 에이전트가 작성합니다.

| 결정 항목 | 선택 | 대안 | 근거 | 날짜 |
|---|---|---|---|---|
EOF

  [[ -f "$HARNESS_DIR/workspace/shared/roadmap.md" ]] || cat > "$HARNESS_DIR/workspace/shared/roadmap.md" <<'EOF'
# 프로젝트 로드맵
> Planner 에이전트가 작성합니다.
EOF

  [[ -f "$HARNESS_DIR/workspace/shared/interfaces.md" ]] || cat > "$HARNESS_DIR/workspace/shared/interfaces.md" <<'EOF'
# 인터페이스 명세
> Designer 에이전트가 작성합니다.
EOF

  log "workspace 초기화 OK"
}

# ── 기존 세션 처리 ────────────────────────────────────────────────────────────
handle_existing_session() {
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    warn "기존 세션 '$SESSION' 발견"
    read -rp "  종료 후 재시작? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      tmux kill-session -t "$SESSION"
      log "기존 세션 종료"
    else
      log "기존 세션에 연결합니다..."
      tmux attach-session -t "$SESSION"
      exit 0
    fi
  fi
}

# ── tmux 레이아웃 생성 ────────────────────────────────────────────────────────
create_layout() {
  log "tmux 세션 '$SESSION' 생성 중..."

  tmux new-session -d -s "$SESSION" -n "agents" -x 240 -y 60

  # pane 테두리 상단에 타이틀 표시
  tmux set-option -t "$SESSION" -g pane-border-status top
  # pane_title 대신 pane_index 기반으로 고정 레이블 표시 (프로그램 덮어쓰기 원천 차단)
  tmux set-option -t "$SESSION" -g pane-border-format     "#{?pane_active,#[fg=colour226 bold],#[fg=colour245]}#{?#{==:#{pane_index},0}, ORCHESTRATOR ,#{?#{==:#{pane_index},1}, ARCHITECT ,#{?#{==:#{pane_index},2}, PLANNER ,#{?#{==:#{pane_index},3}, DESIGNER ,#{?#{==:#{pane_index},4}, IMPLEMENTER ,#{?#{==:#{pane_index},5}, REVIEWER , pane#{pane_index} }}}}}}#[default]"

  # 프로그램의 타이틀 변경 시도 차단
  tmux set-option -t "$SESSION" -g allow-rename off
  tmux set-option -t "$SESSION" -g automatic-rename off
  tmux set-option -t "$SESSION" -g set-titles off

  # 상단: pane0(Orchestrator) | pane1(Architect)
  tmux split-window -h -t "$SESSION:agents.0"

  # 하단 행: pane0 아래로 분할
  tmux split-window -v -t "$SESSION:agents.0" -p 50
  # 하단 행: pane1 아래로 분할
  tmux split-window -v -t "$SESSION:agents.1" -p 50

  # 하단 좌측 분할: Planner | Designer
  tmux split-window -h -t "$SESSION:agents.2"
  # 하단 우측 분할: Implementer | Reviewer
  tmux split-window -h -t "$SESSION:agents.4"

  # 각 pane에 역할 타이틀 부여
  local titles=("ORCHESTRATOR" "ARCHITECT" "PLANNER" "DESIGNER" "IMPLEMENTER" "REVIEWER")
  for i in "${!titles[@]}"; do
    tmux select-pane -t "$SESSION:agents.$i" -T "${titles[$i]}"
  done

  sleep 0.3
  log "레이아웃 생성 완료"
}

# ── Claude Code 인스턴스 시작 ────────────────────────────────────────────────
start_agents() {
  log "Claude Code 인스턴스 시작 중..."

  local agents=("orchestrator" "architect" "planner" "designer" "implementer" "reviewer")
  local display_names=("Orchestrator" "Architect" "Planner" "Designer" "Implementer" "Reviewer")

  # 에이전트별 모델
  # Opus  : 깊은 추론 필요 (Architect, Reviewer)
  # Sonnet: 일반 작업 (Orchestrator, Planner, Designer, Implementer)
  local models=(
    "claude-sonnet-4-6"   # 0: Orchestrator
    "claude-opus-4-7"     # 1: Architect
    "claude-sonnet-4-6"   # 2: Planner
    "claude-sonnet-4-6"   # 3: Designer
    "claude-sonnet-4-6"   # 4: Implementer
    "claude-opus-4-7"     # 5: Reviewer
  )

  # 에이전트별 권한 모드
  # skip : --dangerously-skip-permissions (자동화 / 승인 생략)
  # normal: 일반 모드 (사람이 최종 게이트 역할 — Reviewer 전용)
  local permissions=(
    "skip"    # 0: Orchestrator — tmux 명령 실행 필수
    "skip"    # 1: Architect    — 문서 파일 작성 빈도 높음
    "skip"    # 2: Planner      — 문서 파일 작성 빈도 높음
    "skip"    # 3: Designer     — 문서 파일 작성 빈도 높음
    "skip"    # 4: Implementer  — src/ 파일 다수 생성
    "normal"  # 5: Reviewer     — 사람이 최종 확인하는 게이트
  )

  for i in "${!agents[@]}"; do
    local role="${agents[$i]}"
    local name="${display_names[$i]}"
    local model="${models[$i]}"
    local perm="${permissions[$i]}"
    local md_file="$HARNESS_DIR/agents/${role}.md"

    [[ -f "$md_file" ]] || { warn "$md_file 없음, 스킵"; continue; }

    # 권한 모드에 따라 claude 실행 명령 구성
    if [[ "$perm" == "skip" ]]; then
      tmux send-keys -t "$SESSION:agents.$i"         "cd $PROJECT_ROOT && claude --model $model --dangerously-skip-permissions" Enter
    else
      # Reviewer: 일반 모드 (승인 게이트 역할)
      tmux send-keys -t "$SESSION:agents.$i"         "cd $PROJECT_ROOT && claude --model $model" Enter
    fi

    log "$name 시작 (claude 초기화 대기 중...)"

    # Claude Code 완전 초기화 대기
    # pane에 프롬프트(>)가 뜰 때까지 폴링
    local max_wait=30
    local waited=0
    while ! tmux capture-pane -t "$SESSION:agents.$i" -p 2>/dev/null | grep -q "[>?]"; do
      sleep 1
      waited=$((waited + 1))
      [[ $waited -ge $max_wait ]] && { warn "$name 초기화 타임아웃 (${max_wait}s)"; break; }
    done
    sleep 1  # 프롬프트 뜬 후 안정화 대기

    # 역할 파일 경로를 직접 전달 (tmux 버퍼 크기 제한 우회)
    tmux send-keys -t "$SESSION:agents.$i"       "harness/agents/${role}.md 파일을 읽고 역할을 인지해줘. 인지 완료 시 '✅ ${name} 준비 완료' 라고만 짧게 답해."       Enter

    sleep 2
  done

  log "전체 에이전트 시작 완료"
}

# ── monitor 창 생성 ───────────────────────────────────────────────────────────
create_monitor() {
  tmux new-window -t "$SESSION" -n "monitor"

  # watch에 넘길 명령을 스크립트 파일로 저장 (send-keys 버퍼 오염 방지)
  local monitor_script="$HARNESS_DIR/workspace/monitor.sh"

  cat > "$monitor_script" << MONITOR
#!/bin/bash
cd "$PROJECT_ROOT"
echo "━━━ TASKS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -1 harness/workspace/tasks/ 2>/dev/null | grep .json || echo "  (없음)"

echo ""
echo "━━━ NOTIFY (완료 알림) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -1 harness/workspace/notify/ 2>/dev/null | grep .done || echo "  (없음)"

echo ""
echo "━━━ RESULTS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -1 harness/workspace/results/ 2>/dev/null || echo "  (없음)"

echo ""
echo "━━━ SHARED ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -1 harness/workspace/shared/ 2>/dev/null
MONITOR

  chmod +x "$monitor_script"

  # watch로 2초마다 실행 (send-keys에는 짧은 명령만 전달)
  tmux send-keys -t "$SESSION:monitor" "watch -n 2 bash $monitor_script" Enter

  log "monitor 창 생성 완료"
}

# ── 가이드 출력 ───────────────────────────────────────────────────────────────
print_guide() {
  echo ""
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}${BOLD}║     Claude Code 하네스 - 부팅 완료 🚀               ║${NC}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}세션 연결${NC}    tmux attach -t $SESSION"
  echo -e "  ${BOLD}세션 종료${NC}    tmux kill-session -t $SESSION"
  echo ""
  echo -e "  ${BOLD}Pane 이동${NC}    Ctrl+b → 방향키"
  echo -e "  ${BOLD}Pane 확대${NC}    Ctrl+b → z"
  echo -e "  ${BOLD}창 전환${NC}      Ctrl+b → w"
  echo ""
  echo    "  [레이아웃]"
  echo    "  ┌───────────────────┬────────────────────┐"
  echo    "  │  0: Orchestrator  │   1: Architect     │"
  echo    "  ├────────┬──────────┼─────────┬──────────┤"
  echo    "  │2:Plann.│3:Designer│4:Impl.  │5:Reviewer│"
  echo    "  └────────┴──────────┴─────────┴──────────┘"
  echo    "  + monitor 탭 (Ctrl+b → w로 전환)"
  echo ""
}

# ── 메인 ─────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${CYAN}${BOLD}Vue/TS npm 패키지 - Claude Code 하네스 시작${NC}\n"
  echo "  PROJECT_ROOT : $PROJECT_ROOT"
  echo "  HARNESS_DIR  : $HARNESS_DIR"
  echo ""

  check_deps
  init_workspace
  handle_existing_session
  create_layout

  # ★ 핵심: monitor와 agents를 모두 먼저 구성한 뒤 attach
  create_monitor
  start_agents

  print_guide

  read -rp "지금 바로 세션에 연결할까요? [Y/n] " attach_ans
  [[ "$attach_ans" =~ ^[Nn]$ ]] || exec tmux attach-session -t "$SESSION"
}

main "$@"