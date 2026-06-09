<script setup lang="ts">
import { watch, computed, ref, onMounted, onUnmounted } from 'vue'
import type { LabelFormat, LabelCell, ElementDefinition, GridConfig } from '../../types'
import type { CSSProperties } from 'vue'
import { useDesigner } from '../../composables/useDesigner'
import GridCanvas from './GridCanvas.vue'
import ElementPanel from './ElementPanel.vue'
import CellEditor from './CellEditor.vue'

export interface LabelDesignerExpose {
  resetFormat(newFormat?: LabelFormat): void
  placeElement(row: number, col: number, definition: ElementDefinition): void
  removeElement(row: number, col: number): void
  updateGrid(config: Partial<GridConfig>): void
  selectCell(row: number, col: number): void
  clearSelection(): void
}

const props = defineProps<{
  elements: ElementDefinition[]
  modelValue?: LabelFormat
  gridConfig?: Partial<GridConfig>
}>()

const emit = defineEmits<{
  'update:modelValue': [format: LabelFormat]
  'save': [format: LabelFormat]
  'grid-change': [config: GridConfig, removedCells: LabelCell[]]
}>()

const {
  format,
  selectedCell,
  cellMatrix,
  canUndo,
  getCellAt,
  placeElement,
  removeElement,
  selectCell,
  clearSelection,
  updateGrid,
  addRow,
  deleteRow,
  addCol,
  deleteCol,
  updateColWidth,
  updateRowHeight,
  updateSpan,
  renameFormat,
  resetFormat,
  snapshot,
  undo,
} = useDesigner(props.modelValue)

// Reactively apply gridConfig changes (deep watch with JSON.stringify dedup, skipSnapshot)
let _prevGridConfigJSON = ''
watch(
  () => props.gridConfig,
  (val) => {
    if (!val) return
    const next = JSON.stringify(val)
    if (next === _prevGridConfigJSON) return
    _prevGridConfigJSON = next
    const removedCells = updateGrid({ ...val }, true)  // external props sync: skip snapshot
    emit('grid-change', format.value.grid, removedCells)
  },
  { deep: true, immediate: true }
)

// Sync external v-model changes in
watch(
  () => props.modelValue,
  (val) => {
    if (val && val.updatedAt !== format.value.updatedAt) {
      Object.assign(format.value, val)
    }
  }
)

// Emit on internal changes
watch(format, (val) => emit('update:modelValue', val), { deep: true })

const selectedCellData = computed(() => {
  if (!selectedCell.value) return null
  return getCellAt(selectedCell.value.row, selectedCell.value.col) ?? null
})

// ── Local state for rows/cols inputs (prevent mid-type revert) ──
const localRows = ref(format.value.grid.rows)
const localCols = ref(format.value.grid.cols)

watch(() => format.value.grid.rows, (v) => { localRows.value = v })
watch(() => format.value.grid.cols, (v) => { localCols.value = v })

function handleRowsCommit(): void {
  const v = localRows.value
  if (v >= 1 && v <= 50 && v !== format.value.grid.rows) updateGrid({ rows: v })
  else localRows.value = format.value.grid.rows
}

function handleColsCommit(): void {
  const v = localCols.value
  if (v >= 1 && v <= 50 && v !== format.value.grid.cols) updateGrid({ cols: v })
  else localCols.value = format.value.grid.cols
}

// ── Keyboard shortcut: Ctrl+Z / Cmd+Z ──
function handleKeydown(e: KeyboardEvent): void {
  if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
    e.preventDefault()
    undo()
  }
}

onMounted(() => window.addEventListener('keydown', handleKeydown))
onUnmounted(() => window.removeEventListener('keydown', handleKeydown))

// ── GridCanvas event handlers ──
function handleDrop(row: number, col: number, definition: ElementDefinition): void {
  placeElement(row, col, definition)
}

function handleUpdateStyle(row: number, col: number, style: Partial<CSSProperties>): void {
  const cell = getCellAt(row, col)
  if (cell?.element) {
    cell.element.style = { ...cell.element.style, ...style }
  }
}

function handleUpdateSpan(row: number, col: number, rowSpan: number, colSpan: number): void {
  updateSpan(row, col, rowSpan, colSpan)
}

function handleColResizeStart(_colIdx: number): void {
  snapshot()
}

function handleRowResizeStart(_rowIdx: number): void {
  snapshot()
}

function handleColResize(colIdx: number, width: number): void {
  updateColWidth(colIdx, width)
}

function handleRowResize(rowIdx: number, height: number): void {
  updateRowHeight(rowIdx, height)
}

function handleSave(): void {
  emit('save', format.value)
}

defineExpose<LabelDesignerExpose>({
  resetFormat,
  placeElement,
  removeElement,
  updateGrid,
  selectCell,
  clearSelection,
})
</script>

<template>
  <div class="canvue-designer">
    <!-- Toolbar -->
    <div class="canvue-designer__toolbar">
      <slot name="toolbar" :format="format" :save="handleSave" :update-grid="updateGrid" :rename-format="renameFormat">
        <input
          class="canvue-designer__name-input"
          :value="format.name"
          placeholder="Label name…"
          @input="renameFormat(($event.target as HTMLInputElement).value)"
        />
        <div class="canvue-designer__grid-controls">
          <label>
            Rows
            <input
              type="number"
              min="1"
              max="50"
              v-model.number="localRows"
              @blur="handleRowsCommit"
              @keydown.enter="handleRowsCommit"
            />
          </label>
          <label>
            Cols
            <input
              type="number"
              min="1"
              max="50"
              v-model.number="localCols"
              @blur="handleColsCommit"
              @keydown.enter="handleColsCommit"
            />
          </label>
        </div>
        <button
          class="canvue-btn canvue-btn--ghost"
          :disabled="!canUndo"
          title="Undo (Ctrl+Z)"
          @click="undo"
        >↩ Undo</button>
        <button class="canvue-btn canvue-btn--primary" @click="handleSave">Save</button>
        <slot name="toolbar-actions" :format="format" :save="handleSave" />
      </slot>
    </div>

    <!-- Main layout -->
    <div class="canvue-designer__body">
      <!-- Left: grid canvas -->
      <div class="canvue-designer__canvas-area" @click.self="clearSelection">
        <GridCanvas
          :format="format"
          :cell-matrix="cellMatrix"
          :selected-cell="selectedCell"
          @cell-click="selectCell"
          @drop="handleDrop"
          @remove-element="removeElement"
          @add-row="addRow"
          @add-col="addCol"
          @delete-row="deleteRow"
          @delete-col="deleteCol"
          @col-resize-start="handleColResizeStart"
          @col-resize="handleColResize"
          @row-resize-start="handleRowResizeStart"
          @row-resize="handleRowResize"
        >
          <template #cell-content="slotProps">
            <slot name="cell-content" v-bind="slotProps" />
          </template>
        </GridCanvas>
      </div>

      <!-- Right: element panel + cell editor -->
      <div class="canvue-designer__sidebar">
        <ElementPanel :elements="elements" />
        <CellEditor
          v-if="selectedCell"
          :cell="selectedCellData"
          :format="format"
          :row="selectedCell.row"
          :col="selectedCell.col"
          @update-style="handleUpdateStyle"
          @update-span="handleUpdateSpan"
          @close="clearSelection"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.canvue-designer {
  display: flex;
  flex-direction: column;
  font-family: var(--canvue-font, system-ui, sans-serif);
  background: var(--canvue-bg, #ffffff);
  border: 1px solid var(--canvue-border, #e2e8f0);
  border-radius: 8px;
  overflow: hidden;
  min-width: 480px;
}

.canvue-designer__toolbar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  background: var(--canvue-toolbar-bg, #f8fafc);
  border-bottom: 1px solid var(--canvue-border, #e2e8f0);
  flex-wrap: wrap;
}

.canvue-designer__name-input {
  padding: 4px 10px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 14px;
  font-weight: 500;
  min-width: 160px;
}

.canvue-designer__grid-controls {
  display: flex;
  gap: 8px;
  align-items: center;
}

.canvue-designer__grid-controls label {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: #64748b;
}

.canvue-designer__grid-controls input[type='number'] {
  width: 52px;
  padding: 3px 6px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 13px;
}

.canvue-btn {
  padding: 6px 14px;
  border: none;
  border-radius: 4px;
  font-size: 13px;
  cursor: pointer;
  font-weight: 500;
  transition: background 0.15s;
}

.canvue-btn--primary {
  background: var(--canvue-accent, #3b82f6);
  color: #fff;
}

.canvue-btn--primary:hover {
  background: var(--canvue-accent-dark, #2563eb);
}

.canvue-btn--ghost {
  background: transparent;
  color: #64748b;
  border: 1px solid #e2e8f0;
}

.canvue-btn--ghost:hover:not(:disabled) {
  background: #f1f5f9;
}

.canvue-btn--ghost:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.canvue-designer__body {
  display: flex;
  gap: 0;
  overflow: auto;
}

.canvue-designer__canvas-area {
  flex: 1;
  padding: 24px;
  overflow: auto;
  background: var(--canvue-canvas-area-bg, #f1f5f9);
  min-height: 300px;
}

.canvue-designer__sidebar {
  width: 220px;
  min-width: 180px;
  border-left: 1px solid var(--canvue-border, #e2e8f0);
  display: flex;
  flex-direction: column;
  gap: 0;
  background: var(--canvue-panel-bg, #f8fafc);
  overflow-y: auto;
}
</style>
