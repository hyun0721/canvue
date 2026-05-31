<script setup lang="ts">
import type { LabelFormat, DataRecord } from '../../types'
import type { PrintOptions, PrintError } from '../../composables/usePrint'
import { usePrint } from '../../composables/usePrint'
import PrintPreview from './PrintPreview.vue'

const props = defineProps<{
  format: LabelFormat
  records: DataRecord[]
  open: boolean
  printOptions?: PrintOptions
}>()

const emit = defineEmits<{
  'update:open': [value: boolean]
  'close': []
  'print-success': []
  'print-error': [error: PrintError]
}>()

const { printLabels } = usePrint()

function handleClose(): void {
  emit('update:open', false)
  emit('close')
}

async function handlePrint(): Promise<void> {
  const result = await printLabels(props.format, props.records, props.printOptions)
  if (result.success) {
    emit('print-success')
  } else if (result.error) {
    emit('print-error', result.error)
  }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="canvue-popup">
      <div v-if="open" class="canvue-popup-overlay" @click.self="handleClose">
        <div class="canvue-popup">
          <div class="canvue-popup__header">
            <span class="canvue-popup__title">Print Preview — {{ format.name }}</span>
            <button class="canvue-popup__close" @click="handleClose">×</button>
          </div>

          <div class="canvue-popup__body">
            <p class="canvue-popup__meta">{{ records.length }} record(s)</p>
            <div class="canvue-popup__preview-area">
              <PrintPreview
                v-for="(record, i) in records"
                :key="i"
                :format="format"
                :record="record"
              />
            </div>
          </div>

          <div class="canvue-popup__footer">
            <button class="canvue-btn canvue-btn--secondary" @click="handleClose">Cancel</button>
            <button class="canvue-btn canvue-btn--primary" @click="handlePrint">Print</button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.canvue-popup-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: var(--canvue-popup-z, 9999);
}

.canvue-popup {
  background: #fff;
  border-radius: 8px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.25);
  max-width: 90vw;
  max-height: 90vh;
  width: auto;
  min-width: 400px;
  display: flex;
  flex-direction: column;
  font-family: var(--canvue-font, system-ui, sans-serif);
  overflow: hidden;
}

.canvue-popup__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 20px;
  border-bottom: 1px solid #e2e8f0;
  background: #f8fafc;
}

.canvue-popup__title {
  font-size: 15px;
  font-weight: 600;
  color: #1e293b;
}

.canvue-popup__close {
  background: none;
  border: none;
  font-size: 20px;
  line-height: 1;
  cursor: pointer;
  color: #94a3b8;
  padding: 0 4px;
}

.canvue-popup__close:hover {
  color: #475569;
}

.canvue-popup__body {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
}

.canvue-popup__meta {
  font-size: 12px;
  color: #64748b;
  margin-bottom: 12px;
}

.canvue-popup__preview-area {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  align-items: flex-start;
}

.canvue-popup__footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  padding: 14px 20px;
  border-top: 1px solid #e2e8f0;
  background: #f8fafc;
}

.canvue-btn {
  padding: 8px 18px;
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

.canvue-btn--secondary {
  background: #f1f5f9;
  color: #475569;
}

.canvue-btn--secondary:hover {
  background: #e2e8f0;
}

/* Transition */
.canvue-popup-enter-active,
.canvue-popup-leave-active {
  transition: opacity 0.2s ease;
}

.canvue-popup-enter-active .canvue-popup,
.canvue-popup-leave-active .canvue-popup {
  transition: transform 0.2s ease;
}

.canvue-popup-enter-from,
.canvue-popup-leave-to {
  opacity: 0;
}

.canvue-popup-enter-from .canvue-popup,
.canvue-popup-leave-to .canvue-popup {
  transform: scale(0.95);
}
</style>
