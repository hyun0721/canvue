# canvue

Vue 3 label designer component — design grid-based labels and print them.

- Drag & drop elements onto a grid canvas to build a label layout
- Serialize/deserialize the format as JSON
- Render barcode, QR code, image, or text in each cell
- Open a print popup with real data records

---

## Installation

```bash
npm install canvue
```

Import the stylesheet once in your app entry:

```ts
import 'canvue/style.css'
```

---

## Quick Start

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { LabelDesigner, LabelPrintPopup } from 'canvue'
import type { LabelFormat, ElementDefinition, DataRecord } from 'canvue'

// Elements shown in the right panel — consumer defines these
const elements: ElementDefinition[] = [
  { key: 'productName', label: 'Product Name', type: 'text' },
  { key: 'sku',         label: 'SKU',          type: 'text', defaultStyle: { fontFamily: 'monospace' } },
  { key: 'barcode',     label: 'Barcode',       type: 'barcode' },
  { key: 'qr',          label: 'QR Code',       type: 'qrcode' },
]

// Records provided at print time
const records: DataRecord[] = [
  { productName: 'Widget A', sku: 'WGT-001', barcode: '012345678905', qr: 'https://example.com/1' },
  { productName: 'Widget B', sku: 'WGT-002', barcode: '012345678906', qr: 'https://example.com/2' },
]

const format = ref<LabelFormat | undefined>()
const printOpen = ref(false)
</script>

<template>
  <LabelDesigner
    :elements="elements"
    v-model="format"
    @save="console.log('saved', $event)"
  />

  <button :disabled="!format" @click="printOpen = true">Print</button>

  <LabelPrintPopup
    v-if="format"
    :format="format"
    :records="records"
    v-model:open="printOpen"
  />
</template>
```

---

## Components

### `<LabelDesigner>`

Grid-based label layout editor with a drag-and-drop element panel.

#### Props

| Prop | Type | Default | Description |
|---|---|---|---|
| `elements` | `ElementDefinition[]` | — | **Required.** Element definitions shown in the right panel. |
| `modelValue` | `LabelFormat` | — | Current format. Use `v-model` for two-way binding. |
| `gridConfig` | `Partial<GridConfig>` | — | Override grid dimensions reactively. |

#### Emits

| Event | Payload | Description |
|---|---|---|
| `update:modelValue` | `LabelFormat` | Emitted on every change (use `v-model`). |
| `save` | `LabelFormat` | Emitted when the Save button is clicked. |
| `grid-change` | `(config: GridConfig, removedCells: LabelCell[])` | Emitted when grid dimensions change; provides the cells that were out of bounds and removed. |

#### Expose (`ref` access)

```ts
const designerRef = ref<InstanceType<typeof LabelDesigner>>()
// Methods available via template ref:
designerRef.value?.resetFormat(newFormat?)
designerRef.value?.placeElement(row, col, definition)
designerRef.value?.removeElement(row, col)
designerRef.value?.updateGrid({ rows, cols, cellWidth, cellHeight })
designerRef.value?.selectCell(row, col)
designerRef.value?.clearSelection()
```

#### Slots

| Slot | Scope | Description |
|---|---|---|
| `toolbar` | `{ format, save, updateGrid, renameFormat }` | Replace the entire toolbar. |
| `toolbar-actions` | `{ format, save }` | Append extra buttons to the default toolbar. |
| `cell-content` | `{ cell, row, col, element }` | Override cell rendering inside the grid. |

#### Example: custom toolbar actions

```vue
<LabelDesigner :elements="elements" v-model="format">
  <template #toolbar-actions="{ format, save }">
    <button @click="saveToServer(format)">Save to server</button>
  </template>
</LabelDesigner>
```

---

### `<LabelPrintPopup>`

Modal print popup that renders a preview of all records and opens the browser print dialog.

#### Props

| Prop | Type | Default | Description |
|---|---|---|---|
| `format` | `LabelFormat` | — | **Required.** Label format to render. |
| `records` | `DataRecord[]` | — | **Required.** Data records to print. |
| `open` | `boolean` | — | **Required.** Use `v-model:open`. |
| `printOptions` | `PrintOptions` | — | Optional print behavior settings. |

#### Emits

| Event | Payload | Description |
|---|---|---|
| `update:open` | `boolean` | Use `v-model:open`. |
| `close` | — | Emitted when the popup is dismissed. |
| `print-success` | — | Emitted after the print dialog is opened successfully. |
| `print-error` | `PrintError` | Emitted when printing fails (e.g. popup blocked, SSR). |

#### `PrintOptions`

```ts
interface PrintOptions {
  title?: string           // <title> for the print window (default: format.name)
  pageBreakAfter?: boolean // Insert page break between each record
  mode?: 'window' | 'iframe' | 'auto'
  // 'auto' (default): tries window.open, falls back to hidden iframe if blocked
}
```

---

## Composables

### `useDesigner(initialFormat?)`

All the state and methods powering `<LabelDesigner>`. Use this if you need programmatic control outside the component.

```ts
import { useDesigner } from 'canvue'

const {
  format,          // Ref<LabelFormat>
  selectedCell,    // Ref<{ row, col } | null>
  cellMatrix,      // ComputedRef<(LabelCell | null)[][]>
  getCellAt,       // (row, col) => LabelCell | undefined
  placeElement,    // (row, col, definition) => void
  removeElement,   // (row, col) => void
  selectCell,      // (row, col) => void
  clearSelection,  // () => void
  updateGrid,      // (config: Partial<GridConfig>) => LabelCell[] (removed cells)
  updateSpan,      // (row, col, rowSpan, colSpan) => void
  renameFormat,    // (name: string) => void
  resetFormat,     // (newFormat?: LabelFormat) => void
} = useDesigner()
```

### `useFormat()`

JSON serialization helpers for `LabelFormat`.

```ts
import { useFormat } from 'canvue'

const { format, createFormat, loadFormat, exportFormat, downloadFormat } = useFormat()

// Create a new empty format
const f = createFormat('My Label', { rows: 3, cols: 4, cellWidth: 100, cellHeight: 70 })

// Load from saved JSON string
loadFormat(jsonString)

// Export to JSON string
const json = exportFormat()

// Trigger a browser file download
downloadFormat('my-label.json')
```

You can also use the lower-level utilities directly:

```ts
import { serializeFormat, deserializeFormat } from 'canvue'
```

### `usePrint()`

Programmatic printing without the popup UI.

```ts
import { usePrint } from 'canvue'

const { printLabels } = usePrint()

const result = await printLabels(format, records, {
  title: 'Product Labels',
  pageBreakAfter: true,
  mode: 'auto',
})

if (!result.success) {
  console.error(result.error?.code, result.error?.message)
}
```

---

## Types

```ts
interface GridConfig {
  rows: number
  cols: number
  cellWidth: number   // px
  cellHeight: number  // px
}

interface LabelFormat {
  id: string
  name: string
  grid: GridConfig
  cells: LabelCell[]
  createdAt: string
  updatedAt: string
}

interface LabelCell {
  row: number
  col: number
  rowSpan?: number
  colSpan?: number
  element?: LabelElement
}

interface LabelElement {
  id: string
  type: 'text' | 'barcode' | 'qrcode' | 'image' | 'custom'
  fieldKey: string        // bound to a key in DataRecord
  style?: CSSProperties
}

// Draggable item definition provided by the consumer
interface ElementDefinition {
  key: string
  label: string
  type: LabelElement['type']
  defaultStyle?: CSSProperties
}

// A single data record provided at print time
type DataRecord = Record<string, unknown>
```

---

## CSS Variables (Theming)

Override any of these variables to theme the components:

```css
:root {
  --canvue-accent:        #3b82f6;  /* primary action color */
  --canvue-accent-dark:   #2563eb;
  --canvue-bg:            #ffffff;
  --canvue-border:        #e2e8f0;
  --canvue-font:          system-ui, sans-serif;

  /* Grid */
  --canvue-grid-border:      #94a3b8;
  --canvue-grid-gap-color:   #e2e8f0;
  --canvue-cell-bg:          #ffffff;
  --canvue-cell-hover-bg:    #f0f9ff;
  --canvue-cell-selected-bg: #eff6ff;
  --canvue-cell-occupied-bg: #f0fdf4;
  --canvue-placeholder-color:#cbd5e1;

  /* Panels */
  --canvue-toolbar-bg:       #f8fafc;
  --canvue-canvas-area-bg:   #f1f5f9;
  --canvue-panel-bg:         #f8fafc;
  --canvue-panel-border:     #e2e8f0;
  --canvue-panel-header-bg:  #f1f5f9;

  /* Popup */
  --canvue-popup-z:          9999;
}
```

---

## Development

```bash
npm run dev          # playground dev server
npm run build        # typecheck + library build
npm test             # vitest
npm publish --dry-run
```

---

## License

MIT
