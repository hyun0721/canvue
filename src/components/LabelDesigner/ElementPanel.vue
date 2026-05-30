<script setup lang="ts">
import type { ElementDefinition } from '../../types'

defineProps<{
  elements: ElementDefinition[]
}>()

function onDragStart(e: DragEvent, definition: ElementDefinition): void {
  if (!e.dataTransfer) return
  e.dataTransfer.effectAllowed = 'copy'
  e.dataTransfer.setData('application/canvue-element', JSON.stringify(definition))
}

const typeLabels: Record<ElementDefinition['type'], string> = {
  text: 'Text',
  barcode: 'Barcode',
  qrcode: 'QR Code',
  image: 'Image',
  custom: 'Custom',
}
</script>

<template>
  <div class="canvue-element-panel">
    <div class="canvue-element-panel__header">Elements</div>
    <ul class="canvue-element-panel__list">
      <li
        v-for="def in elements"
        :key="def.key"
        class="canvue-element-item"
        draggable="true"
        @dragstart="onDragStart($event, def)"
      >
        <span class="canvue-element-item__type-badge">{{ typeLabels[def.type] }}</span>
        <span class="canvue-element-item__label">{{ def.label }}</span>
        <span class="canvue-element-item__key">{{ def.key }}</span>
      </li>
    </ul>
    <p v-if="elements.length === 0" class="canvue-element-panel__empty">
      No elements provided.
    </p>
  </div>
</template>

<style scoped>
.canvue-element-panel {
  min-width: 180px;
  background: var(--canvue-panel-bg, #f8fafc);
  border: 1px solid var(--canvue-panel-border, #e2e8f0);
  border-radius: 6px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.canvue-element-panel__header {
  padding: 8px 12px;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #64748b;
  background: var(--canvue-panel-header-bg, #f1f5f9);
  border-bottom: 1px solid var(--canvue-panel-border, #e2e8f0);
}

.canvue-element-panel__list {
  list-style: none;
  margin: 0;
  padding: 6px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.canvue-element-panel__empty {
  padding: 12px;
  font-size: 12px;
  color: #94a3b8;
  text-align: center;
}

.canvue-element-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 8px 10px;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  cursor: grab;
  transition: box-shadow 0.15s, border-color 0.15s;
}

.canvue-element-item:hover {
  border-color: var(--canvue-accent, #3b82f6);
  box-shadow: 0 1px 4px rgba(59, 130, 246, 0.15);
}

.canvue-element-item:active {
  cursor: grabbing;
}

.canvue-element-item__type-badge {
  display: inline-block;
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--canvue-accent, #3b82f6);
  background: #eff6ff;
  padding: 1px 5px;
  border-radius: 3px;
  width: fit-content;
}

.canvue-element-item__label {
  font-size: 13px;
  font-weight: 500;
  color: #1e293b;
}

.canvue-element-item__key {
  font-size: 11px;
  color: #94a3b8;
  font-family: monospace;
}
</style>
