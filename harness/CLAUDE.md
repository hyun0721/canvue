# Vue/TS npm 패키지 프로젝트

## 프로젝트 개요
Vue 3 + TypeScript 기반 npm 공개 패키지 개발 프로젝트입니다.
멀티 에이전트 하네스 환경에서 협업합니다.

## 에이전트 팀 구성
| 역할 | CLAUDE.md 위치 | 담당 |
|---|---|---|
| Orchestrator | `harness/CLAUDE.md` + `harness/agents/orchestrator.md` | 작업 분배 · 진행 조율 |
| Architect | `harness/agents/architect.md` | 기술 자문 · 설계 결정 |
| Planner | `harness/agents/planner.md` | 기획 · 로드맵 |
| Designer | `harness/agents/designer.md` | UX/DX · 인터페이스 설계 |
| Implementer | `harness/agents/implementer.md` | 코드 구현 · 테스트 |
| Reviewer | `harness/agents/reviewer.md` | 코드 리뷰 · QA |

## 에이전트 통신 규약
- **작업 요청**: `harness/workspace/tasks/{task_id}.json`
- **결과 제출**: `harness/workspace/results/{task_id}.md`
- **완료 알림**: `harness/workspace/notify/{task_id}.done` (빈 파일 touch)
- **공유 컨텍스트**: `harness/workspace/shared/` (전 에이전트 읽기/쓰기 가능)

## Task 상태값
`pending` → `in_progress` → `done` | `blocked`

## Task JSON 포맷
```json
{
  "task_id": "task_001",
  "assigned_to": "architect",
  "priority": "high",
  "status": "pending",
  "title": "작업 제목",
  "description": "상세 설명",
  "context_refs": ["harness/workspace/shared/decisions.md"],
  "expected_output": "결과물 설명",
  "created_at": "YYYY-MM-DDTHH:MM:SS"
}
```

## 공유 파일 목록
| 파일 | 작성 주체 | 내용 |
|---|---|---|
| `shared/decisions.md` | Architect | 기술 결정 로그 |
| `shared/roadmap.md` | Planner | 기능 목록 · 마일스톤 |
| `shared/interfaces.md` | Designer | 컴포넌트 · Composable API 명세 |

## 현재 프로젝트 단계
**Phase 0**: 하네스 초기화 완료
→ **다음**: Architect · Planner · Designer 초기 기획 작업 병렬 착수
