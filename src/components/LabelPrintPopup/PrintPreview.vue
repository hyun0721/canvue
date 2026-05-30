<script setup lang="ts">
import { computed, onMounted, watch, ref } from 'vue'
import type { LabelFormat, DataRecord } from '../../types'
import { renderBarcode, renderQrCode } from '../../utils/barcode'

const props = defineProps<{
  format: LabelFormat
  record: DataRecord
}>()

const gridStyle = computed(() => ({
  display: 'grid',
  gridTemplateColumns: `repeat(${props.format.grid.cols}, ${props.format.grid.cellWidth}px)`,
  gridTemplateRows: `repeat(${props.format.grid.rows}, ${props.format.grid.cellHeight}px)`,
  width: `${props.format.grid.cols * props.format.grid.cellWidth}px`,
  height: `${props.format.grid.rows * props.format.grid.cellHeight}px`,
  border: '1px solid #ccc',
  background: '#fff',
  gap: '1px',
  backgroundColor: '#ddd',
  fontFamily: 'sans-serif',
}))

function cellValue(fieldKey: string): string {
  const val = props.record[fieldKey]
  return val != null ? String(val) : ''
}

/** Stores pre-rendered content keyed by 'row-col': SVG string (barcode) or data URL (qrcode) */
const renderedCells = ref<Record<string, string>>({})

async function prerenderCells(): Promise<void> {
  const result: Record<string, string> = {}
  for (const cell of props.format.cells) {
    if (!cell.element) continue
    const value = cellValue(cell.element.fieldKey)
    const key = `${cell.row}-${cell.col}`

    if (cell.element.type === 'barcode') {
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg') as SVGSVGElement
      try {
        await renderBarcode(svg, value)
        result[key] = new XMLSerializer().serializeToString(svg)
      } catch {
        result[key] = value
      }
    } else if (cell.element.type === 'qrcode') {
      const canvas = document.createElement('canvas')
      try {
        await renderQrCode(canvas, value)
        result[key] = canvas.toDataURL('image/png')
      } catch {
        result[key] = ''
      }
    }
  }
  renderedCells.value = result
}

onMounted(prerenderCells)
watch(() => [props.format, props.record], prerenderCells, { deep: true })
</script>

<template>
  <div class="canvue-print-preview" :style="gridStyle">
    <template
      v-for="cell in format.cells"
      :key="`${cell.row}-${cell.col}`"
    >
      <div
        class="canvue-preview-cell"
        :style="{
          gridColumn: `${cell.col + 1} / span ${cell.colSpan ?? 1}`,
          gridRow: `${cell.row + 1} / span ${cell.rowSpan ?? 1}`,
          width: `${(cell.colSpan ?? 1) * format.grid.cellWidth}px`,
          height: `${(cell.rowSpan ?? 1) * format.grid.cellHeight}px`,
          ...cell.element?.style,
        }"
      >
        <template v-if="cell.element">
          <!-- Barcode: inline SVG pre-rendered in main window context -->
          <!-- eslint-disable-next-line vue/no-v-html -->
          <span
            v-if="cell.element.type === 'barcode'"
            class="canvue-preview-cell__barcode"
            v-html="renderedCells[`${cell.row}-${cell.col}`] || cellValue(cell.element.fieldKey)"
          />
          <!-- QR Code: data URL image -->
          <img
            v-else-if="cell.element.type === 'qrcode'"
            :src="renderedCells[`${cell.row}-${cell.col}`]"
            class="canvue-preview-cell__img"
            alt=""
          />
          <!-- Image: direct URL from record -->
          <img
            v-else-if="cell.element.type === 'image'"
            :src="cellValue(cell.element.fieldKey)"
            class="canvue-preview-cell__img"
            alt=""
          />
          <!-- Text / fallback -->
          <span v-else>{{ cellValue(cell.element.fieldKey) }}</span>
        </template>
      </div>
    </template>
  </div>
</template>

<style scoped>
.canvue-print-preview {
  box-sizing: content-box;
}

.canvue-preview-cell {
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  font-size: 12px;
  padding: 2px;
  box-sizing: border-box;
}

.canvue-preview-cell__barcode :deep(svg) {
  max-width: 100%;
  max-height: 100%;
}

.canvue-preview-cell__img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}
</style>
