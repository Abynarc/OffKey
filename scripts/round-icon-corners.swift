#!/usr/bin/swift
import AppKit
import Foundation

/// macOS-style squircle mask (superellipse, close to system app icon shape).
func isInsideSquircle(x: Int, y: Int, width: Int, height: Int) -> Bool {
    let nx = (2.0 * Double(x) / Double(width - 1)) - 1.0
    let ny = (2.0 * Double(y) / Double(height - 1)) - 1.0
    return pow(abs(nx), 5.0) + pow(abs(ny), 5.0) <= 1.0
}

func applySquircleMask(to inputPath: String, outputPath: String) throws {
    guard let image = NSImage(contentsOfFile: inputPath) else {
        throw NSError(domain: "round-icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot open \(inputPath)"])
    }

    var proposedRect = NSRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
        throw NSError(domain: "round-icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot read CGImage"])
    }

    let width = cgImage.width
    let height = cgImage.height

    guard
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw NSError(domain: "round-icon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create context"])
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let data = context.data else {
        throw NSError(domain: "round-icon", code: 4, userInfo: [NSLocalizedDescriptionKey: "No pixel data"])
    }

    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

    for y in 0..<height {
        for x in 0..<width {
            let index = (y * width + x) * 4
            if !isInsideSquircle(x: x, y: y, width: width, height: height) {
                pixels[index + 3] = 0
                continue
            }

            // Remove leftover near-white fringe from square source art.
            let r = Double(pixels[index])
            let g = Double(pixels[index + 1])
            let b = Double(pixels[index + 2])
            let a = Double(pixels[index + 3])

            if a > 0, r > 235, g > 235, b > 235 {
                let whiteness = min(r, g, b) / 255.0
                let edgeDistance = min(
                    Double(x),
                    Double(y),
                    Double(width - 1 - x),
                    Double(height - 1 - y)
                )
                if edgeDistance < Double(width) * 0.12 && whiteness > 0.9 {
                    pixels[index + 3] = 0
                }
            }
        }
    }

    guard let output = context.makeImage() else {
        throw NSError(domain: "round-icon", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot make output image"])
    }

    let rep = NSBitmapImageRep(cgImage: output)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "round-icon", code: 6, userInfo: [NSLocalizedDescriptionKey: "Cannot encode PNG"])
    }

    try png.write(to: URL(fileURLWithPath: outputPath))
}

let iconSet = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let masterName = "icon_1024.png"
let masterURL = iconSet.appendingPathComponent(masterName)
let backupURL = iconSet.appendingPathComponent("icon_1024_original.png")

if !FileManager.default.fileExists(atPath: backupURL.path) {
    try FileManager.default.copyItem(at: masterURL, to: backupURL)
    print("Backup: \(backupURL.path)")
}

let roundedMaster = iconSet.appendingPathComponent("icon_1024_rounded.png")
try applySquircleMask(to: masterURL.path, outputPath: roundedMaster.path)
try FileManager.default.removeItem(at: masterURL)
try FileManager.default.moveItem(at: roundedMaster, to: masterURL)
print("Rounded master: \(masterURL.path)")

let sizes = [16, 32, 64, 128, 256, 512]
for size in sizes {
    let out = iconSet.appendingPathComponent("icon_\(size).png")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = ["-z", "\(size)", "\(size)", masterURL.path, "--out", out.path]
    try task.run()
    task.waitUntilExit()
    if task.terminationStatus != 0 {
        fputs("sips failed for size \(size)\n", stderr)
        exit(1)
    }
    print("Resized: \(out.lastPathComponent)")
}

print("Done.")
