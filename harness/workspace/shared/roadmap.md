# Canvue 기능 로드맵

> Planner 에이전트 작성 | 2026-05-30
> 기준: 코드베이스 직접 분석 (src/types, GridCanvas, CellEditor, PrintPreview, usePrint)

---

## 현재 MVP 완성도 평가

| 기능 영역 | 상태 | 비고 |
|---|---|---|
| 그리드 렌더링 / 셀 선택 | ✅ 완성 | |
| 드래그&드롭으로 요소 배치 | ✅ 완성 | |
| JSON 직렬화/역직렬화 | ✅ 완성 | |
| 인쇄 팝업 (text) | ⚠️ 부분 완성 | text 타입만 실제 출력 |
| 바코드/QR 인쇄 렌더링 | ❌ 미구현 | 텍스트 값만 출력됨 |
| image 타입 렌더링 | ❌ 미구현 | 타입 선언만 존재 |
| custom 타입 렌더링 | ❌ 미구현 | 타입 선언만 존재 |
| 셀 스타일 편집 | ⚠️ 부분 완성 | fontSize, textAlign만 지원 |
| 셀 병합 (rowSpan/colSpan) | ⚠️ 부분 완성 | 렌더링은 동작, 편집 UI 없음 |
| Undo/Redo | ❌ 미구현 | |
| 다중 셀 선택 | ❌ 미구현 | |

**MVP 완성도: 약 55%** — 핵심 가치인 바코드/QR 인쇄가 미작동 상태이므로 공개 출시 불가 수준.

---

## v0.1.x — 핵심 기능 완성 (출시 전 필수)

> 목표: "바코드/QR 라벨을 설계하고 인쇄할 수 있다"는 핵심 가치를 실현

### v0.1.1 — 인쇄 렌더링 완성

- [ ] **바코드 인쇄 렌더링** `priority: high`
  - 왜 필요한가: 패키지의 핵심 가치. 현재 `usePrint.ts`의 `buildCells()`는 barcode 타입도 `escapeHtml(value)`로 텍스트 출력. `jsbarcode` 의존성이 설치되어 있으나 print HTML에 전혀 주입되지 않음.
  - 완료 기준: 인쇄 HTML에 `<svg>` 바코드가 실제 렌더링됨 (JsBarcode CDN 또는 inline script 방식)

- [ ] **QR코드 인쇄 렌더링** `priority: high`
  - 왜 필요한가: 바코드와 동일. `qrcode` 패키지가 설치되어 있으나 미사용.
  - 완료 기준: 인쇄 HTML에 `<canvas>` 또는 `<svg>` QR코드가 실제 렌더링됨

- [ ] **PrintPreview 바코드/QR 시각화** `priority: high`
  - 왜 필요한가: 디자이너 내 미리보기(`PrintPreview.vue`)도 현재 텍스트만 출력. 실제 바코드 모양을 미리 볼 수 없음.
  - 완료 기준: `PrintPreview`에서 barcode/qrcode 타입이 실제 바코드/QR 이미지로 렌더링됨

### v0.1.2 — image 타입 지원

- [ ] **image 타입 렌더링 (인쇄 + 미리보기)** `priority: high`
  - 왜 필요한가: `LabelElement.type`에 `'image'`가 선언되어 있어 사용자가 설정 가능하지만, `PrintPreview`·`usePrint` 어디에도 `<img>` 렌더링이 없음. `fieldKey`에 URL을 바인딩하면 `<img src="...">` 로 출력되어야 함.
  - 완료 기준: image 타입 셀이 인쇄 HTML과 `PrintPreview`에서 `<img>` 태그로 렌더링됨

### v0.1.3 — 셀 편집 기능 보완

- [ ] **CellEditor 스타일 속성 확장** `priority: medium`
  - 왜 필요한가: 현재 `fontSize`, `textAlign` 두 가지만 편집 가능. 실용적인 라벨 디자인을 위해 `color`, `fontWeight`, `fontFamily`, `backgroundColor`, `padding`은 최소한 지원되어야 함.
  - 완료 기준: CellEditor에서 위 5가지 추가 속성 편집 가능

- [ ] **셀 병합 UI (rowSpan/colSpan)** `priority: medium`
  - 왜 필요한가: `LabelCell`에 `rowSpan`/`colSpan` 타입이 정의되어 있고 그리드 렌더링도 지원하지만, 사용자가 설정할 UI가 없어 사실상 사용 불가 기능.
  - 완료 기준: CellEditor에서 rowSpan/colSpan 숫자 입력으로 셀 병합 가능

---

## v0.2.x — 사용성 개선

> 목표: 반복 작업과 편집 경험을 개선하여 실무 사용 가능 수준 달성

### v0.2.0

- [ ] **Undo/Redo** `priority: medium`
  - 왜 필요한가: 셀 배치 실수 시 되돌릴 방법이 없어 UX가 열악함. 상태 스택 기반으로 구현.
  - 완료 기준: `Ctrl+Z` / `Ctrl+Shift+Z`로 10단계 이상 되돌리기/다시하기 동작

- [ ] **다중 셀 선택** `priority: medium`
  - 왜 필요한가: 여러 셀에 동일 스타일을 일괄 적용하려면 다중 선택이 필요.
  - 완료 기준: Shift+클릭으로 다중 선택 후 일괄 스타일 편집 가능

- [ ] **i18n (레이블 prop 오버라이드)** `priority: medium`
  - 왜 필요한가: UI 문자열이 영어 하드코딩("drop here", "Font Size", "Text Align" 등). npm 공개 패키지로서 비영어권 채택에 장애.
  - 완료 기준: `<LabelDesigner :labels="{ dropHere: '여기에 놓기', ... }">` prop으로 모든 UI 텍스트 오버라이드 가능. 기본값은 영어 유지.

### v0.2.1

- [ ] **custom 타입 렌더링 슬롯** `priority: low`
  - 왜 필요한가: `'custom'` 타입이 선언되어 있으나 렌더링 불가. 소비자가 Vue slot으로 커스텀 컨텐츠 주입 가능해야 패키지 확장성이 생김.
  - 완료 기준: `<LabelDesigner>` 및 `<PrintPreview>`에 `#custom-cell="{ element, record }"` 슬롯 제공

- [ ] **그리드 설정 편집 UI** `priority: low`
  - 왜 필요한가: 현재 `rows`, `cols`, `cellWidth`, `cellHeight`를 코드에서만 설정 가능. 비개발자도 라벨 크기를 조정할 수 있어야 함.
  - 완료 기준: 디자이너 UI에서 그리드 행/열 수, 셀 크기 변경 가능

- [ ] **포맷 파일 저장/불러오기** `priority: low`
  - 왜 필요한가: 현재 직렬화/역직렬화는 메모리 내에서만 동작. 실제 .json 파일로 내보내기/가져오기 버튼이 있어야 사용성 완성.
  - 완료 기준: 브라우저에서 `.canvue.json` 파일 다운로드 및 파일 선택으로 불러오기 가능

---

## v1.0.0 — 정식 출시 기준

> 목표: API 안정성 보장, 접근성, 배포 품질 확보

- [ ] **접근성 (ARIA)** `priority: medium`
  - 왜 필요한가: 현재 그리드 셀에 ARIA role/label 없음. 공개 패키지 품질 기준상 기본 키보드 접근성은 필수.
  - 완료 기준: 그리드에 `role="grid"`, 셀에 `role="gridcell"`, 드래그 요소에 `aria-label` 적용. 키보드로 셀 탐색(화살표 키) 가능.

- [ ] **API 안정성 선언** `priority: high`
  - 왜 필요한가: semver 1.0.0은 공개 API가 안정적임을 의미. 인터페이스 변경에 major bump 정책 필요.
  - 완료 기준: 공개 타입(`LabelFormat`, `LabelCell`, `LabelElement`, `ElementDefinition`, `DataRecord`) freeze. CHANGELOG 작성.

- [ ] **테스트 커버리지 목표 달성** `priority: medium`
  - 왜 필요한가: 현재 13개 테스트가 있으나 인쇄 렌더링·바코드·image 등 신규 기능 커버리지 없음.
  - 완료 기준: composable 단위 테스트 커버리지 80% 이상, 컴포넌트 통합 테스트 주요 시나리오 커버

- [ ] **문서화** `priority: medium`
  - 왜 필요한가: npm 패키지로서 README와 API 문서 없이는 채택률이 낮음.
  - 완료 기준: README에 설치, 기본 사용법, prop 목록, 슬롯, CSS 변수, 브라우저 지원 명시

---

## 기능 우선순위 매트릭스

| 기능 | 사용자 가치 | 구현 복잡도 | 우선순위 |
|---|---|---|---|
| 바코드/QR 인쇄 렌더링 | 최상 | 중 | **v0.1.1 즉시** |
| PrintPreview 바코드/QR | 상 | 중 | **v0.1.1 즉시** |
| image 타입 렌더링 | 상 | 하 | v0.1.2 |
| CellEditor 스타일 확장 | 상 | 하 | v0.1.3 |
| 셀 병합 UI | 중 | 중 | v0.1.3 |
| Undo/Redo | 상 | 중 | v0.2.0 |
| 다중 셀 선택 | 중 | 중 | v0.2.0 |
| i18n prop 오버라이드 | 중 | 하 | v0.2.0 |
| custom 슬롯 | 중 | 중 | v0.2.1 |
| 그리드 설정 편집 | 중 | 하 | v0.2.1 |
| 포맷 파일 저장/불러오기 | 중 | 하 | v0.2.1 |
| ARIA 접근성 | 중 | 중 | v1.0.0 |
| API 안정성 선언 | 상 | 하 | v1.0.0 |

---

## i18n / ARIA 포함 여부 결정 근거

- **i18n**: **포함 (v0.2.0)** — 전체 i18n 프레임워크(vue-i18n 등) 도입은 과함. 단순히 UI 텍스트를 prop으로 오버라이드 가능하게 하는 방식으로 충분하며 구현 비용이 낮음.
- **ARIA**: **포함 (v1.0.0)** — 1.0.0 출시 기준에 포함. 단, v0.x 개발 중 새로 만드는 컴포넌트에는 기본 role/label을 바로 추가하여 누적 부채를 최소화 권장.
