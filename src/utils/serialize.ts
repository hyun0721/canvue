import type { LabelFormat } from '../types'

export function serializeFormat(format: LabelFormat): string {
  return JSON.stringify(format, null, 2)
}

export function deserializeFormat(json: string): LabelFormat {
  const parsed = JSON.parse(json) as LabelFormat
  // basic structural validation
  if (!parsed.id || !parsed.grid || !Array.isArray(parsed.cells)) {
    throw new Error('Invalid LabelFormat JSON')
  }
  return parsed
}
