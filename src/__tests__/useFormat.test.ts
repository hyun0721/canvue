import { describe, it, expect } from 'vitest'
import { useFormat } from '../composables/useFormat'
import { serializeFormat, deserializeFormat } from '../utils/serialize'
import type { LabelFormat } from '../types'

const sampleFormat: LabelFormat = {
  id: 'test-1',
  name: 'Test Label',
  grid: { rows: 2, cols: 3, cellWidths: [80, 80, 80], cellHeights: [60, 60] },
  cells: [
    { row: 0, col: 0, element: { id: 'el-1', type: 'text', fieldKey: 'name' } },
  ],
  createdAt: '2024-01-01T00:00:00.000Z',
  updatedAt: '2024-01-01T00:00:00.000Z',
}

describe('useFormat', () => {
  it('creates a new format with correct defaults', () => {
    const { createFormat } = useFormat()
    const f = createFormat('My Label', { rows: 3, cols: 4, cellWidths: [100, 100, 100, 100], cellHeights: [70, 70, 70] })
    expect(f.name).toBe('My Label')
    expect(f.grid.rows).toBe(3)
    expect(f.grid.cols).toBe(4)
    expect(f.cells).toHaveLength(0)
    expect(f.id).toBeTruthy()
  })

  it('loads format from JSON', () => {
    const { format, loadFormat } = useFormat()
    loadFormat(JSON.stringify(sampleFormat))
    expect(format.value?.id).toBe('test-1')
    expect(format.value?.name).toBe('Test Label')
  })

  it('exports format to JSON string', () => {
    const { loadFormat, exportFormat } = useFormat()
    loadFormat(JSON.stringify(sampleFormat))
    const json = exportFormat()
    const parsed = JSON.parse(json) as LabelFormat
    expect(parsed.id).toBe('test-1')
  })
})

describe('serialize utils', () => {
  it('round-trips a format', () => {
    const json = serializeFormat(sampleFormat)
    const result = deserializeFormat(json)
    expect(result.id).toBe(sampleFormat.id)
    expect(result.cells).toHaveLength(1)
  })

  it('throws on invalid JSON', () => {
    expect(() => deserializeFormat('{"foo":1}')).toThrow('Invalid LabelFormat JSON')
  })

  it('migrates old cellWidth/cellHeight scalars to arrays', () => {
    const oldFormat = {
      id: 'old-1',
      name: 'Old Label',
      grid: { rows: 2, cols: 3, cellWidth: 80, cellHeight: 60 },
      cells: [],
      createdAt: '2024-01-01T00:00:00.000Z',
      updatedAt: '2024-01-01T00:00:00.000Z',
    }
    const result = deserializeFormat(JSON.stringify(oldFormat))
    expect(result.grid.cellWidths).toEqual([80, 80, 80])
    expect(result.grid.cellHeights).toEqual([60, 60])
    expect((result.grid as unknown as Record<string, unknown>).cellWidth).toBeUndefined()
    expect((result.grid as unknown as Record<string, unknown>).cellHeight).toBeUndefined()
  })
})
