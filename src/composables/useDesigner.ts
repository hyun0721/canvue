import { ref, computed } from 'vue'
import type { LabelFormat, LabelCell, LabelElement, ElementDefinition, GridConfig } from '../types'

function generateId(): string {
  const g = (globalThis as unknown as { crypto?: { randomUUID?: () => string } }).crypto
  if (g?.randomUUID) return `el-${g.randomUUID()}`
  return `el-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}

const DEFAULT_GRID: GridConfig = {
  rows: 4,
  cols: 4,
  cellWidth: 80,
  cellHeight: 60,
}

export function useDesigner(initialFormat?: LabelFormat) {
  const format = ref<LabelFormat>(
    initialFormat ?? {
      id: generateId(),
      name: 'New Label',
      grid: { ...DEFAULT_GRID },
      cells: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }
  )

  const selectedCell = ref<{ row: number; col: number } | null>(null)

  /** Derive a flat matrix for easier template rendering */
  const cellMatrix = computed<(LabelCell | null)[][]>(() => {
    const { rows, cols } = format.value.grid
    const matrix: (LabelCell | null)[][] = Array.from({ length: rows }, () =>
      Array(cols).fill(null)
    )
    for (const cell of format.value.cells) {
      if (cell.row < rows && cell.col < cols) {
        matrix[cell.row][cell.col] = cell
      }
    }
    return matrix
  })

  function getCellAt(row: number, col: number): LabelCell | undefined {
    return format.value.cells.find((c) => c.row === row && c.col === col)
  }

  function placeElement(row: number, col: number, definition: ElementDefinition): void {
    const existing = getCellAt(row, col)
    const element: LabelElement = {
      id: generateId(),
      type: definition.type,
      fieldKey: definition.key,
      style: definition.defaultStyle ? { ...definition.defaultStyle } : undefined,
    }

    if (existing) {
      existing.element = element
    } else {
      format.value.cells.push({ row, col, element })
    }
    touch()
  }

  function removeElement(row: number, col: number): void {
    const idx = format.value.cells.findIndex((c) => c.row === row && c.col === col)
    if (idx !== -1) {
      format.value.cells.splice(idx, 1)
      touch()
    }
  }

  function selectCell(row: number, col: number): void {
    selectedCell.value = { row, col }
  }

  function clearSelection(): void {
    selectedCell.value = null
  }

  function updateGrid(config: Partial<GridConfig>): void {
    format.value.grid = { ...format.value.grid, ...config }
    // Remove out-of-bounds cells
    format.value.cells = format.value.cells.filter(
      (c) => c.row < format.value.grid.rows && c.col < format.value.grid.cols
    )
    touch()
  }

  function renameFormat(name: string): void {
    format.value.name = name
    touch()
  }

  function resetFormat(newFormat?: LabelFormat): void {
    format.value = newFormat ?? {
      id: generateId(),
      name: 'New Label',
      grid: { ...DEFAULT_GRID },
      cells: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }
  }

  function touch(): void {
    format.value.updatedAt = new Date().toISOString()
  }

  return {
    format,
    selectedCell,
    cellMatrix,
    getCellAt,
    placeElement,
    removeElement,
    selectCell,
    clearSelection,
    updateGrid,
    renameFormat,
    resetFormat,
  }
}
