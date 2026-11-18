//
//  SPLKToast.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/18.
//

import Cocoa

// A note at a window's bottom-left corner that goes away by itself, for news that needs no answer. A window shows
// one at a time; a new one replaces the old.
@MainActor
final class SPLKToast {

    enum Style {
        case info, success, warning, error

        var symbolName: String {
            switch self {
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.octagon.fill"
            }
        }

        var tint: NSColor {
            switch self {
            case .info: .controlAccentColor
            case .success: .systemGreen
            case .warning: .systemOrange
            case .error: .systemRed
            }
        }
    }

    static let defaultDuration: TimeInterval = 4

    private static let current = NSMapTable<NSWindow, SPLKToast>.weakToStrongObjects()

    private let view: SPLKToastView
    private var dismissTask: Task<Void, Never>?
    private var isDismissed = false

    // A nil duration keeps the toast until dismiss() or a click.
    @discardableResult
    static func show(_ message: String, detail: String? = nil, style: Style = .info, in window: NSWindow?, duration: TimeInterval? = defaultDuration) -> SPLKToast? {
        guard let window, let container = window.contentView else { return nil }
        current.object(forKey: window)?.dismiss()
        let toast = SPLKToast(view: SPLKToastView(message: message, detail: detail, style: style))
        current.setObject(toast, forKey: window)
        toast.present(in: container, duration: duration)
        NSAccessibility.post(element: window, notification: .announcementRequested, userInfo: [.announcement: [message, detail].compactMap { $0 }.joined(separator: " "), .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        return toast
    }

    private init(view: SPLKToastView) {
        self.view = view
        view.onClick = { [weak self] in self?.dismiss() }
    }

    private func present(in container: NSView, duration: TimeInterval?) {
        view.alphaValue = 0
        container.addSubview(view, positioned: .above, relativeTo: nil)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            view.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            view.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
        ])
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            view.animator().alphaValue = 1
        }
        if let duration {
            dismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        guard !isDismissed else { return }
        isDismissed = true
        dismissTask?.cancel()
        if let window = view.window, Self.current.object(forKey: window) === self {
            Self.current.removeObject(forKey: window)
        }
        let view = view
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            view.animator().alphaValue = 0
        } completionHandler: {
            view.removeFromSuperview()
        }
    }
}

private final class SPLKToastView: NSVisualEffectView {

    var onClick: (() -> Void)?

    init(message: String, detail: String?, style: SPLKToast.Style) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        material = .popover
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel([message, detail].compactMap { $0 }.joined(separator: " "))

        let icon = NSImageView(image: NSImage(systemSymbolName: style.symbolName, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 17, weight: .medium)
        icon.contentTintColor = style.tint
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = NSTextField(wrappingLabelWithString: message)
        title.font = .systemFont(ofSize: 14, weight: .medium)
        let lines = NSStackView(views: [title])
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = 3
        if let detail {
            let detailLabel = NSTextField(wrappingLabelWithString: detail)
            detailLabel.font = .systemFont(ofSize: 12)
            detailLabel.textColor = .secondaryLabelColor
            lines.addArrangedSubview(detailLabel)
        }

        let row = NSStackView(views: [icon, lines])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
