import { describe, it, expect } from 'vitest'
import { useDesigner } from '../composables/useDesigner'
import type { ElementDefinition } from '../types'

const textEl: ElementDefinition = {
  key: 'productName',
  label: 'Product Name',
  type: 'text',
}

describe('useDesigner', () => {
  it('initializes with default format', () => {
    const { format } = useDesigner()
    expect(format.value.grid.rows).toBe(4)
    expect(format.value.grid.cols).toBe(4)
    expect(format.value.cells).toHaveLength(0)
  })

  it('places an element in a cell', () => {
    const { format, placeElement } = useDesigner()
    placeElement(0, 0, textEl)
    expect(format.value.cells).toHaveLength(1)
    expect(format.value.cells[0].element?.fieldKey).toBe('productName')
    expect(format.value.cells[0].element?.type).toBe('text')
  })

  it('replaces existing element in a cell', () => {
    const { format, placeElement } = useDesigner()
    placeElement(0, 0, textEl)
    placeElement(0, 0, { key: 'sku', label: 'SKU', type: 'barcode' })
    expect(format.value.cells).toHaveLength(1)
    expect(format.value.cells[0].element?.fieldKey).toBe('sku')
  })

  it('removes an element from a cell', () => {
    const { format, placeElement, removeElement } = useDesigner()
    placeElement(1, 2, textEl)
    expect(format.value.cells).toHaveLength(1)
    removeElement(1, 2)
    expect(format.value.cells).toHaveLength(0)
  })

  it('cellMatrix reflects placed elements', () => {
    const { cellMatrix, placeElement } = useDesigner()
    placeElement(0, 1, textEl)
    expect(cellMatrix.value[0][1]?.element?.fieldKey).toBe('productName')
    expect(cellMatrix.value[0][0]).toBeNull()
  })

  it('updates grid config', () => {
    const { format, updateGrid } = useDesigner()
    updateGrid({ rows: 6, cols: 5 })
    expect(format.value.grid.rows).toBe(6)
    expect(format.value.grid.cols).toBe(5)
  })

  it('removes out-of-bounds cells after grid shrink', () => {
    const { format, placeElement, updateGrid } = useDesigner()
    placeElement(3, 3, textEl)
    expect(format.value.cells).toHaveLength(1)
    updateGrid({ rows: 2, cols: 2 })
    expect(format.value.cells).toHaveLength(0)
  })

  it('selects and clears selection', () => {
    const { selectedCell, selectCell, clearSelection } = useDesigner()
    selectCell(2, 3)
    expect(selectedCell.value).toEqual({ row: 2, col: 3 })
    clearSelection()
    expect(selectedCell.value).toBeNull()
  })
})
