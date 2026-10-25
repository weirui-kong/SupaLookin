//
//  LKExportManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKExportManager {

    static let sharedInstance = LKExportManager()

    private init() {}

    func data(from info: LookinHierarchyInfo?, imageCompression compression: CGFloat) -> (data: Data?, fileName: String?) {
        let file = LookinHierarchyFile()
        file.serverVersion = info?.serverVersion ?? 0
        file.hierarchyInfo = info

        var soloScreenshots: [NSNumber: Data] = [:]
        var groupScreenshots: [NSNumber: Data] = [:]

        let allItems = LookinDisplayItem.flatItems(fromHierarchicalItems: info?.displayItems ?? []) ?? []
        for displayItem in allItems {
            displayItem.screenshotEncodeType = .none
            let key = NSNumber(value: displayItem.layerObject?.oid ?? 0)
            soloScreenshots[key] = compressedData(from: displayItem.soloScreenshot, compression: compression)
            groupScreenshots[key] = compressedData(from: displayItem.groupScreenshot, compression: compression)
        }
        file.soloScreenshots = soloScreenshots
        file.groupScreenshots = groupScreenshots

        let document = LookinDocument()
        document.hierarchyFile = file
        var exportedData: Data?
        do {
            exportedData = try document.data(ofType: "com.lookin.lookin")
        } catch {
            assertionFailure()
        }

        let timeString: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMddHHmm"
            return formatter.string(from: Date())
        }()
        let iOSVersion: String = {
            var str = info?.appInfo?.osDescription ?? "(null)"
            if let dotIdx = str.firstIndex(of: ".") {
                str = String(str[..<dotIdx])
            }
            return str
        }()
        let fileName = "\(info?.appInfo?.appName ?? "(null)")_ios\(iOSVersion)_\(timeString).lookin"

        return (exportedData, fileName)
    }

    private func compressedData(from sourceImage: NSImage?, compression: CGFloat) -> Data? {
        guard let sourceImage else {
            return nil
        }

        let compression = max(min(compression, 1), 0.01)

        let targetSize = NSSize(width: sourceImage.size.width * compression, height: sourceImage.size.height * compression)
        let targetFrame = NSRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        let sourceImageRep = sourceImage.bestRepresentation(for: targetFrame, context: nil, hints: nil)

        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        sourceImageRep?.draw(in: targetFrame)
        resizedImage.unlockFocus()

        guard let tiff = resizedImage.tiffRepresentation, let imageRep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return imageRep.tiffRepresentation(using: .lzw, factor: 1)
    }

    static func exportScreenshot(with displayItem: LookinDisplayItem?) {
        let keyWindow = NSApplication.shared.keyWindow
        guard let image = displayItem?.groupScreenshot else {
            LKHelper.alertError(LookinError.inner, window: keyWindow)
            return
        }

        guard let imageData = image.tiffRepresentation(using: .lzw, factor: 1) else {
            LKHelper.alertError(LookinError.inner, window: keyWindow)
            return
        }

        let fileName = displayItem?.title ?? "LookinImage"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [.tiff]
        panel.isExtensionHidden = true
        panel.canCreateDirectories = true
        guard let keyWindow else { return }
        panel.beginSheetModal(for: keyWindow) { result in
            if result == .OK, let url = panel.url {
                do {
                    try imageData.write(to: url)
                } catch {
                    LKHelper.alertError(error, window: NSApplication.shared.keyWindow)
                    assertionFailure()
                }
            }
        }
    }

    static func nativeScale(for displayItem: LookinDisplayItem) -> Int {
        let pointWidth = displayItem.frame.size.width
        guard let image = displayItem.groupScreenshot, pointWidth > 0 else {
            return 0
        }
        let scale = image.size.width / pointWidth
        return max(Int(scale.rounded()), 1)
    }

    static func pixelSize(for displayItem: LookinDisplayItem, scale: Int) -> NSSize {
        NSSize(width: displayItem.frame.size.width * CGFloat(scale), height: displayItem.frame.size.height * CGFloat(scale))
    }

    static func copyScreenshotAsPNG(with displayItem: LookinDisplayItem, scale: Int) {
        let keyWindow = NSApplication.shared.keyWindow
        guard let sourceImage = displayItem.groupScreenshot else {
            LKHelper.alertError(LookinError.inner, window: keyWindow)
            return
        }
        let targetSize = pixelSize(for: displayItem, scale: scale)
        if targetSize.width <= 0 || targetSize.height <= 0 {
            LKHelper.alertError(LookinError.inner, window: keyWindow)
            return
        }
        var imageToCopy = sourceImage
        if targetSize != sourceImage.size {
            let targetFrame = NSRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
            let sourceImageRep = sourceImage.bestRepresentation(for: targetFrame, context: nil, hints: nil)
            let resizedImage = NSImage(size: targetSize)
            resizedImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            sourceImageRep?.draw(in: targetFrame)
            resizedImage.unlockFocus()
            imageToCopy = resizedImage
        }
        guard let tiff = imageToCopy.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiff),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            LKHelper.alertError(LookinError.inner, window: keyWindow)
            return
        }
        let paste = NSPasteboard.general
        paste.clearContents()
        paste.setData(pngData, forType: .png)
    }
}
