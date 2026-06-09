import type { LabelFormat } from '../types'

export function serializeFormat(format: LabelFormat): string {
  return JSON.stringify(format, null, 2)
}

export function deserializeFormat(json: string): LabelFormat {
  const parsed = JSON.parse(json) as Record<string, unknown>
  // basic structural validation
  if (!parsed.id || !parsed.grid || !Array.isArray(parsed.cells)) {
    throw new Error('Invalid LabelFormat JSON')
  }
  // Migrate old format: cellWidth/cellHeight (scalars) → cellWidths/cellHeights (arrays)
  const grid = parsed.grid as Record<string, unknown>
  if (typeof grid.cellWidth === 'number' || typeof grid.cellHeight === 'number') {
    const w = typeof grid.cellWidth === 'number' ? grid.cellWidth : 80
    const h = typeof grid.cellHeight === 'number' ? grid.cellHeight : 60
    grid.cellWidths = Array.from({ length: grid.cols as number }, () => w)
    grid.cellHeights = Array.from({ length: grid.rows as number }, () => h)
    delete grid.cellWidth
    delete grid.cellHeight
  }
  return parsed as unknown as LabelFormat
}
