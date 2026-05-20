import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make-icon.swift <output.icns>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("LimitLens-\(UUID().uuidString).iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer {
    try? fileManager.removeItem(at: iconsetURL)
}

let iconFiles: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for file in iconFiles {
    let data = iconPNG(size: file.size)
    try data.write(to: iconsetURL.appendingPathComponent(file.name))
}

try? fileManager.removeItem(at: outputURL)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", outputURL.path, iconsetURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}

private func iconPNG(size: Int) -> Data {
    let length = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: length, height: length)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fputs("failed to create bitmap context\n", stderr)
        exit(1)
    }

    context.clear(rect)

    let radius = length * 0.22
    let backgroundRect = rect.insetBy(dx: length * 0.055, dy: length * 0.055)
    let background = CGPath(
        roundedRect: backgroundRect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )

    drawGradient(
        in: background,
        context: context,
        colorSpace: colorSpace,
        colors: [
            CGColor(red: 0.09, green: 0.62, blue: 0.78, alpha: 1),
            CGColor(red: 0.12, green: 0.17, blue: 0.28, alpha: 1)
        ],
        start: CGPoint(x: backgroundRect.minX, y: backgroundRect.maxY),
        end: CGPoint(x: backgroundRect.maxX, y: backgroundRect.minY)
    )

    context.addPath(background)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
    context.setLineWidth(max(1, length * 0.018))
    context.strokePath()

    let lensRect = rect.insetBy(dx: length * 0.24, dy: length * 0.24)
    let lens = CGPath(ellipseIn: lensRect, transform: nil)
    drawGradient(
        in: lens,
        context: context,
        colorSpace: colorSpace,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.92),
            CGColor(red: 0.61, green: 0.96, blue: 0.82, alpha: 0.88)
        ],
        start: CGPoint(x: lensRect.minX, y: lensRect.minY),
        end: CGPoint(x: lensRect.maxX, y: lensRect.maxY)
    )

    context.addPath(lens)
    context.setStrokeColor(CGColor(red: 0.03, green: 0.20, blue: 0.28, alpha: 0.9))
    context.setLineWidth(max(1.5, length * 0.04))
    context.strokePath()

    let gaugeRect = lensRect.insetBy(dx: length * 0.12, dy: length * 0.12)
    context.addArc(
        center: CGPoint(x: lensRect.midX, y: lensRect.midY),
        radius: gaugeRect.width / 2,
        startAngle: radians(210),
        endAngle: radians(24),
        clockwise: false
    )
    context.setStrokeColor(CGColor(red: 0.02, green: 0.45, blue: 0.33, alpha: 0.95))
    context.setLineWidth(max(2, length * 0.05))
    context.setLineCap(.round)
    context.strokePath()

    let highlight = CGRect(
        x: length * 0.33,
        y: length * 0.58,
        width: length * 0.16,
        height: length * 0.10
    )
    context.addEllipse(in: highlight)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.46))
    context.fillPath()

    guard
        let image = context.makeImage(),
        let destinationData = NSMutableData() as CFMutableData?,
        let destination = CGImageDestinationCreateWithData(destinationData, UTType.png.identifier as CFString, 1, nil)
    else {
        fputs("failed to render icon png\n", stderr)
        exit(1)
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fputs("failed to finalize icon png\n", stderr)
        exit(1)
    }

    return destinationData as Data
}

private func drawGradient(
    in path: CGPath,
    context: CGContext,
    colorSpace: CGColorSpace,
    colors: [CGColor],
    start: CGPoint,
    end: CGPoint
) {
    guard let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors as CFArray,
        locations: [0, 1]
    ) else {
        return
    }

    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

private func radians(_ degrees: CGFloat) -> CGFloat {
    degrees * .pi / 180
}
