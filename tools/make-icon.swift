// Gera o ícone do Tipoteca (.iconset) — quadrado arredondado verde com o "T" preto.
// Uso: swiftc tools/make-icon.swift -o /tmp/make-icon && /tmp/make-icon Resources/AppIcon.iconset
import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func render(pixels: Int) -> Data? {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Moldura padrão do macOS: 80,5% da tela, cantos ~22%.
    let inset = size * 0.0975
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = size * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
    shadow.set()
    color(0x08EC99).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [color(0x08EC99), color(0xC7FE83)])?.draw(in: path, angle: -50)

    // Brilho sutil no topo
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])?
        .draw(in: path, angle: -90)

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: rect.height * 0.62, weight: .black),
        .foregroundColor: color(0x070807)
    ]
    let glyph = NSAttributedString(string: "T", attributes: attributes)
    let box = glyph.size()
    glyph.draw(at: NSPoint(x: rect.midX - box.width / 2, y: rect.midY - box.height / 2 - rect.height * 0.01))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

guard CommandLine.arguments.count > 1 else { print("uso: make-icon <pasta.iconset>"); exit(1) }
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for (name, pixels) in variants {
    guard let data = render(pixels: pixels) else { print("falhou \(name)"); exit(1) }
    try data.write(to: out.appendingPathComponent("\(name).png"))
}
print("ok")
