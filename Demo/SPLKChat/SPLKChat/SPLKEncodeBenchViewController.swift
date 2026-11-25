//
//  SPLKEncodeBenchViewController.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/25.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

final class SPLKEncodeBenchViewController: UIViewController, UITableViewDataSource {

    private struct Section {
        let sample: SPLKEncodeBenchSample
        var results: [SPLKEncodeBenchResult]
    }

    private static let maxLayers = 300

    // Lives behind the results so its views are in a window, which drawViewHierarchy needs.
    private let chats = UINavigationController(rootViewController: SPLKChatsViewController())
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [Section] = []
    private var deviceLines: [String] = []
    private var runTask: Task<Void, Never>?
    private var hasAutorun = false

    private lazy var runItem = UIBarButtonItem(title: "Run", style: .done, target: self, action: #selector(run))
    private lazy var shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Screenshot Encoding"
        view.backgroundColor = .systemGroupedBackground

        chats.topViewController?.title = "Chats"
        addChild(chats)
        chats.view.frame = view.bounds
        chats.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(chats.view)
        chats.didMove(toParent: self)

        tableView.dataSource = self
        tableView.accessibilityIdentifier = "encodeBench.results"
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)
        setContentScrollView(tableView, for: .top)

        runItem.accessibilityIdentifier = "encodeBench.run"
        shareItem.accessibilityIdentifier = "encodeBench.share"
        shareItem.isEnabled = false
        navigationItem.rightBarButtonItems = [runItem, shareItem]
        deviceLines = deviceSummary(thermalLabel: "Thermal state")
    }

    // Launching with `-SPLKChatEncodeBenchAutorun YES` starts a run without a tap, for devices driven from a Mac.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAutorun && UserDefaults.standard.bool(forKey: "SPLKChatEncodeBenchAutorun") {
            hasAutorun = true
            run()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent {
            runTask?.cancel()
        }
    }

    // MARK: - Running

    @objc private func run() {
        runItem.isEnabled = false
        shareItem.isEnabled = false
        removeSavedResults()
        sections = []
        deviceLines = deviceSummary(thermalLabel: "Thermal state at start")
        title = "Running…"
        tableView.reloadData()

        // Let the title show before the main thread is busy drawing.
        DispatchQueue.main.async { [self] in
            let samples = makeSamples()
            runTask = Task { await encode(samples) }
        }
    }

    // The UI stays still until every codec is done, so redraws don't take CPU from the encoders.
    private func encode(_ samples: [SPLKEncodeBenchSample]) async {
        let results = await SPLKEncodeBench.measure(samples)
        guard !Task.isCancelled else { return }
        sections = zip(samples, results).map { Section(sample: $0, results: $1) }
        deviceLines.append(thermalLine(label: "Thermal state at end"))
        tableView.reloadData()
        saveResults()
        title = "Screenshot Encoding"
        runItem.isEnabled = true
        shareItem.isEnabled = true
    }

    // MARK: - Samples

    private func makeSamples() -> [SPLKEncodeBenchSample] {
        let scale = traitCollection.displayScale
        let screen = view.window?.bounds.size ?? view.bounds.size
        var samples: [SPLKEncodeBenchSample] = []
        func add(_ title: String, _ images: [CGImage], isBatch: Bool = false) {
            let bitmaps = images.compactMap { SPLKEncodeBenchBitmap($0, scale: scale) }
            guard !bitmaps.isEmpty else { return }
            samples.append(.init(title: title, bitmaps: bitmaps, isBatch: isBatch))
        }
        if let image = drawBusyUI(size: screen, scale: scale) { add("Busy UI", [image]) }
        if let image = drawDarkPage(size: screen, scale: scale) { add("Dark page", [image]) }
        if let image = drawTranslucentCard(scale: scale) { add("Translucent card", [image]) }

        chats.view.layoutIfNeeded()
        if let image = groupScreenshot(of: chats.view.layer, scale: scale) { add("Chats screen", [image]) }
        var layers: [CALayer] = []
        collect(chats.view.layer, into: &layers)
        add("Chats, every layer", layers.compactMap { groupScreenshot(of: $0, scale: scale) }, isBatch: true)
        return samples
    }

    private func collect(_ layer: CALayer, into layers: inout [CALayer]) {
        guard layers.count < Self.maxLayers, !layer.isHidden else { return }
        if layer.frame.width >= 1 && layer.frame.height >= 1 {
            layers.append(layer)
        }
        for sublayer in layer.sublayers ?? [] {
            collect(sublayer, into: &layers)
        }
    }

    // Mirrors CALayer+SPLKServer's splk_groupScreenshotWithLowQuality:.
    private func groupScreenshot(of layer: CALayer, scale: CGFloat) -> CGImage? {
        let size = layer.frame.size
        guard size.width > 0, size.height > 0 else { return nil }
        let image = renderer(size: size, scale: scale).image { context in
            if let view = layer.delegate as? UIView, view.window != nil {
                view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            } else {
                layer.render(in: context.cgContext)
            }
        }
        return image.cgImage
    }

    private func renderer(size: CGSize, scale: CGFloat) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format)
    }

    private func drawBusyUI(size: CGSize, scale: CGFloat) -> CGImage? {
        let photo = makePhoto()
        return renderer(size: size, scale: scale).image { context in
            let cg = context.cgContext
            UIColor(white: 0.96, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let colors = [UIColor.systemIndigo.cgColor, UIColor.systemPink.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: 140), options: [])
            }
            ("Inbox" as NSString).draw(at: CGPoint(x: 20, y: 70), withAttributes: [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold), .foregroundColor: UIColor.white,
            ])

            let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor.label]
            let detail: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.secondaryLabel]
            let words = "Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua".split(separator: " ")
            var y: CGFloat = 156
            var row = 0
            while y < size.height - 110 {
                let card = UIBezierPath(roundedRect: CGRect(x: 12, y: y, width: size.width - 24, height: 92), cornerRadius: 14)
                UIColor.white.setFill()
                card.fill()
                UIColor(white: 0.86, alpha: 1).setStroke()
                card.lineWidth = 1 / scale
                card.stroke()

                let thumb = CGRect(x: 24, y: y + 12, width: 68, height: 68)
                if row % 3 == 0, let photo {
                    cg.saveGState()
                    UIBezierPath(roundedRect: thumb, cornerRadius: 10).addClip()
                    photo.draw(in: thumb.insetBy(dx: -CGFloat(row % 5) * 8, dy: -CGFloat(row % 4) * 8))
                    cg.restoreGState()
                } else {
                    UIColor(hue: CGFloat(row % 7) / 7, saturation: 0.55, brightness: 0.9, alpha: 1).setFill()
                    UIBezierPath(ovalIn: thumb).fill()
                    UIImage(systemName: "person.fill")?.withTintColor(.white).draw(in: thumb.insetBy(dx: 18, dy: 18))
                }

                let start = (row * 5) % words.count
                let title = words[start..<min(words.count, start + 4)].joined(separator: " ")
                (title as NSString).draw(at: CGPoint(x: 106, y: y + 14), withAttributes: body)
                (words.shuffled().prefix(7).joined(separator: " ") as NSString).draw(in: CGRect(x: 106, y: y + 40, width: size.width - 150, height: 20), withAttributes: detail)
                ("\(9 + row % 3):\(String(format: "%02d", row * 7 % 60))" as NSString).draw(at: CGPoint(x: 106, y: y + 62), withAttributes: detail)
                y += 102
                row += 1
            }
            drawTabBar(in: size)
        }.cgImage
    }

    private func drawDarkPage(size: CGSize, scale: CGFloat) -> CGImage? {
        renderer(size: size, scale: scale).image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            let white: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor.white]
            ("9:41" as NSString).draw(at: CGPoint(x: 52, y: 18), withAttributes: white)
            let title = "Dark page" as NSString
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34, weight: .bold), .foregroundColor: UIColor.white]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: (size.height - titleSize.height) / 2), withAttributes: titleAttributes)
            drawTabBar(in: size)
        }.cgImage
    }

    private func drawTabBar(in size: CGSize) {
        let bar = CGRect(x: size.width * 0.16, y: size.height - 94, width: size.width * 0.68, height: 64)
        UIColor(white: 0.25, alpha: 0.85).setFill()
        UIBezierPath(roundedRect: bar, cornerRadius: 32).fill()
        let symbols = ["sparkles", "message", "folder"]
        for (index, symbol) in symbols.enumerated() {
            let x = bar.minX + bar.width * (CGFloat(index) + 0.5) / CGFloat(symbols.count)
            UIImage(systemName: symbol)?.withTintColor(index == 0 ? .systemBlue : .white).draw(in: CGRect(x: x - 13, y: bar.minY + 10, width: 26, height: 24))
            ((["Home", "Chat", "Files"][index]) as NSString).draw(at: CGPoint(x: x - 16, y: bar.minY + 38), withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: UIColor.white,
            ])
        }
    }

    private func drawTranslucentCard(scale: CGFloat) -> CGImage? {
        let size = CGSize(width: 360, height: 220)
        return renderer(size: size, scale: scale).image { context in
            let cg = context.cgContext
            cg.setShadow(offset: CGSize(width: 0, height: 6), blur: 20, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            UIColor.systemTeal.withAlphaComponent(0.85).setFill()
            UIBezierPath(roundedRect: CGRect(x: 24, y: 24, width: 312, height: 172), cornerRadius: 24).fill()
            cg.setShadow(offset: .zero, blur: 0)
            ("Get Started" as NSString).draw(at: CGPoint(x: 100, y: 92), withAttributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold), .foregroundColor: UIColor.white,
            ])
        }.cgImage
    }

    // Blurred noise stands in for a photo: it compresses as badly as one.
    private func makePhoto() -> UIImage? {
        let noise = CIFilter.randomGenerator().outputImage?.cropped(to: CGRect(x: 0, y: 0, width: 240, height: 240))
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = noise
        blur.radius = 3
        let color = CIFilter.colorControls()
        color.inputImage = blur.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: 240, height: 240))
        color.saturation = 1.6
        guard let output = color.outputImage, let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }

    // MARK: - Device

    private func deviceSummary(thermalLabel: String) -> [String] {
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        // A simulator's machine is the Mac's architecture.
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"].map { "\($0) Simulator" } ?? machine
        #if DEBUG
        let configuration = "Debug"
        #else
        let configuration = "Release"
        #endif
        return [
            "Device: \(model)",
            "System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            "Build: \(configuration)",
            thermalLine(label: thermalLabel),
        ]
    }

    private func thermalLine(label: String) -> String {
        let state = switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
        return "\(label): \(state)"
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count + 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? deviceLines.count : sections[section - 1].results.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? nil : header(for: sections[section - 1].sample)
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        return "Encoding only. Median of up to 7 runs after a warm-up (3 for every layer). "
            + "Transfer assumes 35 MB/s, a rough figure for USB 2."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        var content = UIListContentConfiguration.subtitleCell()
        if indexPath.section == 0 {
            content.text = deviceLines[indexPath.row]
        } else {
            let result = sections[indexPath.section - 1].results[indexPath.row]
            content.text = result.codec + (result.isLossless ? "" : " (lossy)")
            content.secondaryText = detail(for: result)
            content.secondaryTextProperties.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            content.secondaryTextProperties.color = .secondaryLabel
        }
        cell.contentConfiguration = content
        return cell
    }

    private func header(for sample: SPLKEncodeBenchSample) -> String {
        let raw = String(format: "%.1f MB raw", Double(sample.rawBytes) / 1_048_576)
        if sample.isBatch {
            return "\(sample.title) · \(sample.bitmaps.count) images · \(raw)"
        }
        let bitmap = sample.bitmaps[0]
        return "\(sample.title) · \(bitmap.width)×\(bitmap.height) px · \(raw)"
    }

    private func detail(for result: SPLKEncodeBenchResult) -> String {
        guard !result.failed else { return "failed" }
        let size = kilobytes(result.bytes)
        let encode = milliseconds(result.milliseconds)
        if let concurrent = result.concurrentMilliseconds {
            return "\(size) · \(encode) · \(milliseconds(concurrent)) on all cores"
        }
        return "\(size) · \(encode) · +\(milliseconds(transferMilliseconds(result.bytes))) to send"
    }

    private func kilobytes(_ bytes: Int) -> String {
        String(format: "%.1f KB", Double(bytes) / 1024)
    }

    private func milliseconds(_ value: Double) -> String {
        String(format: "%.1f ms", value)
    }

    private func transferMilliseconds(_ bytes: Int) -> Double {
        Double(bytes) / SPLKEncodeBench.transferBytesPerSecond * 1000
    }

    // MARK: - Sharing

    @objc private func share() {
        let controller = UIActivityViewController(activityItems: [markdown()], applicationActivities: nil)
        controller.popoverPresentationController?.barButtonItem = shareItem
        present(controller, animated: true)
    }

    // Kept in Documents so `devicectl device copy from` can fetch it.
    private var resultsURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("encode-bench.md")
    }

    private func saveResults() {
        guard let resultsURL else { return }
        try? markdown().write(to: resultsURL, atomically: true, encoding: .utf8)
    }

    // A fetch during a run then finds nothing, rather than the last run's results.
    private func removeSavedResults() {
        guard let resultsURL else { return }
        try? FileManager.default.removeItem(at: resultsURL)
    }

    private func markdown() -> String {
        var lines = ["# Screenshot encoding bench", ""]
        lines += deviceLines.map { "- \($0)" }
        for section in sections {
            lines += ["", "## \(header(for: section.sample))", ""]
            if section.sample.isBatch {
                lines += ["| Codec | Lossless | Size KB | Encode ms | All cores ms |", "|---|---|---|---|---|"]
            } else {
                lines += ["| Codec | Lossless | Size KB | Encode ms | +Send ms @35 MB/s |", "|---|---|---|---|---|"]
            }
            for result in section.results {
                let lossless = result.isLossless ? "yes" : "no"
                guard !result.failed else {
                    lines.append("| \(result.codec) | \(lossless) | failed | | |")
                    continue
                }
                let last = result.concurrentMilliseconds ?? transferMilliseconds(result.bytes)
                lines.append(String(format: "| %@ | %@ | %.1f | %.1f | %.1f |", result.codec, lossless, Double(result.bytes) / 1024, result.milliseconds, last))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
