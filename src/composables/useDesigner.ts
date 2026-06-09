import { ref, computed } from 'vue'
import type { LabelFormat, LabelCell, LabelElement, ElementDefinition, GridConfig } from '../types'

function generateId(): string {
  const g = (globalThis as unknown as { crypto?: { randomUUID?: () => string } }).crypto
  if (g?.randomUUID) return `el-${g.randomUUID()}`
  return `el-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}

const DEFAULT_CELL_WIDTH = 80
const DEFAULT_CELL_HEIGHT = 60
const MAX_HISTORY = 50

function makeDefaultGrid(): GridConfig {
  return {
    rows: 4,
    cols: 4,
    cellWidths: Array(4).fill(DEFAULT_CELL_WIDTH) as number[],
    cellHeights: Array(4).fill(DEFAULT_CELL_HEIGHT) as number[],
  }
}

export function useDesigner(initialFormat?: LabelFormat) {
  const format = ref<LabelFormat>(
    initialFormat ?? {
      id: generateId(),
      name: 'New Label',
      grid: makeDefaultGrid(),
      cells: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }
  )

  const selectedCell = ref<{ row: number; col: number } | null>(null)
  const history = ref<string[]>([])

  const canUndo = computed(() => history.value.length > 0)

  function snapshot(): void {
    history.value.push(JSON.stringify(format.value))
    if (history.value.length > MAX_HISTORY) {
      history.value.splice(0, history.value.length - MAX_HISTORY)
    }
  }

  function undo(): void {
    const snap = history.value.pop()
    if (snap) {
      format.value = JSON.parse(snap) as LabelFormat
    }
  }

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
    snapshot()
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
    snapshot()
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

  function updateGrid(config: Partial<GridConfig>, skipSnapshot = false): LabelCell[] {
    if (!skipSnapshot) snapshot()
    const grid = format.value.grid
    const newRows = config.rows ?? grid.rows
    const newCols = config.cols ?? grid.cols

    // Sync cellWidths
    let newCellWidths = config.cellWidths ? [...config.cellWidths] : [...grid.cellWidths]
    if (newCellWidths.length < newCols) {
      const fill = newCellWidths[newCellWidths.length - 1] ?? DEFAULT_CELL_WIDTH
      while (newCellWidths.length < newCols) newCellWidths.push(fill)
    } else if (newCellWidths.length > newCols) {
      newCellWidths = newCellWidths.slice(0, newCols)
    }

    // Sync cellHeights
    let newCellHeights = config.cellHeights ? [...config.cellHeights] : [...grid.cellHeights]
    if (newCellHeights.length < newRows) {
      const fill = newCellHeights[newCellHeights.length - 1] ?? DEFAULT_CELL_HEIGHT
      while (newCellHeights.length < newRows) newCellHeights.push(fill)
    } else if (newCellHeights.length > newRows) {
      newCellHeights = newCellHeights.slice(0, newRows)
    }

    const newGrid: GridConfig = { rows: newRows, cols: newCols, cellWidths: newCellWidths, cellHeights: newCellHeights }
    const removed = format.value.cells.filter((c) => c.row >= newRows || c.col >= newCols)
    format.value.grid = newGrid
    format.value.cells = format.value.cells.filter((c) => c.row < newRows && c.col < newCols)
    touch()
    return removed
  }

  function addRow(): void {
    snapshot()
    const grid = format.value.grid
    const lastH = grid.cellHeights[grid.cellHeights.length - 1] ?? DEFAULT_CELL_HEIGHT
    format.value.grid = {
      ...grid,
      rows: grid.rows + 1,
      cellHeights: [...grid.cellHeights, lastH],
    }
    touch()
  }

  function deleteRow(rowIdx: number): void {
    snapshot()
    const grid = format.value.grid
    if (grid.rows <= 1) return
    format.value.grid = {
      ...grid,
      rows: grid.rows - 1,
      cellHeights: grid.cellHeights.filter((_, i) => i !== rowIdx),
    }
    format.value.cells = format.value.cells
      .filter((c) => c.row !== rowIdx)
      .map((c) => (c.row > rowIdx ? { ...c, row: c.row - 1 } : c))
    touch()
  }

  function addCol(): void {
    snapshot()
    const grid = format.value.grid
    const lastW = grid.cellWidths[grid.cellWidths.length - 1] ?? DEFAULT_CELL_WIDTH
    format.value.grid = {
      ...grid,
      cols: grid.cols + 1,
      cellWidths: [...grid.cellWidths, lastW],
    }
    touch()
  }

  function deleteCol(colIdx: number): void {
    snapshot()
    const grid = format.value.grid
    if (grid.cols <= 1) return
    format.value.grid = {
      ...grid,
      cols: grid.cols - 1,
      cellWidths: grid.cellWidths.filter((_, i) => i !== colIdx),
    }
    format.value.cells = format.value.cells
      .filter((c) => c.col !== colIdx)
      .map((c) => (c.col > colIdx ? { ...c, col: c.col - 1 } : c))
    touch()
  }

  /** updateColWidth/updateRowHeight do NOT snapshot — caller should call snapshot() before a drag sequence */
  function updateColWidth(colIdx: number, width: number): void {
    const newWidths = [...format.value.grid.cellWidths]
    newWidths[colIdx] = Math.max(20, width)
    format.value.grid = { ...format.value.grid, cellWidths: newWidths }
    touch()
  }

  function updateRowHeight(rowIdx: number, height: number): void {
    const newHeights = [...format.value.grid.cellHeights]
    newHeights[rowIdx] = Math.max(20, height)
    format.value.grid = { ...format.value.grid, cellHeights: newHeights }
    touch()
  }

  function updateSpan(row: number, col: number, rowSpan: number, colSpan: number): void {
    const cell = getCellAt(row, col)
    if (cell) {
      snapshot()
      cell.rowSpan = Math.max(1, rowSpan)
      cell.colSpan = Math.max(1, colSpan)
      touch()
    }
  }

  function renameFormat(name: string): void {
    format.value.name = name
    touch()
  }

  function resetFormat(newFormat?: LabelFormat): void {
    format.value = newFormat ?? {
      id: generateId(),
      name: 'New Label',
      grid: makeDefaultGrid(),
      cells: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }
    history.value = []
  }

  function touch(): void {
    format.value.updatedAt = new Date().toISOString()
  }

  return {
    format,
    selectedCell,
    cellMatrix,
    canUndo,
    getCellAt,
    placeElement,
    removeElement,
    selectCell,
    clearSelection,
    updateGrid,
    addRow,
    deleteRow,
    addCol,
    deleteCol,
    updateColWidth,
    updateRowHeight,
    updateSpan,
    renameFormat,
    resetFormat,
    snapshot,
    undo,
  }
}
