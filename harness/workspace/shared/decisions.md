# 기술 결정 로그
> Architect 에이전트가 작성합니다.

## 요약 표

| # | 결정 항목 | 선택 (권고) | 대안 | 근거 | 날짜 |
|---|---|---|---|---|---|
| ADR-001 | `vuedraggable` 의존성 | **제거** | 유지 / 실제 도입 | 코드 미사용 + native HTML5 D&D 채택 결정과 일치 | 2026-05-30 |
| ADR-002 | ID 생성 전략 | **`crypto.randomUUID()` + 폴백** | `Date.now() + Math.random()` 유지 | 충돌·예측 가능성 / 표준 API | 2026-05-30 |
| ADR-003 | 바코드/QR 라이브러리 로딩 | **lazy dynamic import 유지 + manualChunks 명시** | 정적 import / peerDependency 화 | 초기 번들 다이어트, tree-shaking, 선택적 사용 | 2026-05-30 |
| ADR-004 | `usePrint()` 환경 가드/팝업 차단 | **SSR 가드 + 팝업 차단 fallback (iframe 인쇄) 도입** | 현행 유지 / 외부 라이브러리(`vue3-print-nb`) | SSR 빌드 안전성, UX | 2026-05-30 |
| ADR-005 | 인쇄 윈도우 내 barcode/QR 렌더링 | **메인 윈도우에서 SVG/Canvas 사전 렌더 → HTML 직렬화 후 이식** | 인쇄 윈도우에서 lazy import 재실행 | dynamic import 컨텍스트·CORS 제약 회피, 실제 시각적 출력 보장 | 2026-05-30 |
| ADR-006 | `package.json` 메타 필드 | **`engines`, `repository`, `homepage`, `bugs`, `sideEffects` 추가** | 현행 유지 | npm 레지스트리 신뢰성, 번들러 최적화 | 2026-05-30 |
| ADR-007 | `exports` 맵 CSS 항목 | **`"./style.css": "./dist/canvue.css"` 항목 추가** | deep import 허용(`canvue/dist/canvue.css`) | Node ESM exports 봉인 정책 대응, 명시적 진입점 | 2026-05-30 |

---

## ADR-001 — `vuedraggable` 의존성 제거
- **현재 상태**: `package.json#dependencies` 에 `vuedraggable@^4.1.0` 선언. `grep -R "vuedraggable" src` 결과 0건. 메모리(`MEMORY.md`) 및 `useDesigner`/`GridCanvas` 구조상 native HTML5 D&D (`application/canvue-element` MIME) 사용.
- **선택**: 의존성에서 즉시 제거.
- **대안 검토**:
  - 유지 (탈락: dead dependency → 소비자 측에 불필요한 설치 부담 및 보안 감사 표면 확대).
  - vuedraggable 실제 도입으로 전환 (탈락: SortableJS 의존, ESM/Vue3 호환성 이슈 이력, peer 충돌 가능. 현재 D&D 요구사항 단순 → 오버킬).
- **근거**: 번들 노이즈 제거, `npm audit` 표면 축소, semver 영향 없음(아직 0.1.0).
- **권고 조치**: `package.json#dependencies` 에서 라인 삭제 후 `npm install` 재실행, lockfile 갱신.

## ADR-002 — ID 생성 전략
- **현재 상태**: `useDesigner.ts#generateId` 가 `el-${Date.now()}-${Math.random().toString(36).slice(2,9)}` 사용. 36진수 7자리(~36^7 ≈ 7.8e10) + ms 타임스탬프. 동일 ms 내 36^7 충돌 확률은 작지만 0이 아님. 예측 가능.
- **선택**: `crypto.randomUUID()` 우선 + 비대응 환경 폴백.
  ```ts
  function generateId(): string {
    const g = (globalThis as any).crypto
    if (g?.randomUUID) return `el-${g.randomUUID()}`
    // 폴백: 기존 로직
    return `el-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
  }
  ```
- **대안 검토**:
  - `nanoid` 도입 (탈락: 추가 의존성, 현재 충돌 위험은 표준 Web Crypto 로 충분히 해결).
  - 단조 증가 카운터 (탈락: 모듈 전역 상태 → 동일 페이지 다중 designer 인스턴스에서 직렬화/역직렬화 시 ID 충돌).
- **근거**: `crypto.randomUUID` 는 Node 19+, 모든 모던 브라우저에서 지원. RFC 4122 v4 충돌 확률 무시 가능. 폴백으로 구형 환경(타깃 `es2020` Node ≤16)도 보호.
- **권고 조치**: `useDesigner.ts` 및 `placeElement` 내 ID 생성 통일. 직렬화된 포맷이 외부 시스템과 키로 매칭될 가능성 → `el-` 접두사는 유지(가독성/네임스페이스).

## ADR-003 — 바코드/QR 라이브러리 lazy 로딩 전략
- **현재 상태**: `utils/barcode.ts` 에서 `await import('jsbarcode')`, `await import('qrcode')`. Vite 라이브러리 빌드 산출물에 `dist/JsBarcode-*.js`, `dist/browser-*.js` 청크 분리 확인.
- **선택**: lazy dynamic import 유지, 단 아래 보강.
  1. `vite.config.ts#build.rollupOptions.output.manualChunks` 로 청크 파일명 안정화 → 소비자 CDN 캐시 효율.
  2. `dependencies` 유지 (peerDependency 화는 사용자 DX 저하 → 도입 거부).
  3. 사용 위치(`renderBarcode`, `renderQrCode`) JSDoc 에 “동적 import — 번들러 `import()` 분석 가능 필요” 명시.
- **대안 검토**:
  - 정적 import 전환 (탈락: 라이브러리 사용자가 바코드/QR 미사용해도 전량 번들 → tree-shaking 불가, JsBarcode 는 side-effectful 등록 구조).
  - peerDependency 로 외부화 (탈락: 일반 npm 패키지 소비자 경험 악화, 옵셔널 의존 관리 복잡, 본 라이브러리 목적상 “바로 동작” 약속과 모순).
  - 코드 스플리팅 제거 후 단일 번들 (탈락: ESM/CJS 두 진입점에서 사용 안 해도 무조건 적재).
- **근거**: 현재 분리 청크 약 jsbarcode 35KB + qrcode 30KB 규모로 초기 로드 비용 큼 → lazy 가 정당. 다만 라이브러리 소비자 빌드 시 dynamic chunk 경로 안정화 필요.
- **권고 조치**: ADR-005 와 결합하여 “호출 위치 = 메인 페이지”로 한정. 인쇄 윈도우에서 별도 호출 금지.

## ADR-004 — `usePrint()` SSR 가드 및 팝업 차단 fallback
- **현재 상태**: `composables/usePrint.ts` 가 직접 `window.open()` 호출. `typeof window` 가드 없음 → Nuxt/SSR 빌드에서 import만으로는 안전하나, 컴포넌트 setup 단계에서 호출 시 서버 측 에러. 팝업 차단 시 `console.error` 만 출력하고 silent fail.
- **선택**: 다음 두 가지 동시 도입.
  1. **SSR 가드**: 함수 진입부에 `if (typeof window === 'undefined') return` (또는 Promise reject) — composable 자체는 안전하게 SSR 빌드 통과.
  2. **팝업 차단 fallback**: 숨김 `<iframe>` 생성 → `srcdoc` 주입 → `iframe.contentWindow.print()` 후 제거. 옵션 `mode: 'window' | 'iframe' | 'auto'` 도입(기본 `'auto'`).
- **대안 검토**:
  - 외부 라이브러리 `vue3-print-nb` 등 (탈락: 라이브러리 종속 추가, 커스텀 HTML 구성과 결합도 낮음).
  - `window.print()` 직접 호출(메인 윈도우) (탈락: 메인 페이지 전체 스타일 격리 불가 → 인쇄 UX 손상).
- **근거**: SSR 가드는 본 패키지 타깃(서버사이드 렌더링 포함 Vue3 생태계)에서 사실상 의무. iframe fallback 은 Chrome/Edge 팝업 차단 환경에서 사용자 액션 없이도 인쇄 가능(MDN 권장 패턴).
- **권고 조치**: API 시그니처에 `PrintOptions.mode` 추가. 반환 타입을 `Promise<void>` 로 변경하여 호출자가 비동기 완료/에러를 await 가능하게.

## ADR-005 — 인쇄 HTML 내 barcode/QR 실제 렌더링 구조 결함
- **현재 상태(결함)**: `buildPrintHtml` → `buildCells` 는 `record[fieldKey]` 의 **문자열 값을 그대로 텍스트로 escape 후 출력**. element type(`text`, `barcode`, `qrcode`, `image`)을 분기하지 않음. 즉:
  - lazy import 된 `renderBarcode`/`renderQrCode` 는 인쇄 윈도우에서 호출되지 않음.
  - 새로 열린 `window.open('', '_blank')` 컨텍스트는 별도 Document/모듈 스코프 → 메인 번들의 dynamic import 청크에 접근 불가.
  - 결과: 사용자는 디자이너에서 바코드 셀을 배치했어도 인쇄 시 텍스트만 인쇄됨.
- **선택**: **메인 윈도우에서 사전 렌더 → 인쇄 HTML에 직렬화하여 이식**.
  - 동작 흐름:
    1. `printLabels()` 호출 시 메인 페이지에서 임시 off-screen container 에 `<svg>`/`<canvas>` 생성.
    2. element.type 별 분기: `barcode` → `renderBarcode(svg, value)` await, `qrcode` → `renderQrCode(canvas, value)` await, `image` → `<img src>`, `text` → 텍스트.
    3. 바코드는 SVG 직렬화(`new XMLSerializer().serializeToString`), QR/이미지는 `canvas.toDataURL('image/png')` 로 변환.
    4. 결과 문자열을 `buildCells` 가 그대로 inline 삽입.
  - 이로써 인쇄 윈도우는 정적 HTML/이미지/SVG 만으로 완전 렌더 가능, 외부 라이브러리 의존 없음.
- **대안 검토**:
  - 인쇄 윈도우에 `<script type="module" src="...">` 로 라이브러리 주입 (탈락: 라이브러리 호스팅 경로 결정 불가, CSP 위반 가능, 비동기 타이밍 복잡).
  - 인쇄 윈도우에 동일 도메인 iframe 마운트 후 Vue 앱 재마운트 (탈락: SSR 가드/생명주기 복잡, 번들 중복 적재).
  - 현행 텍스트 출력 유지 (탈락: 라이브러리 핵심 기능 미충족 = 출시 차단 사유).
- **근거**: dynamic import 청크는 **원래 문서의 base URL + Vite 가 주입한 publicPath** 에 종속. `window.open` 으로 연 빈 문서는 about:blank 컨텍스트로 상대 경로 모듈 해석 불가. SVG/dataURL 직렬화는 모든 인쇄 컨텍스트에서 신뢰 가능.
- **권고 조치**: 이 변경은 `usePrint` 시그니처 변경(Promise화) 및 `LabelElement.type` 분기 도입이 필요. 우선순위 **P0** (출시 전 반드시).

## ADR-006 — `package.json` 메타 필드 보강
- **현재 상태**: `name`, `version`, `description`, `type`, `main`, `module`, `types`, `exports`, `files`, `scripts`, `peerDependencies`, `devDependencies`, `dependencies`, `keywords`, `license` 만 존재. `engines`, `repository`, `homepage`, `bugs`, `sideEffects`, `author`, `publishConfig` 없음.
- **선택**: 아래 필드 추가.
  ```json
  {
    "sideEffects": ["**/*.css"],
    "engines": { "node": ">=18.0.0" },
    "repository": { "type": "git", "url": "git+https://github.com/<org>/canvue.git" },
    "homepage": "https://github.com/<org>/canvue#readme",
    "bugs": { "url": "https://github.com/<org>/canvue/issues" },
    "publishConfig": { "access": "public" }
  }
  ```
- **대안 검토**:
  - 점진적 추가 (탈락: 첫 publish 전 일괄 추가 비용 < publish 후 수정 비용).
  - `sideEffects: false` 단순화 (탈락: CSS import 시 번들러가 제거 → 스타일 손실).
- **근거**:
  - `engines.node` 명시: Vite 5/Node 18 LTS 기준 호환성 공시.
  - `repository/bugs/homepage`: npm 레지스트리 페이지 신뢰도, GitHub link.
  - `sideEffects: ["**/*.css"]`: webpack/rollup tree-shaking 시 CSS 보존(번들러 표준 hint).
  - `publishConfig.access: public`: 스코프 패키지 전환 대비.
- **권고 조치**: 실제 GitHub repo URL 확정 후 적용. `author` 는 조직 정책에 맞춰 추가.

## ADR-007 — `exports` 맵 CSS 항목 추가
- **현재 상태**: `exports` 가 `"."` 진입점만 정의. 소비자가 `import 'canvue/dist/canvue.css'` 시 Node 16.14+ 의 exports 봉인(deep import 차단)에 의해 차단될 수 있음.
- **선택**: 명시적 CSS 서브패스 노출.
  ```json
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/canvue.mjs",
      "require": "./dist/canvue.cjs"
    },
    "./style.css": "./dist/canvue.css",
    "./package.json": "./package.json"
  }
  ```
  - 사용 예: `import 'canvue/style.css'`.
  - `types` 키는 조건부 내부 첫 번째에 둠(TS 5 resolution 권장).
  - `./package.json` 은 일부 도구(plugin) 가 메타 조회 시 필요.
- **대안 검토**:
  - CSS 자동 주입(`import './canvue.css'` 를 ESM 진입점에 포함) (탈락: tree-shaking 불가, 스타일 격리 옵션 박탈, SSR 환경에서 CSS 모듈 실행 불가).
  - `style` 필드만 추가 (탈락: 비표준, 번들러별 처리 차이).
  - deep import 허용(`exports` 미정의) (탈락: 현재 `exports` 가 정의되어 있어 봉인 효과 발생).
- **근거**: Node ESM `exports` 의 명시적 진입점 정책 준수. `import 'canvue/style.css'` 는 Vue 생태계(예: PrimeVue, Vuetify) 관례와 일치.
- **권고 조치**: README 에 `import 'canvue/style.css'` 사용 안내 추가. 기존 `import 'canvue/dist/canvue.css'` 경로는 미래 호환을 위해 한시 유지 가능하나 권장 경로는 단일화.

---

## 우선순위 매트릭스 (구현 순서 제안)

| 우선순위 | ADR | 이유 |
|---|---|---|
| P0 | ADR-005 | 라이브러리 핵심 기능(인쇄)의 기능적 결함 — 출시 차단 사유 |
| P0 | ADR-004 | SSR 환경 import-time 안전성 — 다운스트림 사용 차단 가능 |
| P1 | ADR-001 | 즉시 제거 가능, 위험 0, 신뢰도 향상 |
| P1 | ADR-007 | 첫 publish 전 exports 확정 필요(이후 변경 시 breaking) |
| P1 | ADR-006 | 첫 publish 전 메타 확정 권장 |
| P2 | ADR-002 | 충돌 확률 낮음, 표준화 차원의 개선 |
| P2 | ADR-003 | 현행 동작 OK, 운영 안정성 개선 |

## 다음 액션
- Implementer 에이전트에게 ADR-005, ADR-004 P0 구현 task 발행 권고.
- Planner 에이전트와 0.1.0 → 0.2.0 마일스톤 분리 협의 권고(P0 미해결 시 0.1.0 publish 보류).
