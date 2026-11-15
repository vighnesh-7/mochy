import AppKit
import ImageIO
import PDFKit
import Quartz
import UniformTypeIdentifiers

enum FileTools {
    enum Format {
        case jpeg, jpg, png, webp, heic, tiff, pdf
        var ext: String {
            switch self {
            case .jpeg: "jpeg"
            case .jpg: "jpg"
            case .png: "png"
            case .webp: "webp"
            case .heic: "heic"
            case .tiff: "tiff"
            case .pdf: "pdf"
            }
        }

        var type: UTType {
            switch self {
            case .jpeg, .jpg: .jpeg
            case .png: .png
            case .webp: .webP
            case .heic: .heic
            case .tiff: .tiff
            case .pdf: .pdf
            }
        }

        var flattensAlpha: Bool {
            switch self {
            case .jpeg, .jpg: true
            default: false
            }
        }
    }

    enum Failure: LocalizedError {
        case unreadable
        case write
        var errorDescription: String? {
            switch self {
            case .unreadable: "That file isn’t an image Mochy can convert."
            case .write: "Couldn’t write the converted file."
            }
        }
    }

    static func convert(_ url: URL, to format: Format, quality: Double = 0.82) throws -> URL {
        guard let image = load(url) else { throw Failure.unreadable }
        let dest = destination(for: url, ext: format.ext)
        switch format {
        case .pdf:
            try writePDF(image, to: dest)
        default:
            try writeRaster(image, to: dest, format: format, quality: quality)
        }
        try validate(dest, format: format)
        return dest
    }

    static func resize(_ url: URL, longest: CGFloat) throws -> URL {
        guard let image = load(url) else { throw Failure.unreadable }
        let maxSide = CGFloat(max(image.width, image.height))
        guard maxSide > 0 else { throw Failure.unreadable }
        let ratio = min(1, longest / maxSide)
        let width = max(1, Int((CGFloat(image.width) * ratio).rounded()))
        let height = max(1, Int((CGFloat(image.height) * ratio).rounded()))
        guard let scaled = draw(image, width: width, height: height, opaque: true) else { throw Failure.write }
        let dest = destination(for: url, ext: "\(Int(longest)).jpg")
        try writeRaster(scaled, to: dest, format: .jpg, quality: 0.85)
        try validate(dest, format: .jpg)
        return dest
    }

    static func zip(_ urls: [URL]) throws -> URL {
        guard let first = urls.first else { throw Failure.write }
        let dest = destination(for: first, ext: "zip")
        try? FileManager.default.removeItem(at: dest)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = ["-c", "-k", "--keepParent"] + urls.map(\.path) + [dest.path]
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0, FileManager.default.fileExists(atPath: dest.path) else { throw Failure.write }
        return dest
    }

    static func quickLook(_ url: URL) {
        QuickLook.shared.show(url)
    }

    // MARK: Decode

    private static func load(_ url: URL) -> CGImage? {
        let keys = [kCGImageSourceShouldCache: true] as CFDictionary
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           CGImageSourceGetCount(source) > 0,
           let image = CGImageSourceCreateImageAtIndex(source, 0, keys)
        {
            return image
        }
        guard let ns = NSImage(contentsOf: url), ns.size.width > 0, ns.size.height > 0 else { return nil }
        var rect = CGRect(origin: .zero, size: ns.size)
        return ns.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    // MARK: Encode

    private static func writeRaster(_ image: CGImage, to url: URL, format: Format, quality: Double) throws {
        let prepared = format.flattensAlpha ? (flatten(image) ?? image) : image
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, format.type.identifier as CFString, 1, nil) else {
            throw Failure.write
        }
        var options: [CFString: Any] = [:]
        if format != .png && format != .tiff {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(dest, prepared, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Failure.write }
    }

    private static func writePDF(_ image: CGImage, to url: URL) throws {
        let pageImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        guard let page = PDFPage(image: pageImage) else { throw Failure.write }
        let document = PDFDocument()
        document.insert(page, at: 0)
        guard document.write(to: url) else { throw Failure.write }
    }

    /// JPEG cannot store transparency. Draw the image onto white first so the file is a real JPEG.
    private static func flatten(_ image: CGImage) -> CGImage? {
        draw(image, width: image.width, height: image.height, opaque: true)
    }

    private static func draw(_ image: CGImage, width: Int, height: Int, opaque: Bool) -> CGImage? {
        let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: alpha.rawValue
        ) else { return nil }
        if opaque {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func destination(for url: URL, ext: String) -> URL {
        let folder = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        var candidate = folder.appendingPathComponent("\(stem).\(ext)")
        var count = 2
        while candidate.path == url.path || FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(stem)-\(count).\(ext)")
            count += 1
        }
        return candidate
    }

    private static func validate(_ url: URL, format: Format) throws {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count > 32, magicMatches(data, format: format) else {
            try? FileManager.default.removeItem(at: url)
            throw Failure.write
        }
    }

    private static func magicMatches(_ data: Data, format: Format) -> Bool {
        let bytes = [UInt8](data.prefix(16))
        switch format {
        case .jpeg, .jpg:
            return bytes.starts(with: [0xFF, 0xD8, 0xFF])
        case .png:
            return bytes.starts(with: [0x89, 0x50, 0x4E, 0x47])
        case .pdf:
            return bytes.starts(with: [0x25, 0x50, 0x44, 0x46])
        case .webp:
            return bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) && data.count >= 12 && data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50
        case .tiff:
            return bytes.starts(with: [0x49, 0x49, 0x2A, 0x00]) || bytes.starts(with: [0x4D, 0x4D, 0x00, 0x2A])
        case .heic:
            return data.count >= 12 && data[4] == 0x66 && data[5] == 0x74 && data[6] == 0x79 && data[7] == 0x70
        }
    }
}

private final class QuickLook: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLook()
    private var url: URL?

    func show(_ url: URL) {
        self.url = url
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in _: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }
    func previewPanel(_: QLPreviewPanel!, previewItemAt _: Int) -> QLPreviewItem! { url as NSURL? }
}
