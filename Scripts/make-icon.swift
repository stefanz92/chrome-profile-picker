import AppKit

// Renders the 1024px app icon PNG to the path given as the first argument.
let outputPath = CommandLine.arguments[1]
let canvas: CGFloat = 1024

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
NSColor.black.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(
    starting: NSColor(srgbRed: 0.31, green: 0.56, blue: 0.98, alpha: 1),
    ending: NSColor(srgbRed: 0.40, green: 0.27, blue: 0.86, alpha: 1)
)!.draw(in: shape, angle: -90)

let configuration = NSImage.SymbolConfiguration(pointSize: 420, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(configuration) {
    let size = symbol.size
    symbol.draw(in: NSRect(x: (canvas - size.width) / 2, y: (canvas - size.height) / 2, width: size.width, height: size.height))
}

NSGraphicsContext.current?.flushGraphics()
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outputPath))
