#!/usr/bin/env swift
import AppKit

// Generates Murmur's monochrome waveform app icon into the asset catalog.
// Run: swift scripts/make-icon.swift

let iconset = "Murmur/Resources/Assets.xcassets/AppIcon.appiconset"

func render(_ pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Simple solid-black rounded-rect background.
    let inset = size * 0.06
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.235
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor.black.setFill()
    bg.fill()

    // Centered white waveform bars (matches the app's `waveform` symbol).
    let heights: [CGFloat] = [0.30, 0.52, 0.78, 1.0, 0.78, 0.52, 0.30]
    let barWidth = size * 0.058
    let spacing = size * 0.044
    let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * spacing
    var x = size / 2 - totalWidth / 2
    let maxBarHeight = size * 0.44
    NSColor.white.setFill()
    for h in heights {
        let barHeight = maxBarHeight * h
        let barRect = NSRect(x: x, y: size / 2 - barHeight / 2, width: barWidth, height: barHeight)
        NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        x += barWidth + spacing
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// macOS icon sizes: (point, scale) -> pixels
let specs: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let fm = FileManager.default
for spec in specs {
    let data = render(spec.px)
    try! data.write(to: URL(fileURLWithPath: "\(iconset)/\(spec.name).png"))
}

let images = specs.map { spec -> [String: String] in
    let comps = spec.name.replacingOccurrences(of: "icon_", with: "").components(separatedBy: "@")
    let sizePart = comps[0]
    let scale = comps.count > 1 ? comps[1] : "1x"
    return ["idiom": "mac", "size": sizePart, "scale": scale, "filename": "\(spec.name).png"]
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(iconset)/Contents.json"))

print("Wrote \(specs.count) icon images + Contents.json to \(iconset)")
