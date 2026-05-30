#!/bin/bash
# harness/new-task.sh
# 사용법: ./harness/new-task.sh <role> <title> [priority]
# 예시:   ./harness/new-task.sh architect "기술 스택 선정" high

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASKS_DIR="$PROJECT_ROOT/harness/workspace/tasks"
VALID_ROLES=("orchestrator" "architect" "planner" "designer" "implementer" "reviewer")

ROLE="${1:-}"; TITLE="${2:-}"; PRIORITY="${3:-medium}"

[[ -z "$ROLE" || -z "$TITLE" ]] && {
  echo "사용법: ./harness/new-task.sh <role> <title> [priority]"
  echo "role 옵션: ${VALID_ROLES[*]}"
  exit 1
}

VALID=false
for r in "${VALID_ROLES[@]}"; do [[ "$ROLE" == "$r" ]] && VALID=true && break; done
$VALID || { echo "❌ 유효하지 않은 role: $ROLE"; exit 1; }

COUNT=$(ls "$TASKS_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
TASK_ID="task_$(printf '%03d' $((COUNT + 1)))"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)

cat > "$TASKS_DIR/${TASK_ID}.json" <<EOF
{
  "task_id": "$TASK_ID",
  "assigned_to": "$ROLE",
  "priority": "$PRIORITY",
  "status": "pending",
  "title": "$TITLE",
  "description": "",
  "context_refs": [
    "harness/workspace/shared/decisions.md",
    "harness/workspace/shared/roadmap.md",
    "harness/workspace/shared/interfaces.md"
  ],
  "expected_output": "",
  "created_at": "$TIMESTAMP"
}
EOF

echo "✅ 생성: $TASKS_DIR/${TASK_ID}.json"
echo "   role: $ROLE | priority: $PRIORITY"
echo ""
echo "👉 다음 단계: description과 expected_output을 채워주세요"
echo "   \$EDITOR $TASKS_DIR/${TASK_ID}.json"
