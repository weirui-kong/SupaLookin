//
//  SPLKDashboardAttributeOpenImageView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/10/7.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

final class SPLKDashboardAttributeOpenImageView: SPLKDashboardAttributeView {

    private let control = SPLKTextControl()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.borderWidth = 1
        layer?.cornerRadius = DashboardCardControlCornerRadius
        borderColors = SPLKTwoColors(lightMode: NSColor(splkRed: 181, green: 181, blue: 181), darkMode: NSColor(splkRed: 83, green: 83, blue: 83))

        control.adjustAlphaWhenClick = true
        control.label.stringValue = NSLocalizedString("Open Image with Preview…", comment: "")
        control.label.font = .systemFont(ofSize: 11)
        control.clickAction = { [unowned self] _ in
            self.handleClick()
        }
        addSubview(control)
    }

    override func layout() {
        super.layout()
        control.fillSuperview()
    }

    override func renderWithAttribute() {
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.height = SPLKNumberInputHorizontalHeight
        return size
    }

    private func handleClick() {
        guard let imageViewOid_num = attribute?.value as? NSNumber else {
            SPLKHelper.alertError(SPLKError.inner, window: window)
            assertionFailure()
            return
        }

        let imageViewOid = imageViewOid_num.uintValue
        guard let dashController = dashboardViewController, dashController.isStaticMode else {
            SPLKHelper.alertErrorText(NSLocalizedString("The feature is not available in current mode.", comment: ""), NSLocalizedString("You must connect Lookin with target iOS app before using this feature.", comment: ""), window: window)
            return
        }
        guard let inspectingApp = SPLKAppsManager.sharedInstance.inspectingApp else {
            SPLKHelper.alertError(SPLKError.noConnect, window: window)
            return
        }

        Task { [weak self] in
            do {
                let imageData = try await inspectingApp.fetchImage(withImageViewOid: imageViewOid) as? Data
                guard let self else { return }
                guard let imageData else {
                    SPLKHelper.alertErrorText(NSLocalizedString("Operation failed. The image property value of selected UIImageView is nil.", comment: ""), "", window: self.window)
                    return
                }

                let fileName = String(format: "%.0f", Date().timeIntervalSince1970)
                let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("SPLK_UIImageView_\(fileName).png")
                do {
                    try imageData.write(to: URL(fileURLWithPath: filePath))
                } catch {
                    assertionFailure()
                    SPLKHelper.alertError(error, window: self.window)
                    return
                }
                NSWorkspace.shared.openFile(filePath, withApplication: "preview")

                // 记录临时文件地址以在 Lookin 退出时清理
                SPLKHelper.sharedInstance.tempImageFiles.append(filePath)
            } catch {
                SPLKHelper.alertError(error, window: self?.window)
            }
        }
    }
}
