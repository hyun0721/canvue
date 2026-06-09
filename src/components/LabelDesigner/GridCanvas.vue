<script setup lang="ts">
import { ref } from 'vue'
import type { LabelCell, LabelFormat, ElementDefinition } from '../../types'

const props = defineProps<{
  format: LabelFormat
  cellMatrix: (LabelCell | null)[][]
  selectedCell: { row: number; col: number } | null
}>()

const emit = defineEmits<{
  'cell-click': [row: number, col: number]
  'drop': [row: number, col: number, definition: ElementDefinition]
  'remove-element': [row: number, col: number]
  'add-row': []
  'add-col': []
  'delete-row': [rowIdx: number]
  'delete-col': [colIdx: number]
  'col-resize-start': [colIdx: number]
  'col-resize': [colIdx: number, width: number]
  'row-resize-start': [rowIdx: number]
  'row-resize': [rowIdx: number, height: number]
}>()

function isSelected(row: number, col: number): boolean {
  return props.selectedCell?.row === row && props.selectedCell?.col === col
}

function onDragOver(e: DragEvent): void {
  e.preventDefault()
  if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy'
}

function onDrop(e: DragEvent, row: number, col: number): void {
  e.preventDefault()
  const raw = e.dataTransfer?.getData('application/canvue-element')
  if (!raw) return
  try {
    const definition = JSON.parse(raw) as ElementDefinition
    emit('drop', row, col, definition)
  } catch {
    // ignore malformed drag data
  }
}

function typeLabel(type: string): string {
  const labels: Record<string, string> = {
    text: 'Text',
    barcode: 'Barcode',
    qrcode: 'QR Code',
    image: 'Image',
    custom: 'Custom',
  }
  return labels[type] ?? type
}

// ── Drag resize ──────────────────────────────────────────────
const activeResize = ref<{
  type: 'col' | 'row'
  idx: number
  startPos: number
  startSize: number
} | null>(null)

function startColResize(colIdx: number, e: MouseEvent): void {
  e.preventDefault()
  e.stopPropagation()
  activeResize.value = {
    type: 'col',
    idx: colIdx,
    startPos: e.clientX,
    startSize: props.format.grid.cellWidths[colIdx],
  }
  emit('col-resize-start', colIdx)
  document.addEventListener('mousemove', onResizeMove)
  document.addEventListener('mouseup', onResizeEnd)
}

function startRowResize(rowIdx: number, e: MouseEvent): void {
  e.preventDefault()
  e.stopPropagation()
  activeResize.value = {
    type: 'row',
    idx: rowIdx,
    startPos: e.clientY,
    startSize: props.format.grid.cellHeights[rowIdx],
  }
  emit('row-resize-start', rowIdx)
  document.addEventListener('mousemove', onResizeMove)
  document.addEventListener('mouseup', onResizeEnd)
}

function onResizeMove(e: MouseEvent): void {
  if (!activeResize.value) return
  const { type, idx, startPos, startSize } = activeResize.value
  if (type === 'col') {
    emit('col-resize', idx, Math.max(20, startSize + e.clientX - startPos))
  } else {
    emit('row-resize', idx, Math.max(20, startSize + e.clientY - startPos))
  }
}

function onResizeEnd(): void {
  activeResize.value = null
  document.removeEventListener('mousemove', onResizeMove)
  document.removeEventListener('mouseup', onResizeEnd)
}
</script>

<template>
  <div class="canvue-canvas-wrapper">
    <!-- Column headers row -->
    <div class="canvue-headers-row">
      <div class="canvue-corner" />
      <div
        v-for="(w, ci) in format.grid.cellWidths"
        :key="ci"
        class="canvue-col-header"
        :style="{ width: `${w}px` }"
      >
        <span class="canvue-header-label">{{ ci + 1 }}</span>
        <button
          class="canvue-header-delete"
          title="Delete column"
          @click.stop="emit('delete-col', ci)"
        >×</button>
        <div class="canvue-col-resize-handle" @mousedown="startColResize(ci, $event)" />
      </div>
      <button class="canvue-add-btn" title="Add column" @click="emit('add-col')">+</button>
    </div>

    <!-- Grid body -->
    <div class="canvue-body-row">
      <!-- Row headers -->
      <div class="canvue-row-headers">
        <div
          v-for="(h, ri) in format.grid.cellHeights"
          :key="ri"
          class="canvue-row-header"
          :style="{ height: `${h}px` }"
        >
          <span class="canvue-header-label">{{ ri + 1 }}</span>
          <button
            class="canvue-header-delete"
            title="Delete row"
            @click.stop="emit('delete-row', ri)"
          >×</button>
          <div class="canvue-row-resize-handle" @mousedown="startRowResize(ri, $event)" />
        </div>
      </div>

      <!-- Main grid canvas -->
      <div
        class="canvue-grid-canvas"
        :style="{
          display: 'grid',
          gridTemplateColumns: format.grid.cellWidths.map(w => `${w}px`).join(' '),
          gridTemplateRows: format.grid.cellHeights.map(h => `${h}px`).join(' '),
          border: '2px solid var(--canvue-grid-border, #94a3b8)',
          gap: '1px',
          background: 'var(--canvue-grid-gap-color, #e2e8f0)',
          width: 'fit-content',
        }"
      >
        <template v-for="(rowCells, rowIdx) in cellMatrix" :key="rowIdx">
          <div
            v-for="(cell, colIdx) in rowCells"
            :key="colIdx"
            class="canvue-cell"
            :class="{
              'canvue-cell--selected': isSelected(rowIdx, colIdx),
              'canvue-cell--occupied': !!cell?.element,
              'canvue-cell--empty': !cell?.element,
            }"
            :style="{
              gridColumn: `${colIdx + 1} / span ${cell?.colSpan ?? 1}`,
              gridRow: `${rowIdx + 1} / span ${cell?.rowSpan ?? 1}`,
            }"
            @click="emit('cell-click', rowIdx, colIdx)"
            @dragover="onDragOver"
            @drop="onDrop($event, rowIdx, colIdx)"
          >
            <template v-if="cell?.element">
              <slot name="cell-content" :cell="cell" :row="rowIdx" :col="colIdx" :element="cell.element">
                <span class="canvue-cell__field-key">{{ cell.element.fieldKey }}</span>
                <span class="canvue-cell__type-tag">{{ typeLabel(cell.element.type) }}</span>
                <button
                  class="canvue-cell__remove"
                  title="Remove element"
                  @click.stop="emit('remove-element', rowIdx, colIdx)"
                >×</button>
              </slot>
            </template>
            <template v-else>
              <slot name="cell-content" :cell="null" :row="rowIdx" :col="colIdx" :element="undefined">
                <span class="canvue-cell__placeholder">drop here</span>
              </slot>
            </template>
          </div>
        </template>
      </div>
    </div>

    <!-- Add row button row -->
    <div class="canvue-add-row-row">
      <div class="canvue-corner" />
      <button class="canvue-add-btn canvue-add-btn--row" @click="emit('add-row')">+ Row</button>
    </div>
  </div>
</template>

<style scoped>
.canvue-canvas-wrapper {
  display: flex;
  flex-direction: column;
  width: fit-content;
  user-select: none;
}

/* ── Headers row ── */
.canvue-headers-row {
  display: flex;
  align-items: stretch;
}

.canvue-corner {
  width: 32px;
  min-width: 32px;
  flex-shrink: 0;
}

.canvue-col-header {
  position: relative;
  height: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--canvue-header-bg, #f1f5f9);
  border: 1px solid var(--canvue-border, #e2e8f0);
  font-size: 10px;
  color: #94a3b8;
  flex-shrink: 0;
  overflow: visible;
  box-sizing: border-box;
}

.canvue-col-header:hover .canvue-header-delete {
  display: flex;
}

/* ── Body row ── */
.canvue-body-row {
  display: flex;
}

.canvue-row-headers {
  width: 32px;
  min-width: 32px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
}

.canvue-row-header {
  position: relative;
  width: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--canvue-header-bg, #f1f5f9);
  border: 1px solid var(--canvue-border, #e2e8f0);
  font-size: 10px;
  color: #94a3b8;
  flex-shrink: 0;
  overflow: visible;
  box-sizing: border-box;
}

.canvue-row-header:hover .canvue-header-delete {
  display: flex;
}

/* ── Header shared ── */
.canvue-header-label {
  pointer-events: none;
}

.canvue-header-delete {
  display: none;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 14px;
  height: 14px;
  background: #ef4444;
  color: #fff;
  border: none;
  border-radius: 50%;
  font-size: 9px;
  line-height: 1;
  cursor: pointer;
  align-items: center;
  justify-content: center;
  padding: 0;
  z-index: 1;
}

/* ── Resize handles ── */
.canvue-col-resize-handle {
  position: absolute;
  right: 0;
  top: 0;
  width: 4px;
  height: 100%;
  cursor: col-resize;
  background: transparent;
}

.canvue-col-resize-handle:hover {
  background: var(--canvue-accent, #3b82f6);
  opacity: 0.5;
}

.canvue-row-resize-handle {
  position: absolute;
  bottom: 0;
  left: 0;
  height: 4px;
  width: 100%;
  cursor: row-resize;
  background: transparent;
}

.canvue-row-resize-handle:hover {
  background: var(--canvue-accent, #3b82f6);
  opacity: 0.5;
}

/* ── Add buttons ── */
.canvue-add-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 22px;
  height: 22px;
  background: var(--canvue-header-bg, #f1f5f9);
  border: 1px dashed var(--canvue-border, #cbd5e1);
  border-radius: 3px;
  font-size: 13px;
  color: #94a3b8;
  cursor: pointer;
  padding: 0 4px;
  align-self: center;
  margin-left: 2px;
  transition: background 0.1s, color 0.1s;
}

.canvue-add-btn:hover {
  background: var(--canvue-accent, #3b82f6);
  color: #fff;
  border-color: var(--canvue-accent, #3b82f6);
}

.canvue-add-row-row {
  display: flex;
  align-items: center;
  margin-top: 2px;
}

.canvue-add-btn--row {
  font-size: 11px;
  height: 20px;
  margin-left: 0;
}

/* ── Grid cells ── */
.canvue-grid-canvas {
  /* styles applied inline via :style */
}

.canvue-cell {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: var(--canvue-cell-bg, #ffffff);
  cursor: pointer;
  transition: background 0.1s;
  overflow: hidden;
  font-size: 11px;
  gap: 2px;
}

.canvue-cell:hover {
  background: var(--canvue-cell-hover-bg, #f0f9ff);
}

.canvue-cell--selected {
  outline: 2px solid var(--canvue-accent, #3b82f6);
  outline-offset: -2px;
  background: var(--canvue-cell-selected-bg, #eff6ff);
}

.canvue-cell--occupied {
  background: var(--canvue-cell-occupied-bg, #f0fdf4);
}

.canvue-cell__field-key {
  font-size: 12px;
  font-weight: 600;
  color: var(--canvue-cell-text, #1e293b);
  max-width: calc(100% - 8px);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: 0 4px;
}

.canvue-cell__type-tag {
  display: inline-flex;
  align-items: center;
  padding: 1px 6px;
  background: color-mix(in srgb, var(--canvue-accent, #3b82f6) 12%, transparent);
  color: var(--canvue-accent, #3b82f6);
  border-radius: 3px;
  font-size: 10px;
  font-weight: 500;
  max-width: calc(100% - 8px);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.canvue-cell__placeholder {
  font-size: 10px;
  color: var(--canvue-placeholder-color, #cbd5e1);
}

.canvue-cell__remove {
  position: absolute;
  top: 2px;
  right: 2px;
  width: 16px;
  height: 16px;
  background: #ef4444;
  color: #fff;
  border: none;
  border-radius: 50%;
  font-size: 10px;
  line-height: 1;
  cursor: pointer;
  display: none;
  align-items: center;
  justify-content: center;
  padding: 0;
}

.canvue-cell:hover .canvue-cell__remove {
  display: flex;
}
</style>
