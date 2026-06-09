<script setup lang="ts">
import { ref } from 'vue'
import LabelDesigner from '../components/LabelDesigner/LabelDesigner.vue'
import LabelPrintPopup from '../components/LabelPrintPopup/LabelPrintPopup.vue'
import type { LabelFormat, ElementDefinition, DataRecord } from '../types'

const elements: ElementDefinition[] = [
  { key: 'productName', label: 'Product Name', type: 'text' },
  { key: 'sku', label: 'SKU', type: 'text', defaultStyle: { fontFamily: 'monospace' } },
  { key: 'barcode', label: 'Barcode', type: 'barcode' },
  { key: 'qr', label: 'QR Code', type: 'qrcode' },
  { key: 'price', label: 'Price', type: 'text' },
  { key: 'origin', label: 'Origin', type: 'text' },
]

const records: DataRecord[] = [
  { productName: 'Widget A', sku: 'WGT-001', barcode: '012345678905', qr: 'https://example.com/WGT-001', price: '$4.99', origin: 'Korea' },
  { productName: 'Widget B', sku: 'WGT-002', barcode: '012345678906', qr: 'https://example.com/WGT-002', price: '$7.99', origin: 'USA' },
  { productName: 'Gadget X', sku: 'GDG-010', barcode: '012345678907', qr: 'https://example.com/GDG-010', price: '$24.99', origin: 'Japan' },
]

const currentFormat = ref<LabelFormat | undefined>(undefined)
const printVisible = ref(false)
const savedJson = ref('')

function onSave(format: LabelFormat) {
  savedJson.value = JSON.stringify(format, null, 2)
  console.log('Saved format:', format)
}

function onUpdate(format: LabelFormat) {
  currentFormat.value = format
}
</script>

<template>
  <div style="padding: 24px; max-width: 1200px; margin: 0 auto; font-family: system-ui, sans-serif;">
    <h1 style="margin-bottom: 4px; font-size: 22px;">Canvue Playground</h1>
    <p style="color: #64748b; margin-bottom: 24px; font-size: 14px;">
      Drag elements from the right panel onto the grid cells to design your label.
    </p>

    <LabelDesigner
      :elements="elements"
      :model-value="currentFormat"
      :grid-config="{ rows: 3, cols: 4, cellWidths: [100, 100, 100, 100], cellHeights: [70, 70, 70] }"
      @update:model-value="onUpdate"
      @save="onSave"
    />

    <div style="margin-top: 16px; display: flex; gap: 12px;">
      <button
        style="padding: 8px 18px; background: #3b82f6; color: #fff; border: none; border-radius: 4px; cursor: pointer; font-size: 14px;"
        :disabled="!currentFormat"
        @click="printVisible = true"
      >
        Open Print Popup ({{ records.length }} records)
      </button>
    </div>

    <LabelPrintPopup
      v-if="currentFormat"
      :format="currentFormat"
      :records="records"
      :open="printVisible"
      @update:open="printVisible = $event"
    />

    <details v-if="savedJson" style="margin-top: 24px;">
      <summary style="cursor: pointer; font-size: 13px; color: #475569;">Saved JSON</summary>
      <pre style="background: #f8fafc; padding: 12px; border-radius: 6px; font-size: 12px; overflow: auto; margin-top: 8px;">{{ savedJson }}</pre>
    </details>
  </div>
</template>
