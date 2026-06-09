#!/usr/bin/swift
//
//  Johnny Castaway for macOS — app icon generator
//
//  Draws an original cartoon desert island (no Sierra/Dynamix artwork —
//  game assets must never ship with the repo) and emits an .icns.
//  GPL-3.0-or-later; see LICENSE.
//
//  usage: swift Scripts/make-icon.swift <output.icns> [--preview <png>]
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha)
}

func verticalGradient(_ ctx: CGContext, in rect: CGRect, top: CGColor, bottom: CGColor) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end: CGPoint(x: rect.midX, y: rect.minY),
        options: [])
    ctx.restoreGState()
}

func fillCircle(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(
        x: center.x - radius, y: center.y - radius,
        width: radius * 2, height: radius * 2))
}

func fillCapsule(_ ctx: CGContext, _ rect: CGRect, color: CGColor) {
    let r = min(rect.width, rect.height) / 2
    ctx.setFillColor(color)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.fillPath()
}

/// One palm leaf: a lens shape from the crown to a drooping tip.
func frond(_ ctx: CGContext, from p: CGPoint, angle degrees: CGFloat,
           length: CGFloat, color: CGColor) {
    let a = degrees * .pi / 180
    var tip = CGPoint(x: p.x + cos(a) * length, y: p.y + sin(a) * length * 0.85)
    tip.y -= length * 0.18
    let mid = CGPoint(x: (p.x + tip.x) / 2, y: (p.y + tip.y) / 2)
    let dx = tip.x - p.x, dy = tip.y - p.y
    let len = max(sqrt(dx * dx + dy * dy), 1)
    let nx = -dy / len, ny = dx / len
    let bulge = length * 0.26
    ctx.setFillColor(color)
    ctx.move(to: p)
    ctx.addQuadCurve(
        to: tip, control: CGPoint(x: mid.x + nx * bulge, y: mid.y + ny * bulge))
    ctx.addQuadCurve(
        to: p, control: CGPoint(x: mid.x - nx * bulge * 0.3, y: mid.y - ny * bulge * 0.3))
    ctx.fillPath()
}

/// Draws the full icon into a 1024x1024 coordinate space.
func drawIcon(_ ctx: CGContext, pixels: Int) {
    let s = CGFloat(pixels) / 1024
    ctx.scaleBy(x: s, y: s)

    // Big Sur-style squircle plate; everything below is clipped to it.
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.addPath(CGPath(
        roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.clip()

    let horizon: CGFloat = 430

    // Sky and sea
    verticalGradient(
        ctx, in: CGRect(x: 100, y: horizon, width: 824, height: plate.maxY - horizon),
        top: rgb(0x6FC4EE), bottom: rgb(0xC4EAF8))
    verticalGradient(
        ctx, in: CGRect(x: 100, y: 100, width: 824, height: horizon - 100),
        top: rgb(0x3FA8CF), bottom: rgb(0x1D6FA3))

    // Sun with a soft glow
    fillCircle(ctx, center: CGPoint(x: 740, y: 730), radius: 130, color: rgb(0xFFE9A8, 0.35))
    fillCircle(ctx, center: CGPoint(x: 740, y: 730), radius: 80, color: rgb(0xFFD45E))

    // Cloud
    fillCapsule(ctx, CGRect(x: 210, y: 760, width: 180, height: 50), color: rgb(0xFFFFFF, 0.9))
    fillCircle(ctx, center: CGPoint(x: 270, y: 808), radius: 36, color: rgb(0xFFFFFF, 0.9))
    fillCircle(ctx, center: CGPoint(x: 325, y: 802), radius: 28, color: rgb(0xFFFFFF, 0.9))

    // Sailboat on the horizon — rescue is always almost in sight
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.move(to: CGPoint(x: 806, y: 448))
    ctx.addLine(to: CGPoint(x: 806, y: 516))
    ctx.addLine(to: CGPoint(x: 762, y: 448))
    ctx.closePath()
    ctx.fillPath()
    fillCapsule(ctx, CGRect(x: 752, y: 430, width: 76, height: 18), color: rgb(0x7A3B2E))

    // Waves
    fillCapsule(ctx, CGRect(x: 250, y: 330, width: 95, height: 9), color: rgb(0xFFFFFF, 0.35))
    fillCapsule(ctx, CGRect(x: 600, y: 285, width: 75, height: 9), color: rgb(0xFFFFFF, 0.35))
    fillCapsule(ctx, CGRect(x: 400, y: 215, width: 115, height: 9), color: rgb(0xFFFFFF, 0.35))

    // The island: shaded underside, then dry sand
    ctx.setFillColor(rgb(0xD9B97E))
    ctx.fillEllipse(in: CGRect(x: 262, y: 312, width: 500, height: 152))
    ctx.setFillColor(rgb(0xF2DEA7))
    ctx.fillEllipse(in: CGRect(x: 262, y: 326, width: 500, height: 152))

    // Palm trunk, bending left, wider at the base
    ctx.setFillColor(rgb(0x8C5A2E))
    ctx.move(to: CGPoint(x: 528, y: 415))
    ctx.addQuadCurve(to: CGPoint(x: 435, y: 762), control: CGPoint(x: 468, y: 580))
    ctx.addLine(to: CGPoint(x: 470, y: 778))
    ctx.addQuadCurve(to: CGPoint(x: 596, y: 418), control: CGPoint(x: 512, y: 590))
    ctx.closePath()
    ctx.fillPath()

    // Fronds
    let crown = CGPoint(x: 452, y: 768)
    for (i, angle) in [170, 135, 100, 65, 30, 4].enumerated() {
        frond(ctx, from: crown, angle: CGFloat(angle), length: 250,
              color: rgb(i.isMultiple(of: 2) ? 0x2E9E4F : 0x23874B))
    }

    // Coconuts
    fillCircle(ctx, center: CGPoint(x: 442, y: 752), radius: 21, color: rgb(0x6F4427))
    fillCircle(ctx, center: CGPoint(x: 480, y: 746), radius: 21, color: rgb(0x5E371F))
}

func renderPNG(pixels: Int, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
        bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw NSError(domain: "make-icon", code: 1) }
    drawIcon(ctx, pixels: pixels)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "make-icon", code: 2) }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "make-icon", code: 3)
    }
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(
        "usage: make-icon.swift <output.icns> [--preview <png>]\n".data(using: .utf8)!)
    exit(2)
}
let icnsURL = URL(fileURLWithPath: args[1])

if let i = args.firstIndex(of: "--preview"), i + 1 < args.count {
    try renderPNG(pixels: 1024, to: URL(fileURLWithPath: args[i + 1]))
}

let tmp = FileManager.default.temporaryDirectory
    .appendingPathComponent("JohnnyIcon-\(ProcessInfo.processInfo.processIdentifier).iconset")
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tmp) }

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                        (256, 1), (256, 2), (512, 1), (512, 2)] {
    let suffix = scale == 2 ? "@2x" : ""
    try renderPNG(
        pixels: points * scale,
        to: tmp.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", tmp.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil failed\n".data(using: .utf8)!)
    exit(1)
}
print("wrote \(icnsURL.path)")
