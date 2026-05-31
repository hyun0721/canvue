# 인터페이스 명세
> Designer 에이전트가 작성합니다.
> 작성일: 2026-05-30 | task_003

---

## 목차
1. [DX 이슈 분석 및 결정](#1-dx-이슈-분석-및-결정)
2. [LabelDesigner](#2-labeldesigner)
3. [LabelPrintPopup](#3-labelprintpopup)
4. [useDesigner](#4-usedesigner)
5. [useFormat](#5-useformat)
6. [usePrint](#6-useprint)
7. [타입 추가 명세](#7-타입-추가-명세)

---

## 1. DX 이슈 분석 및 결정

### Issue 1: `LabelPrintPopup` — `visible` vs `modelValue`

**현재 코드:** `visible: boolean` + `update:visible` → `v-model:visible`

**분석:**
- `v-model:visible`은 Vue 3 named v-model로 문법상 유효하다.
- 단, Element Plus `<el-dialog v-model>`, Naive UI `<n-modal v-model:show>` 등 주요 라이브러리는 `modelValue` 또는 명시적 named model(`show`, `open`)을 사용한다.
- `visible`은 의미상 명확하지만, **소비자가 `v-model`(기본값)을 먼저 시도하면 작동하지 않는다**는 DX 마찰이 있다.

**결정: `v-model:visible` 유지 + 네이밍을 `open`으로 변경**
- `v-model:open` — Headless UI, Radix Vue 컨벤션과 일치
- `open`은 dialog/popup의 상태를 명확히 표현하며 영문 관용어로 자연스럽다
- `v-model:visible` → `v-model:open`으로 마이그레이션 (기존 `visible`은 deprecated alias 처리)

```vue
<!-- ✅ 권장 사용 -->
<LabelPrintPopup
  v-model:open="showPopup"
  :format="labelFormat"
  :records="dataRecords"
  @print-success="onSuccess"
  @print-error="onError"
/>
```

---

### Issue 2: `useDesigner()` 상태 공유 패턴

**현재 코드:** `LabelDesigner` 내부에서 `useDesigner(props.modelValue)` 호출 → 소비자가 외부에서 별도 호출 시 격리된 인스턴스 생성

**분석:**
- 단순 사용: 소비자는 `v-model`로 `LabelFormat`만 교환하면 충분
- 고급 사용: 소비자가 `placeElement`, `resetFormat` 등 designer 메서드를 직접 호출해야 하는 경우

**결정: `defineExpose` 패턴 채택 (template ref 통해 접근)**

VueUse, Headless UI 컨벤션상 컴포넌트 내부 상태를 외부에서 직접 제어할 때는 `ref` + `defineExpose`가 가장 Vue답다.

```vue
<!-- ✅ 기본 사용 (v-model만으로 충분) -->
<LabelDesigner
  v-model="myFormat"
  :elements="elementDefs"
  @save="onSave"
/>

<!-- ✅ 고급 사용 (template ref로 메서드 접근) -->
<LabelDesigner
  ref="designerRef"
  v-model="myFormat"
  :elements="elementDefs"
/>

<script setup>
const designerRef = useTemplateRef('designerRef')

function doReset() {
  designerRef.value?.resetFormat()
}
function addElement() {
  designerRef.value?.placeElement(0, 0, myElementDef)
}
</script>
```

`defineExpose`를 통해 노출할 메서드:
- `resetFormat()` — 포맷 초기화
- `placeElement(row, col, definition)` — 프로그래매틱 요소 배치
- `removeElement(row, col)` — 프로그래매틱 요소 제거
- `selectCell(row, col)` — 셀 선택
- `clearSelection()` — 선택 해제
- `updateGrid(config)` — 그리드 설정 변경

---

### Issue 3: `gridConfig` 반응성

**현재 코드:** setup 시 1회 `if (props.gridConfig)` 실행 → 이후 prop 변경 무시

**결정: `watchEffect` 적용**

```typescript
// ✅ 권장 구현
watchEffect(() => {
  if (props.gridConfig) {
    updateGrid({
      rows: props.gridConfig.rows ?? format.value.grid.rows,
      cols: props.gridConfig.cols ?? format.value.grid.cols,
      cellWidth: props.gridConfig.cellWidth ?? format.value.grid.cellWidth,
      cellHeight: props.gridConfig.cellHeight ?? format.value.grid.cellHeight,
    })
  }
})
```

단, gridConfig 변경 시 **기존 배치된 셀이 삭제될 수 있음**을 `@grid-change` 이벤트로 소비자에게 알려야 한다.

---

### Issue 4: `PrintOptions` 미export

**결정:** `src/index.ts`에 `PrintOptions` 타입 추가

```typescript
export type { PrintOptions } from './composables/usePrint'
```

---

### Issue 5: `CellEditor` `update-style` 이벤트 타입

**현재:** `Record<string, string>` — 임의의 CSS 키/값 문자열

**결정: `Partial<CSSProperties>` 로 변경**

- `CSSProperties`는 Vue가 re-export하는 타입으로 자동완성 완전 지원
- `LabelElement.style`이 이미 `CSSProperties`를 사용하므로 일관성 확보

```typescript
// ✅ 권장 타입
'update-style': [row: number, col: number, style: Partial<CSSProperties>]
```

---

### Issue 6: `LabelDesigner` Slot 부재

**결정: 3개 슬롯 추가**

| 슬롯명 | scoped props | 용도 |
|---|---|---|
| `toolbar` | `{ format, save, updateGrid }` | 툴바 전체 교체 |
| `toolbar-actions` | `{ format, save }` | Save 버튼 우측에 커스텀 액션 추가 |
| `cell-content` | `{ cell, row, col, element }` | 셀 렌더링 커스터마이징 |

```vue
<!-- ✅ 툴바 액션 추가 -->
<LabelDesigner v-model="fmt" :elements="elements">
  <template #toolbar-actions="{ format, save }">
    <button @click="save">저장</button>
    <button @click="exportFormat(format)">내보내기</button>
  </template>
</LabelDesigner>

<!-- ✅ 셀 콘텐츠 커스터마이징 -->
<LabelDesigner v-model="fmt" :elements="elements">
  <template #cell-content="{ cell, row, col, element }">
    <MyCustomCellRenderer :element="element" />
  </template>
</LabelDesigner>
```

---

### Issue 7: 인쇄 실패 에러 이벤트

**현재:** `console.error` 출력만 → 소비자가 팝업 차단을 감지할 방법 없음

**결정: `@print-error` emit + `usePrint` 반환값에 에러 상태 추가**

```typescript
// LabelPrintPopup emits
'print-error': [error: PrintError]
'print-success': []

// PrintError 타입
interface PrintError {
  code: 'POPUP_BLOCKED' | 'UNKNOWN'
  message: string
}
```

```vue
<!-- ✅ 사용 예 -->
<LabelPrintPopup
  v-model:open="showPopup"
  :format="format"
  :records="records"
  @print-error="(e) => toast.error(e.message)"
  @print-success="showPopup = false"
/>
```

---

### Issue 8: `LabelDesigner` 리셋/초기화 메서드 미노출

**결정:** Issue 2의 `defineExpose` 패턴에 포함. `resetFormat()` 추가.

```typescript
// ✅ useDesigner에 추가할 메서드
function resetFormat(newFormat?: LabelFormat): void {
  format.value = newFormat ?? {
    id: generateId(),
    name: 'New Label',
    grid: { ...DEFAULT_GRID },
    cells: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }
}
```

---

## 2. LabelDesigner

### Props

```typescript
interface LabelDesignerProps {
  /** 편집 중인 라벨 포맷 (v-model) */
  modelValue?: LabelFormat

  /** 드래그 가능한 요소 정의 목록 (필수) */
  elements: ElementDefinition[]

  /**
   * 그리드 초기 설정 및 반응형 변경
   * 변경 시 범위를 벗어난 셀은 제거되며 @grid-change 이벤트 발생
   */
  gridConfig?: Partial<GridConfig>
}
```

### Emits

```typescript
interface LabelDesignerEmits {
  /** 내부 포맷 변경 시 (v-model 동기화) */
  'update:modelValue': [format: LabelFormat]

  /** Save 버튼 클릭 또는 programmatic save 호출 시 */
  'save': [format: LabelFormat]

  /**
   * gridConfig prop 변경으로 그리드가 재구성될 때
   * removedCells: 범위 초과로 제거된 셀 목록
   */
  'grid-change': [config: GridConfig, removedCells: LabelCell[]]
}
```

### Slots

```typescript
interface LabelDesignerSlots {
  /**
   * 툴바 전체 교체
   * @slot toolbar
   */
  toolbar(props: {
    format: LabelFormat
    save: () => void
    updateGrid: (config: Partial<GridConfig>) => void
    renameFormat: (name: string) => void
  }): any

  /**
   * 툴바 Save 버튼 우측 영역에 추가 액션 삽입
   * @slot toolbar-actions
   */
  'toolbar-actions'(props: {
    format: LabelFormat
    save: () => void
  }): any

  /**
   * 각 셀 내부 렌더링 커스터마이징
   * @slot cell-content
   */
  'cell-content'(props: {
    cell: LabelCell | null
    row: number
    col: number
    element: LabelElement | undefined
  }): any
}
```

### Expose (template ref 접근)

```typescript
interface LabelDesignerExpose {
  /** 포맷 초기화 (인수 없으면 빈 포맷 생성) */
  resetFormat(newFormat?: LabelFormat): void

  /** 특정 셀에 요소를 프로그래매틱으로 배치 */
  placeElement(row: number, col: number, definition: ElementDefinition): void

  /** 특정 셀의 요소 제거 */
  removeElement(row: number, col: number): void

  /** 그리드 설정 변경 */
  updateGrid(config: Partial<GridConfig>): void

  /** 셀 선택 */
  selectCell(row: number, col: number): void

  /** 선택 해제 */
  clearSelection(): void
}
```

### 사용 예제

```vue
<!-- ✅ 기본 사용 -->
<LabelDesigner
  v-model="labelFormat"
  :elements="elementDefs"
  @save="onSave"
/>

<!-- ✅ gridConfig 반응형 연동 -->
<LabelDesigner
  v-model="labelFormat"
  :elements="elementDefs"
  :grid-config="{ rows: 3, cols: 4, cellWidth: 100, cellHeight: 80 }"
  @grid-change="onGridChange"
  @save="onSave"
/>

<!-- ✅ 툴바 커스터마이징 + template ref -->
<LabelDesigner
  ref="designer"
  v-model="labelFormat"
  :elements="elementDefs"
>
  <template #toolbar-actions="{ format, save }">
    <button @click="save">저장</button>
    <button @click="exportJson(format)">JSON 내보내기</button>
  </template>
</LabelDesigner>

<script setup lang="ts">
import type { LabelDesignerExpose } from 'canvue'
const designer = useTemplateRef<LabelDesignerExpose>('designer')

// 외부에서 포맷 초기화
function handleReset() {
  designer.value?.resetFormat()
}
</script>
```

---

## 3. LabelPrintPopup

### Props

```typescript
interface LabelPrintPopupProps {
  /** 팝업 열림 상태 (v-model:open) */
  open: boolean

  /** 인쇄할 라벨 포맷 */
  format: LabelFormat

  /** 인쇄할 데이터 레코드 배열 */
  records: DataRecord[]

  /** 인쇄 옵션 */
  printOptions?: PrintOptions
}
```

### Emits

```typescript
interface LabelPrintPopupEmits {
  /** 팝업 닫힘 동기화 (v-model:open) */
  'update:open': [value: boolean]

  /** 팝업 닫힘 (X 버튼, 오버레이 클릭, 인쇄 후) */
  'close': []

  /** 인쇄 성공 (print dialog 열림) */
  'print-success': []

  /** 인쇄 실패 (팝업 차단 등) */
  'print-error': [error: PrintError]
}
```

### 사용 예제

```vue
<!-- ✅ 기본 사용 -->
<LabelPrintPopup
  v-model:open="showPrintPopup"
  :format="labelFormat"
  :records="selectedRecords"
/>

<!-- ✅ 에러 핸들링 -->
<LabelPrintPopup
  v-model:open="showPrintPopup"
  :format="labelFormat"
  :records="selectedRecords"
  :print-options="{ title: '라벨 출력', pageBreakAfter: true }"
  @print-success="showPrintPopup = false"
  @print-error="handlePrintError"
/>

<script setup lang="ts">
import type { PrintError } from 'canvue'

function handlePrintError(error: PrintError) {
  if (error.code === 'POPUP_BLOCKED') {
    alert('팝업이 차단되었습니다. 브라우저 설정에서 팝업을 허용해주세요.')
  }
}
</script>
```

---

## 4. useDesigner

### 시그니처

```typescript
function useDesigner(initialFormat?: LabelFormat): UseDesignerReturn

interface UseDesignerReturn {
  // State
  format: Ref<LabelFormat>
  selectedCell: Ref<{ row: number; col: number } | null>
  cellMatrix: ComputedRef<(LabelCell | null)[][]>

  // Actions
  getCellAt(row: number, col: number): LabelCell | undefined
  placeElement(row: number, col: number, definition: ElementDefinition): void
  removeElement(row: number, col: number): void
  selectCell(row: number, col: number): void
  clearSelection(): void
  updateGrid(config: Partial<GridConfig>): void
  renameFormat(name: string): void

  /** 포맷 초기화 (추가 예정) */
  resetFormat(newFormat?: LabelFormat): void
}
```

### 상태 공유 패턴

`useDesigner`는 **매 호출마다 독립적인 상태 인스턴스**를 생성한다.
소비자가 LabelDesigner 외부에서 상태를 공유하려면 `defineExpose`로 노출된 메서드를 template ref를 통해 사용한다.

```typescript
// ✅ 단순 사용 — LabelDesigner가 자체 관리
const format = ref<LabelFormat>()
// <LabelDesigner v-model="format" />

// ✅ 외부 제어 — template ref 패턴
const designerRef = useTemplateRef('designer')
designerRef.value?.resetFormat()
designerRef.value?.placeElement(0, 0, elementDef)

// ❌ 권장하지 않음 — 별도 인스턴스로 상태 불일치 발생
const { format, placeElement } = useDesigner()  // 컴포넌트 내부와 다른 인스턴스
```

### 사용 예제

```typescript
// ✅ 직접 상태 편집 UI 구성 시 (LabelDesigner 미사용)
import { useDesigner } from 'canvue'

const { format, cellMatrix, placeElement, removeElement, updateGrid } = useDesigner({
  id: 'my-label',
  name: '배송 라벨',
  grid: { rows: 3, cols: 3, cellWidth: 100, cellHeight: 80 },
  cells: [],
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
})

// 그리드 변경
updateGrid({ rows: 4, cols: 4 })

// 요소 배치
placeElement(0, 0, {
  key: 'recipient',
  label: '수령인',
  type: 'text',
  defaultStyle: { fontSize: '14px', fontWeight: 'bold' },
})
```

---

## 5. useFormat

### 시그니처

```typescript
function useFormat(): UseFormatReturn

interface UseFormatReturn {
  /** LabelFormat → JSON 문자열 직렬화 */
  serialize(format: LabelFormat): string

  /**
   * JSON 문자열 → LabelFormat 역직렬화
   * @throws {Error} 유효하지 않은 포맷 JSON일 때
   */
  deserialize(json: string): LabelFormat
}
```

### 사용 예제

```typescript
import { useFormat } from 'canvue'

const { serialize, deserialize } = useFormat()

// 저장
const json = serialize(format.value)
localStorage.setItem('label-format', json)

// 불러오기
try {
  const saved = localStorage.getItem('label-format')
  if (saved) {
    format.value = deserialize(saved)
  }
} catch (e) {
  console.error('유효하지 않은 포맷 데이터입니다.')
}
```

---

## 6. usePrint

### 시그니처

```typescript
function usePrint(): UsePrintReturn

interface UsePrintReturn {
  /**
   * 라벨 인쇄 팝업 창 열기
   * @returns PrintResult — 성공 여부 및 에러 정보
   */
  printLabels(
    format: LabelFormat,
    records: DataRecord[],
    options?: PrintOptions
  ): PrintResult
}

interface PrintResult {
  success: boolean
  error?: PrintError
}

interface PrintOptions {
  /** 인쇄 문서 제목 (기본값: format.name) */
  title?: string

  /** 레코드 간 페이지 나눔 */
  pageBreakAfter?: boolean
}

interface PrintError {
  code: 'POPUP_BLOCKED' | 'UNKNOWN'
  message: string
}
```

> **변경점:** 기존 `void` 반환 → `PrintResult` 반환으로 소비자가 팝업 차단 여부를 감지 가능

### 사용 예제

```typescript
import { usePrint } from 'canvue'
import type { PrintError } from 'canvue'

const { printLabels } = usePrint()

function handlePrint() {
  const result = printLabels(format, records, {
    title: '배송 라벨',
    pageBreakAfter: true,
  })

  if (!result.success && result.error?.code === 'POPUP_BLOCKED') {
    showNotification('팝업이 차단되었습니다. 브라우저 팝업 허용 후 다시 시도해주세요.')
  }
}
```

---

## 7. 타입 추가 명세

### 추가 export 목록 (`src/index.ts`)

```typescript
// 현재 누락된 타입들 — 추가 필요
export type { PrintOptions } from './composables/usePrint'
export type { PrintError } from './composables/usePrint'
export type { PrintResult } from './composables/usePrint'
export type { LabelDesignerExpose } from './components/LabelDesigner/LabelDesigner.vue'
```

### `LabelElement.style` 타입 명확화

```typescript
// 현재: style?: CSSProperties  ✅ 유지
// CellEditor update-style 이벤트 타입 변경
// 기존: Record<string, string>
// 변경: Partial<CSSProperties>
```

### `GridConfig` — partial 허용

```typescript
// 현재 GridConfig는 모든 필드 필수
// LabelDesigner.gridConfig prop에서 Partial<GridConfig> 허용
// useDesigner.updateGrid는 이미 Partial<GridConfig> 사용 중 ✅
```

---

## 변경 요약

| # | 항목 | 현재 | 권장 | 우선순위 |
|---|---|---|---|---|
| 1 | LabelPrintPopup v-model | `v-model:visible` | `v-model:open` | Medium |
| 2 | 상태 공유 | 없음 | `defineExpose` + template ref | High |
| 3 | gridConfig 반응성 | 1회 초기화 | `watchEffect` | High |
| 4 | PrintOptions export | 미export | `src/index.ts` 추가 | Low |
| 5 | update-style 타입 | `Record<string, string>` | `Partial<CSSProperties>` | Medium |
| 6 | LabelDesigner Slots | 없음 | `toolbar`, `toolbar-actions`, `cell-content` | Medium |
| 7 | 인쇄 에러 이벤트 | console.error만 | `@print-error` emit + `PrintResult` 반환 | High |
| 8 | 포맷 리셋 메서드 | 없음 | `resetFormat()` + `defineExpose` | Medium |
