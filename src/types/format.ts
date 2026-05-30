import type { CSSProperties } from 'vue'

export interface GridConfig {
  rows: number
  cols: number
  cellWidth: number  // px
  cellHeight: number // px
}

export interface LabelElement {
  id: string
  type: 'text' | 'barcode' | 'qrcode' | 'image' | 'custom'
  fieldKey: string       // bound to a key from the consumer's data record
  style?: CSSProperties
}

export interface LabelCell {
  row: number
  col: number
  rowSpan?: number
  colSpan?: number
  element?: LabelElement
}

export interface LabelFormat {
  id: string
  name: string
  grid: GridConfig
  cells: LabelCell[]
  createdAt: string
  updatedAt: string
}

/** Injected by the consumer to describe each draggable element in the panel */
export interface ElementDefinition {
  key: string
  label: string
  type: LabelElement['type']
  defaultStyle?: CSSProperties
}

/** A data record provided at print time; keys match LabelElement.fieldKey */
export type DataRecord = Record<string, unknown>
