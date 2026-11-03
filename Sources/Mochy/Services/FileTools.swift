import AppKit
import ImageIO
import Quartz
import UniformTypeIdentifiers

enum FileTools {
    enum Format {
        case jpeg, heic, tiff, pdf
        var ext: String {
            switch self {
            case .jpeg: "jpg"
            case .heic: "heic"
            case .tiff: "tiff"
            case .pdf: "pdf"
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
        guard let image = NSImage(contentsOf: url) else { throw Failure.unreadable }
        let dest = sibling(of: url, suffix: format.ext)
        switch format {
        case .pdf:
            try writePDF(image, to: dest)
        case .jpeg:
            try writeBitmap(image, to: dest, type: .jpeg, properties: [.compressionFactor: quality])
        case .tiff:
            try writeBitmap(image, to: dest, type: .tiff, properties: [:])
        case .heic:
            try writeHEIC(image, to: dest, quality: quality)
        }
        return dest
    }

    static func resize(_ url: URL, longest: CGFloat) throws -> URL {
        guard let image = NSImage(contentsOf: url) else { throw Failure.unreadable }
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > 0 else { throw Failure.unreadable }
        let scale = min(1, longest / maxSide)
        let target = NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let resized = NSImage(size: target)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: target), from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        resized.unlockFocus()
        let dest = sibling(of: url, suffix: "\(Int(longest)).jpg")
        try writeBitmap(resized, to: dest, type: .jpeg, properties: [.compressionFactor: 0.85])
        return dest
    }

    static func zip(_ urls: [URL]) throws -> URL {
        guard let first = urls.first else { throw Failure.write }
        let dest = sibling(of: first, suffix: "zip")
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

    private static func sibling(of url: URL, suffix: String) -> URL {
        let stem = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent().appendingPathComponent("\(stem).\(suffix)")
    }

    private static func writeBitmap(_ image: NSImage, to url: URL, type: NSBitmapImageRep.FileType, properties: [NSBitmapImageRep.PropertyKey: Any]) throws {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: type, properties: properties) else {
            throw Failure.write
        }
        try data.write(to: url)
    }

    private static func writeHEIC(_ image: NSImage, to url: URL, quality: Double) throws {
        guard let tiff = image.tiffRepresentation, let source = CGImageSourceCreateWithData(tiff as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw Failure.unreadable }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil) else { throw Failure.write }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, cg, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Failure.write }
    }

    private static func writePDF(_ image: NSImage, to url: URL) throws {
        let size = image.size
        var media = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &media, nil)
        else { throw Failure.write }
        context.beginPDFPage(nil)
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cg, in: media)
        }
        context.endPDFPage()
        context.closePDF()
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
