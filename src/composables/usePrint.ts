import type { LabelFormat, DataRecord } from '../types'
import { renderBarcode, renderQrCode } from '../utils/barcode'

export interface PrintOptions {
  title?: string
  pageBreakAfter?: boolean
  /** 인쇄 방식. 'auto'는 window 먼저 시도하고 팝업 차단 시 iframe으로 fallback. */
  mode?: 'window' | 'iframe' | 'auto'
}

export interface PrintError {
  code: 'POPUP_BLOCKED' | 'UNKNOWN' | 'SSR'
  message: string
}

export interface PrintResult {
  success: boolean
  error?: PrintError
}

export function usePrint() {
  async function printLabels(
    format: LabelFormat,
    records: DataRecord[],
    options: PrintOptions = {}
  ): Promise<PrintResult> {
    if (typeof window === 'undefined') {
      return {
        success: false,
        error: { code: 'SSR', message: 'printLabels is not available in SSR context.' },
      }
    }

    const html = await buildPrintHtml(format, records, options)
    const mode = options.mode ?? 'auto'

    if (mode === 'iframe') {
      return printViaIframe(html)
    }

    // mode === 'window' | 'auto': window.open 먼저 시도
    const win = window.open('', '_blank', 'width=800,height=600')
    if (!win) {
      if (mode === 'auto') {
        // 팝업 차단 시 iframe으로 fallback
        return printViaIframe(html)
      }
      return {
        success: false,
        error: {
          code: 'POPUP_BLOCKED',
          message: 'Could not open print window. Check popup blocker settings.',
        },
      }
    }
    win.document.write(html)
    win.document.close()
    win.focus()
    setTimeout(() => {
      win.print()
    }, 300)
    return { success: true }
  }

  return { printLabels }
}

/**
 * 팝업 차단 환경에서 숨김 iframe으로 인쇄 (ADR-004 fallback).
 * iframe은 인쇄 다이얼로그 완료 후 1초 뒤 자동 제거.
 */
function printViaIframe(html: string): PrintResult {
  const iframe = document.createElement('iframe')
  iframe.setAttribute(
    'style',
    'position:fixed;top:0;left:0;width:0;height:0;border:none;visibility:hidden'
  )
  document.body.appendChild(iframe)
  try {
    const doc = iframe.contentDocument
    if (!doc) throw new Error('iframe contentDocument not accessible')
    doc.open()
    doc.write(html)
    doc.close()
    iframe.contentWindow?.focus()
    setTimeout(() => {
      iframe.contentWindow?.print()
      setTimeout(() => {
        if (document.body.contains(iframe)) document.body.removeChild(iframe)
      }, 1000)
    }, 300)
    return { success: true }
  } catch {
    if (document.body.contains(iframe)) document.body.removeChild(iframe)
    return {
      success: false,
      error: { code: 'UNKNOWN', message: 'iframe print failed.' },
    }
  }
}

async function buildPrintHtml(
  format: LabelFormat,
  records: DataRecord[],
  options: PrintOptions
): Promise<string> {
  const { grid } = format
  const labelWidth = grid.cols * grid.cellWidth
  const labelHeight = grid.rows * grid.cellHeight

  const labelParts = await Promise.all(
    records.map(async (record, i) => {
      const pageBreak =
        options.pageBreakAfter && i < records.length - 1
          ? 'page-break-after: always;'
          : ''
      const cells = await buildCells(format, record)
      return `
        <div class="label" style="
          width: ${labelWidth}px;
          height: ${labelHeight}px;
          position: relative;
          display: grid;
          grid-template-columns: repeat(${grid.cols}, ${grid.cellWidth}px);
          grid-template-rows: repeat(${grid.rows}, ${grid.cellHeight}px);
          border: 1px solid #ccc;
          ${pageBreak}
        ">
          ${cells}
        </div>`
    })
  )

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>${options.title ?? format.name}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: sans-serif; background: #fff; }
    .label { margin: 8px; }
    .cell { overflow: hidden; border: 1px solid #e5e5e5; display: flex; align-items: center; justify-content: center; font-size: 12px; }
    .cell img { max-width: 100%; max-height: 100%; object-fit: contain; }
    .cell svg { max-width: 100%; max-height: 100%; }
    @media print {
      body { margin: 0; }
      .label { margin: 0; border: none; }
      .cell { border-color: transparent; }
    }
  </style>
</head>
<body>
  ${labelParts.join('\n')}
</body>
</html>`
}

async function buildCells(format: LabelFormat, record: DataRecord): Promise<string> {
  const { grid, cells } = format
  const result: string[] = []

  for (let r = 0; r < grid.rows; r++) {
    for (let c = 0; c < grid.cols; c++) {
      const cell = cells.find((cl) => cl.row === r && cl.col === c)
      const rowSpan = cell?.rowSpan ?? 1
      const colSpan = cell?.colSpan ?? 1
      let content = ''

      if (cell?.element) {
        const value = String(record[cell.element.fieldKey] ?? '')
        content = await renderCellContent(cell.element.type, value)
      }

      result.push(`
        <div class="cell" style="
          grid-column: ${c + 1} / span ${colSpan};
          grid-row: ${r + 1} / span ${rowSpan};
        ">${content}</div>`)
    }
  }
  return result.join('')
}

async function renderCellContent(type: string, value: string): Promise<string> {
  switch (type) {
    case 'barcode': {
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg') as SVGSVGElement
      try {
        await renderBarcode(svg, value)
        return new XMLSerializer().serializeToString(svg)
      } catch {
        return escapeHtml(value)
      }
    }
    case 'qrcode': {
      const canvas = document.createElement('canvas')
      try {
        await renderQrCode(canvas, value)
        return `<img src="${canvas.toDataURL('image/png')}" />`
      } catch {
        return escapeHtml(value)
      }
    }
    case 'image':
      return `<img src="${escapeHtml(value)}" />`
    default:
      return escapeHtml(value)
  }
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}
