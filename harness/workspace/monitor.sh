#!/bin/bash
cd "/Users/donghyun/projects/frontend/canvue"
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
