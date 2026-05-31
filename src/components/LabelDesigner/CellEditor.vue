<script setup lang="ts">
import { computed } from 'vue'
import type { CSSProperties } from 'vue'
import type { LabelCell, LabelFormat } from '../../types'

const props = defineProps<{
  cell: LabelCell | null
  format: LabelFormat
  row: number
  col: number
}>()

const emit = defineEmits<{
  'update-style': [row: number, col: number, style: Partial<CSSProperties>]
  'update-span': [row: number, col: number, rowSpan: number, colSpan: number]
  'close': []
}>()

const element = computed(() => props.cell?.element)

function updateFontSize(e: Event): void {
  const val = (e.target as HTMLInputElement).value
  if (!element.value) return
  emit('update-style', props.row, props.col, { fontSize: `${val}px` })
}

function updateTextAlign(align: string): void {
  emit('update-style', props.row, props.col, { textAlign: align as CSSProperties['textAlign'] })
}

function updateColor(e: Event): void {
  emit('update-style', props.row, props.col, { color: (e.target as HTMLInputElement).value })
}

function updateFontWeight(e: Event): void {
  const val = (e.target as HTMLSelectElement).value
  emit('update-style', props.row, props.col, { fontWeight: val as CSSProperties['fontWeight'] })
}

function updateFontFamily(e: Event): void {
  emit('update-style', props.row, props.col, { fontFamily: (e.target as HTMLInputElement).value })
}

function updateBgColor(e: Event): void {
  emit('update-style', props.row, props.col, { backgroundColor: (e.target as HTMLInputElement).value })
}

function updatePadding(e: Event): void {
  const val = (e.target as HTMLInputElement).value
  emit('update-style', props.row, props.col, { padding: `${val}px` })
}

function updateRowSpan(e: Event): void {
  const val = parseInt((e.target as HTMLInputElement).value)
  if (!isNaN(val) && val >= 1) {
    emit('update-span', props.row, props.col, val, props.cell?.colSpan ?? 1)
  }
}

function updateColSpan(e: Event): void {
  const val = parseInt((e.target as HTMLInputElement).value)
  if (!isNaN(val) && val >= 1) {
    emit('update-span', props.row, props.col, props.cell?.rowSpan ?? 1, val)
  }
}
</script>

<template>
  <div v-if="cell" class="canvue-cell-editor">
    <div class="canvue-cell-editor__header">
      <span>Cell ({{ row }}, {{ col }})</span>
      <button class="canvue-cell-editor__close" @click="emit('close')">×</button>
    </div>

    <template v-if="element">
      <div class="canvue-cell-editor__row">
        <label>Field Key</label>
        <code>{{ element.fieldKey }}</code>
      </div>
      <div class="canvue-cell-editor__row">
        <label>Type</label>
        <span>{{ element.type }}</span>
      </div>
      <div class="canvue-cell-editor__row">
        <label>Font Size (px)</label>
        <input
          type="number"
          min="8"
          max="72"
          :value="parseInt(String(element.style?.fontSize ?? '12'))"
          @change="updateFontSize"
        />
      </div>
      <div class="canvue-cell-editor__row canvue-cell-editor__row--align">
        <label>Text Align</label>
        <div class="canvue-align-buttons">
          <button
            v-for="align in ['left', 'center', 'right']"
            :key="align"
            :class="{ active: element.style?.textAlign === align }"
            @click="updateTextAlign(align)"
          >{{ align }}</button>
        </div>
      </div>
      <div class="canvue-cell-editor__row">
        <label>Color</label>
        <input type="color" :value="element.style?.color ?? '#000000'" @change="updateColor" />
      </div>
      <div class="canvue-cell-editor__row">
        <label>Font Weight</label>
        <select :value="element.style?.fontWeight ?? 'normal'" @change="updateFontWeight">
          <option value="normal">Normal</option>
          <option value="bold">Bold</option>
          <option value="600">600</option>
        </select>
      </div>
      <div class="canvue-cell-editor__row">
        <label>Font Family</label>
        <input
          type="text"
          :value="element.style?.fontFamily ?? ''"
          placeholder="sans-serif"
          @change="updateFontFamily"
        />
      </div>
      <div class="canvue-cell-editor__row">
        <label>BG Color</label>
        <input
          type="color"
          :value="element.style?.backgroundColor ?? '#ffffff'"
          @change="updateBgColor"
        />
      </div>
      <div class="canvue-cell-editor__row">
        <label>Padding (px)</label>
        <input
          type="number"
          min="0"
          max="40"
          :value="parseInt(String(element.style?.padding ?? '0'))"
          @change="updatePadding"
        />
      </div>
    </template>
    <template v-if="cell">
      <div class="canvue-cell-editor__section-title">Cell Span</div>
      <div class="canvue-cell-editor__row">
        <label>Row Span</label>
        <input
          type="number"
          min="1"
          :max="format.grid.rows - row"
          :value="cell.rowSpan ?? 1"
          @change="updateRowSpan"
        />
      </div>
      <div class="canvue-cell-editor__row">
        <label>Col Span</label>
        <input
          type="number"
          min="1"
          :max="format.grid.cols - col"
          :value="cell.colSpan ?? 1"
          @change="updateColSpan"
        />
      </div>
    </template>
    <p v-if="!element && cell" class="canvue-cell-editor__empty">No element in this cell.</p>
  </div>
</template>

<style scoped>
.canvue-cell-editor {
  min-width: 220px;
  background: var(--canvue-panel-bg, #f8fafc);
  border: 1px solid var(--canvue-panel-border, #e2e8f0);
  border-radius: 6px;
  overflow: hidden;
  font-size: 13px;
}

.canvue-cell-editor__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  background: var(--canvue-panel-header-bg, #f1f5f9);
  border-bottom: 1px solid var(--canvue-panel-border, #e2e8f0);
  font-size: 12px;
  font-weight: 600;
  color: #475569;
}

.canvue-cell-editor__close {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 16px;
  line-height: 1;
  color: #94a3b8;
  padding: 0 2px;
}

.canvue-cell-editor__row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  border-bottom: 1px solid #f1f5f9;
  gap: 8px;
}

.canvue-cell-editor__row label {
  color: #64748b;
  white-space: nowrap;
}

.canvue-cell-editor__row code {
  font-family: monospace;
  font-size: 12px;
  background: #f1f5f9;
  padding: 1px 5px;
  border-radius: 3px;
}

.canvue-cell-editor__row input[type='number'] {
  width: 64px;
  padding: 3px 6px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 13px;
}

.canvue-align-buttons {
  display: flex;
  gap: 4px;
}

.canvue-align-buttons button {
  padding: 3px 8px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  background: #fff;
  cursor: pointer;
  font-size: 11px;
  color: #64748b;
  text-transform: capitalize;
}

.canvue-align-buttons button.active {
  background: var(--canvue-accent, #3b82f6);
  color: #fff;
  border-color: var(--canvue-accent, #3b82f6);
}

.canvue-cell-editor__empty {
  padding: 12px;
  color: #94a3b8;
  font-size: 12px;
  text-align: center;
}

.canvue-cell-editor__section-title {
  padding: 6px 12px 4px;
  font-size: 11px;
  font-weight: 600;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border-top: 1px solid #f1f5f9;
  background: var(--canvue-panel-header-bg, #f1f5f9);
}

.canvue-cell-editor__row input[type='color'] {
  width: 36px;
  height: 26px;
  padding: 0 2px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  cursor: pointer;
}

.canvue-cell-editor__row select {
  padding: 3px 6px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 13px;
  background: #fff;
}

.canvue-cell-editor__row input[type='text'] {
  width: 100px;
  padding: 3px 6px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 12px;
}
</style>
