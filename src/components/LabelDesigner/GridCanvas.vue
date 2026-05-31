<script setup lang="ts">
import { computed } from 'vue'
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
}>()

const canvasStyle = computed(() => ({
  display: 'grid',
  gridTemplateColumns: `repeat(${props.format.grid.cols}, ${props.format.grid.cellWidth}px)`,
  gridTemplateRows: `repeat(${props.format.grid.rows}, ${props.format.grid.cellHeight}px)`,
  border: '2px solid var(--canvue-grid-border, #94a3b8)',
  gap: '1px',
  background: 'var(--canvue-grid-gap-color, #e2e8f0)',
  width: 'fit-content',
}))

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

function typeIcon(type: string): string {
  const icons: Record<string, string> = {
    text: 'T',
    barcode: '▌▌',
    qrcode: '⊞',
    image: '🖼',
    custom: '✦',
  }
  return icons[type] ?? '?'
}
</script>

<template>
  <div class="canvue-grid-canvas" :style="canvasStyle">
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
          width: `${format.grid.cellWidth}px`,
          height: `${format.grid.cellHeight}px`,
          gridColumn: `${colIdx + 1} / span ${cell?.colSpan ?? 1}`,
          gridRow: `${rowIdx + 1} / span ${cell?.rowSpan ?? 1}`,
        }"
        @click="emit('cell-click', rowIdx, colIdx)"
        @dragover="onDragOver"
        @drop="onDrop($event, rowIdx, colIdx)"
      >
        <template v-if="cell?.element">
          <slot name="cell-content" :cell="cell" :row="rowIdx" :col="colIdx" :element="cell.element">
            <span class="canvue-cell__type-icon">{{ typeIcon(cell.element.type) }}</span>
            <span class="canvue-cell__field-key">{{ cell.element.fieldKey }}</span>
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
</template>

<style scoped>
.canvue-grid-canvas {
  user-select: none;
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

.canvue-cell__type-icon {
  font-size: 14px;
  font-weight: 700;
  color: var(--canvue-accent, #3b82f6);
}

.canvue-cell__field-key {
  font-size: 10px;
  color: #64748b;
  max-width: 100%;
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
