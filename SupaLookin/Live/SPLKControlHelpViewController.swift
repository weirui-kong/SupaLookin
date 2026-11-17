//
//  SPLKControlHelpViewController.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/18.
//

import Cocoa
import SPLKProtocol

// Live Control's help sheet: what each target allows, how to install the SupaLookin Helper on a jailbroken device,
// and a check of the connected one. See spec/20261118-protocol-v2-m12-jailbreak-input.md.
final class SPLKControlHelpViewController: NSViewController {

    static let packageName = "org.supacode.app.lookin.splkhid"
    static let packageDirectory = "/SupaLookin"
    static let installCommand = "sudo dpkg -i /var/mobile/Media/SupaLookin/org.supacode.app.lookin.splkhid.deb"
    static let removeCommand = "sudo dpkg -r org.supacode.app.lookin.splkhid"

    private weak var session: SPLKDeviceSession?
    private let copyStatus = NSTextField(wrappingLabelWithString: "")
    private let checkResult = NSTextField(wrappingLabelWithString: "")
    private let checkButton = NSButton(title: NSLocalizedString("Check This Device", comment: ""), target: nil, action: nil)
    private let copyPackageButton = NSButton(title: NSLocalizedString("Copy Package to Device", comment: ""), target: nil, action: nil)
    private let spinner = NSProgressIndicator()

    init(session: SPLKDeviceSession?) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        stack.addArrangedSubview(Self.label(NSLocalizedString("Operating Devices", comment: ""), font: .boldSystemFont(ofSize: 15)))
        stack.addArrangedSubview(supportTable())
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)

        stack.addArrangedSubview(Self.label(NSLocalizedString("Install the SupaLookin Helper", comment: ""), font: .boldSystemFont(ofSize: 13)))
        stack.addArrangedSubview(Self.wrapping(NSLocalizedString("For jailbroken devices below iOS 27 on a rootless jailbreak, such as Dopamine, connected over USB.", comment: "")))
        stack.addArrangedSubview(Self.wrapping(NSLocalizedString("1. Copy the helper package, built into Supa Lookin, to the device's media folder.", comment: "")))
        copyPackageButton.bezelStyle = .rounded
        copyPackageButton.target = self
        copyPackageButton.action = #selector(copyPackage)
        copyPackageButton.isEnabled = isUSBDevice
        copyStatus.textColor = .secondaryLabelColor
        copyStatus.font = .systemFont(ofSize: 11)
        stack.addArrangedSubview(row([copyPackageButton, copyStatus]))
        stack.addArrangedSubview(Self.wrapping(NSLocalizedString("2. Install it as root, in a terminal on the device or over SSH. Or open the file in Filza and install it there.", comment: "")))
        stack.addArrangedSubview(commandRow(Self.installCommand))
        stack.addArrangedSubview(Self.wrapping(NSLocalizedString("To remove it:", comment: "")))
        stack.addArrangedSubview(commandRow(Self.removeCommand))
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)

        stack.addArrangedSubview(Self.label(NSLocalizedString("This Device", comment: ""), font: .boldSystemFont(ofSize: 13)))
        stack.addArrangedSubview(Self.wrapping(deviceDescription))
        checkButton.bezelStyle = .rounded
        checkButton.target = self
        checkButton.action = #selector(check)
        checkButton.isEnabled = session != nil
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        stack.addArrangedSubview(row([checkButton, spinner]))
        checkResult.isSelectable = true
        stack.addArrangedSubview(checkResult)

        let done = NSButton(title: NSLocalizedString("Done", comment: ""), target: self, action: #selector(done))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        let footer = NSStackView(views: [NSView(), done])
        footer.orientation = .horizontal
        stack.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true

        stack.widthAnchor.constraint(equalToConstant: 580).isActive = true
        for case let field as NSTextField in stack.arrangedSubviews where field.cell?.wraps == true {
            field.preferredMaxLayoutWidth = 532
        }
        checkResult.preferredMaxLayoutWidth = 532
        view = stack
    }

    // MARK: - Content

    enum Support: Equatable {
        case full, partial, none

        var color: NSColor {
            switch self {
            case .full: return .systemGreen
            case .partial: return .systemOrange
            case .none: return .systemRed
            }
        }
    }

    struct SupportRow: Equatable {
        let target: String
        let watch: String
        let operate: String
        let support: Support
    }

    static var supportRows: [SupportRow] {
        let yes = NSLocalizedString("Yes", comment: "")
        return [
            SupportRow(target: NSLocalizedString("Simulator, Xcode 27 or later", comment: ""), watch: yes, operate: NSLocalizedString("Everything", comment: ""), support: .full),
            SupportRow(target: NSLocalizedString("Simulator, Xcode 26", comment: ""), watch: yes, operate: NSLocalizedString("The app only; everything is planned", comment: ""), support: .partial),
            SupportRow(target: NSLocalizedString("Device, iOS 27 or later", comment: ""), watch: yes, operate: NSLocalizedString("Coming soon", comment: ""), support: .none),
            SupportRow(target: NSLocalizedString("Device below iOS 27, jailbroken, with the SupaLookin Helper", comment: ""), watch: yes, operate: NSLocalizedString("Everything, while unlocked", comment: ""), support: .full),
            SupportRow(target: NSLocalizedString("Other devices", comment: ""), watch: yes, operate: NSLocalizedString("No", comment: ""), support: .none),
        ]
    }

    private func supportTable() -> NSView {
        let header = [NSLocalizedString("Target", comment: ""), NSLocalizedString("Watch", comment: ""), NSLocalizedString("Operate", comment: "")].map {
            Self.label($0, font: .boldSystemFont(ofSize: 12))
        }
        // A target's operation reads green where it's supported, orange where partly, red where not.
        let rows = Self.supportRows.map { row in
            let cells = [Self.label(row.target, font: .systemFont(ofSize: 12)), Self.label(row.watch, font: .systemFont(ofSize: 12)), Self.label(row.operate, font: .systemFont(ofSize: 12, weight: .medium))]
            cells[0].textColor = row.support.color
            cells[1].textColor = .systemGreen
            cells[2].textColor = row.support.color
            return cells
        }
        let grid = NSGridView(views: [header] + rows)
        grid.rowSpacing = 6
        grid.columnSpacing = 16
        // Fits the sheet's 532 pt of content: 250 + 50 + 200 plus the spacing.
        let widths: [CGFloat] = [250, 50, 200]
        for (index, width) in widths.enumerated() {
            grid.column(at: index).width = width
        }
        for row in 0..<grid.numberOfRows {
            grid.row(at: row).yPlacement = .top
        }
        for row in rows {
            for (index, field) in row.enumerated() {
                field.lineBreakMode = .byWordWrapping
                field.maximumNumberOfLines = 0
                field.preferredMaxLayoutWidth = widths[index]
            }
        }
        return grid
    }

    private var isUSBDevice: Bool {
        if case .usbDevice = session?.target { return true }
        return false
    }

    private var deviceDescription: String {
        guard let app = session?.client.serverHello.app else {
            return NSLocalizedString("No app is being inspected.", comment: "")
        }
        let kind = isUSBDevice ? NSLocalizedString("USB device", comment: "") : NSLocalizedString("Simulator", comment: "")
        return "\(app.deviceDescription) · \(app.osDescription) · \(kind)"
    }

    // What the check found, in the person's terms.
    static func checkResult(_ availability: SPLKDeviceSession.InputAvailability, isUSBDevice: Bool, error: Error?) -> String {
        switch availability {
        case .unknown:
            return NSLocalizedString("Not checked yet.", comment: "")
        case .host:
            return isUSBDevice
                ? NSLocalizedString("Full control, through the SupaLookin Helper.", comment: "")
                : NSLocalizedString("Full control, through the simulator.", comment: "")
        case .app:
            return NSLocalizedString("Only the app's own screens respond. Xcode 27 or later gives full control.", comment: "")
        case .watchOnly(.locked):
            return NSLocalizedString("The helper is installed. Unlock the device to operate it.", comment: "")
        case .watchOnly(.comingSoon):
            return NSLocalizedString("Operating devices on iOS 27 or later is coming soon.", comment: "")
        case .watchOnly(.needsJailbreak):
            if let refusal = error as? SPLKJailbreakHIDInput.Refusal, refusal != .unreachable {
                return String(format: NSLocalizedString("The SupaLookin Helper refused the connection: %@.", comment: ""), refusal.reason)
            }
            if let error, !(error is SPLKJailbreakHIDInput.Refusal) {
                return error.localizedDescription
            }
            return NSLocalizedString("The SupaLookin Helper wasn't found. Install it on a jailbroken device.", comment: "")
        }
    }

    // MARK: - Actions

    @objc private func copyPackage() {
        guard case .usbDevice(let serialNumber?) = session?.target,
              let url = Bundle.main.url(forResource: Self.packageName, withExtension: "deb"),
              let package = try? Data(contentsOf: url) else {
            copyStatus.stringValue = NSLocalizedString("The package isn't available for this device.", comment: "")
            return
        }
        copyPackageButton.isEnabled = false
        copyStatus.stringValue = NSLocalizedString("Copying…", comment: "")
        Task { [weak self] in
            do {
                try await SPLKMobileDeviceAFC.write(package, toDirectory: Self.packageDirectory, file: "\(Self.packageName).deb", udid: serialNumber)
                self?.copyStatus.stringValue = NSLocalizedString("Copied to /var/mobile/Media/SupaLookin.", comment: "")
            } catch {
                self?.copyStatus.stringValue = error.localizedDescription
            }
            self?.copyPackageButton.isEnabled = true
        }
    }

    @objc private func check() {
        guard let session else { return }
        checkButton.isEnabled = false
        spinner.startAnimation(nil)
        checkResult.stringValue = ""
        Task { [weak self, weak session] in
            guard let session else { return }
            let availability = await session.refreshInputAvailability()
            guard let self else { return }
            self.checkResult.stringValue = Self.checkResult(availability, isUSBDevice: self.isUSBDevice, error: session.hostInputError)
            self.spinner.stopAnimation(nil)
            self.checkButton.isEnabled = true
        }
    }

    @objc private func done() {
        dismiss(nil)
    }

    // MARK: - Views

    private func commandRow(_ command: String) -> NSView {
        let field = NSTextField(wrappingLabelWithString: command)
        field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        field.isSelectable = true
        field.preferredMaxLayoutWidth = 460
        let copy = NSButton(title: NSLocalizedString("Copy", comment: ""), target: nil, action: nil)
        copy.bezelStyle = .rounded
        copy.controlSize = .small
        copy.onAction { button in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            button.title = NSLocalizedString("Copied", comment: "")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                button.title = NSLocalizedString("Copy", comment: "")
            }
        }
        return row([copy, field])
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private static func label(_ text: String, font: NSFont) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        return label
    }

    private static func wrapping(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        return label
    }
}
