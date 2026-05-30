import { ref } from 'vue'
import type { LabelFormat, GridConfig } from '../types'
import { serializeFormat, deserializeFormat } from '../utils/serialize'

function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}

export function useFormat() {
  const format = ref<LabelFormat | null>(null)

  function createFormat(name: string, grid: GridConfig): LabelFormat {
    const now = new Date().toISOString()
    return {
      id: generateId(),
      name,
      grid,
      cells: [],
      createdAt: now,
      updatedAt: now,
    }
  }

  function loadFormat(json: string): void {
    format.value = deserializeFormat(json)
  }

  function exportFormat(): string {
    if (!format.value) throw new Error('No format to export')
    return serializeFormat(format.value)
  }

  function downloadFormat(filename?: string): void {
    const json = exportFormat()
    const blob = new Blob([json], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename ?? `${format.value?.name ?? 'label'}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  return { format, createFormat, loadFormat, exportFormat, downloadFormat }
}
