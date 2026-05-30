// Components
export { default as LabelDesigner } from './components/LabelDesigner/LabelDesigner.vue'
export { default as LabelPrintPopup } from './components/LabelPrintPopup/LabelPrintPopup.vue'

// Composables
export { useDesigner } from './composables/useDesigner'
export { useFormat } from './composables/useFormat'
export { usePrint } from './composables/usePrint'
export type { PrintOptions, PrintResult, PrintError } from './composables/usePrint'

// Types
export type {
  LabelFormat,
  LabelCell,
  LabelElement,
  ElementDefinition,
  DataRecord,
  GridConfig,
} from './types'

// Utils (exported for advanced use cases)
export { serializeFormat, deserializeFormat } from './utils/serialize'
export { renderBarcode, renderQrCode } from './utils/barcode'
