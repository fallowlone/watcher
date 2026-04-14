#!/usr/bin/env swift
/// Generates AppIcon.icns for FileSandboxMenuBar.
/// Run from macos-menubar/: swift create-icon.swift
import AppKit
import Foundation

func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    defer { img.unlockFocus() }
    guard let ctx = NSGraphicsContext.current?.cgContext else { return img }

    // ── Background ────────────────────────────────────────────────────────────
    let radius = s * 0.22
    let bgPath = NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
        xRadius: radius, yRadius: radius
    )
    let cs = CGColorSpaceCreateDeviceRGB()
    ctx.saveGState()
    bgPath.setClip()
    let bgColors = [
        CGColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 1.0),
        CGColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0),
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: 0, y: s),
            end: CGPoint(x: s, y: 0),
            options: []
        )
    }
    ctx.restoreGState()

    // ── Shield ────────────────────────────────────────────────────────────────
    let pw = s * 0.56, ph = s * 0.60
    let px = (s - pw) / 2, py = s * 0.18
    let mx = px + pw / 2

    let shield = NSBezierPath()
    shield.move(to: NSPoint(x: mx, y: py + ph))
    shield.curve(
        to: NSPoint(x: px, y: py + ph * 0.52),
        controlPoint1: NSPoint(x: px + pw * 0.10, y: py + ph * 0.97),
        controlPoint2: NSPoint(x: px, y: py + ph * 0.76)
    )
    shield.curve(
        to: NSPoint(x: mx, y: py),
        controlPoint1: NSPoint(x: px, y: py + ph * 0.18),
        controlPoint2: NSPoint(x: mx - pw * 0.28, y: py)
    )
    shield.curve(
        to: NSPoint(x: px + pw, y: py + ph * 0.52),
        controlPoint1: NSPoint(x: mx + pw * 0.28, y: py),
        controlPoint2: NSPoint(x: px + pw, y: py + ph * 0.18)
    )
    shield.curve(
        to: NSPoint(x: mx, y: py + ph),
        controlPoint1: NSPoint(x: px + pw, y: py + ph * 0.76),
        controlPoint2: NSPoint(x: mx + pw * 0.10, y: py + ph * 0.97)
    )
    shield.close()

    // Shield drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.025), blur: s * 0.06,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
    NSColor.clear.setFill()
    shield.fill()
    ctx.restoreGState()

    // Shield gradient fill
    ctx.saveGState()
    shield.setClip()
    let shieldColors = [
        CGColor(red: 0.06, green: 0.90, blue: 0.70, alpha: 1.0),
        CGColor(red: 0.02, green: 0.60, blue: 0.95, alpha: 1.0),
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: shieldColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: px, y: py + ph),
            end: CGPoint(x: px + pw, y: py),
            options: []
        )
    }
    ctx.restoreGState()

    // Inner shield highlight (glass effect)
    ctx.saveGState()
    shield.setClip()
    let hlColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    if let hlGrad = CGGradient(colorsSpace: cs, colors: hlColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            hlGrad,
            start: CGPoint(x: mx, y: py + ph),
            end: CGPoint(x: mx, y: py + ph * 0.5),
            options: []
        )
    }
    ctx.restoreGState()

    // ── Checkmark ─────────────────────────────────────────────────────────────
    let ck = NSBezierPath()
    ck.lineWidth = s * 0.065
    ck.lineCapStyle = .round
    ck.lineJoinStyle = .round
    let cx = s * 0.50, cy = s * 0.43
    ck.move(to:  NSPoint(x: cx - s * 0.130, y: cy + s * 0.010))
    ck.line(to:  NSPoint(x: cx - s * 0.018, y: cy - s * 0.105))
    ck.line(to:  NSPoint(x: cx + s * 0.158, y: cy + s * 0.138))
    NSColor.white.withAlphaComponent(0.95).setStroke()
    ck.stroke()

    return img
}

// ── Save PNG ──────────────────────────────────────────────────────────────────
func savePng(_ img: NSImage, to path: String) {
    guard
        let tiff = img.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let data = rep.representation(using: .png, properties: [:])
    else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

// ── Build iconset ─────────────────────────────────────────────────────────────
let iconset = "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let defs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, size) in defs {
    savePng(drawIcon(size: size), to: "\(iconset)/\(filename)")
    print("  \(filename)")
}

let result = shell("iconutil -c icns \(iconset) -o AppIcon.icns")
if result == 0 {
    try? FileManager.default.removeItem(atPath: iconset)
    print("✓ AppIcon.icns created")
} else {
    print("✗ iconutil failed — iconset left at \(iconset)")
}

@discardableResult
func shell(_ cmd: String) -> Int32 {
    let p = Process()
    p.launchPath = "/bin/sh"
    p.arguments = ["-c", cmd]
    p.launch(); p.waitUntilExit()
    return p.terminationStatus
}
