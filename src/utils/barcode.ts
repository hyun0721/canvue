/**
 * Thin wrappers around JsBarcode and qrcode.
 * Both libraries are loaded lazily to avoid SSR/build issues.
 */

export async function renderBarcode(
  svgOrCanvas: SVGSVGElement | HTMLCanvasElement,
  value: string,
  options: Record<string, unknown> = {}
): Promise<void> {
  const JsBarcode = (await import('jsbarcode')).default
  JsBarcode(svgOrCanvas, value, {
    format: 'CODE128',
    displayValue: true,
    fontSize: 12,
    margin: 4,
    ...options,
  })
}

export async function renderQrCode(
  canvas: HTMLCanvasElement,
  value: string,
  options: Record<string, unknown> = {}
): Promise<void> {
  const QRCode = await import('qrcode')
  await QRCode.toCanvas(canvas, value, {
    width: 128,
    margin: 1,
    ...options,
  })
}
