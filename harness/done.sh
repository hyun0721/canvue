#!/bin/bash
# harness/done.sh
# 에이전트가 작업 완료 후 호출
# 사용법: ./harness/done.sh <task_id>

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PROJECT_ROOT/harness"
TASK_ID="${1:-}"

[[ -z "$TASK_ID" ]] && { echo "사용법: ./harness/done.sh <task_id>"; exit 1; }

TASK_FILE="$HARNESS_DIR/workspace/tasks/${TASK_ID}.json"
RESULT_FILE="$HARNESS_DIR/workspace/results/${TASK_ID}.md"

[[ -f "$TASK_FILE" ]]  || { echo "❌ task 파일 없음: $TASK_FILE"; exit 1; }
[[ -f "$RESULT_FILE" ]] || { echo "❌ 결과 파일 없음: $RESULT_FILE (먼저 작성해주세요)"; exit 1; }

# status 업데이트
sed -i.bak 's/"status": "in_progress"/"status": "done"/' "$TASK_FILE"
sed -i.bak 's/"status": "pending"/"status": "done"/'     "$TASK_FILE"
rm -f "${TASK_FILE}.bak"

# 완료 알림 파일 생성
touch "$HARNESS_DIR/workspace/notify/${TASK_ID}.done"

echo "✅ 완료 알림 전송: $TASK_ID"
echo "   Orchestrator가 notify/${TASK_ID}.done 을 감지합니다."
