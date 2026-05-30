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
    </template>
    <p v-else class="canvue-cell-editor__empty">No element in this cell.</p>
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
</style>
