#!/usr/bin/env swift
import AppKit
import Foundation

/// Renders PNG layers for `MacApp/MisterRogersRenamer/AppIcon.icon/Assets/`.
/// Square 1024×1024 layers; primary shapes sit inside ~84% center so the macOS squircle mask
/// (Tahoe Liquid Glass) keeps them legible. Layer edges use transparency; `icon.json` `fill`
/// supplies the opaque square backdrop the system expects.

let size: CGFloat = 1024
let margin = size * 0.08
let inner = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
let corner = inner.width * 0.22

func drawPNG(path: String, draw: () -> Void) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    defer {
        NSGraphicsContext.current = nil
        NSGraphicsContext.restoreGraphicsState()
    }
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "context"])
    }
    NSGraphicsContext.current = ctx
    draw()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "png"])
    }
    try data.write(to: URL(fileURLWithPath: path))
}

let outArg = CommandLine.arguments.dropFirst().first
let assetsDir: String = {
    if let o = outArg, !o.isEmpty { return o }
    let cwd = FileManager.default.currentDirectoryPath
    return (cwd as NSString).appendingPathComponent("MacApp/MisterRogersRenamer/AppIcon.icon/Assets")
}()

try FileManager.default.createDirectory(atPath: assetsDir, withIntermediateDirectories: true)

// plate.png — warm field (glass-friendly)
try drawPNG(path: (assetsDir as NSString).appendingPathComponent("plate.png")) {
    let path = NSBezierPath(roundedRect: inner, xRadius: corner, yRadius: corner)
    let warm = NSColor(calibratedRed: 0.78, green: 0.22, blue: 0.20, alpha: 1)
    let warmHi = NSColor(calibratedRed: 0.88, green: 0.32, blue: 0.28, alpha: 1)
    let g = NSGradient(colors: [warm, warmHi], atLocations: [0, 1], colorSpace: NSColorSpace.deviceRGB)!
    g.draw(in: path, angle: 88)
}

// mark.png — document + gentle accent (caring organization)
try drawPNG(path: (assetsDir as NSString).appendingPathComponent("mark.png")) {
    let docW = inner.width * 0.42
    let docH = inner.height * 0.50
    let docX = (size - docW) / 2
    let docY = (size - docH) / 2 - size * 0.04
    let docRect = CGRect(x: docX, y: docY, width: docW, height: docH)
    let dr = docW * 0.08

    let docPath = NSBezierPath(roundedRect: docRect, xRadius: dr, yRadius: dr)
    NSColor(calibratedRed: 0.38, green: 0.62, blue: 0.82, alpha: 1).setFill()
    docPath.fill()

    NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 0.95).setStroke()
    let line = NSBezierPath()
    line.lineWidth = size * 0.018
    line.lineCapStyle = .round
    let lx = docRect.minX + docW * 0.14
    let rx = docRect.maxX - docW * 0.14
    let y1 = docRect.minY + docH * 0.28
    let y2 = docRect.minY + docH * 0.44
    let y3 = docRect.minY + docH * 0.60
    line.move(to: NSPoint(x: lx, y: y1))
    line.line(to: NSPoint(x: rx, y: y1))
    line.move(to: NSPoint(x: lx, y: y2))
    line.line(to: NSPoint(x: rx * 0.78, y: y2))
    line.move(to: NSPoint(x: lx, y: y3))
    line.line(to: NSPoint(x: rx * 0.65, y: y3))
    line.stroke()

    NSColor(calibratedRed: 0.92, green: 0.75, blue: 0.35, alpha: 1).setFill()
    let badge = CGRect(x: size / 2 - size * 0.08, y: docRect.maxY + size * 0.04, width: size * 0.16, height: size * 0.05)
    NSBezierPath(roundedRect: badge, xRadius: badge.height / 2, yRadius: badge.height / 2).fill()
}

print("Wrote plate.png and mark.png → \(assetsDir)")
