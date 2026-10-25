//
//  LKDashboardAttributeOpenImageView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/10/7.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

final class LKDashboardAttributeOpenImageView: LKDashboardAttributeView {

    private let control = LKTextControl()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.borderWidth = 1
        layer?.cornerRadius = DashboardCardControlCornerRadius
        borderColors = LKTwoColors(lightMode: NSColor(lookinRed: 181, green: 181, blue: 181), darkMode: NSColor(lookinRed: 83, green: 83, blue: 83))

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
        size.height = LKNumberInputHorizontalHeight
        return size
    }

    private func handleClick() {
        guard let imageViewOid_num = attribute?.value as? NSNumber else {
            LKHelper.alertError(LookinError.inner, window: window)
            assertionFailure()
            return
        }

        let imageViewOid = imageViewOid_num.uintValue
        guard let dashController = dashboardViewController, dashController.isStaticMode else {
            LKHelper.alertErrorText(NSLocalizedString("The feature is not available in current mode.", comment: ""), NSLocalizedString("You must connect Lookin with target iOS app before using this feature.", comment: ""), window: window)
            return
        }
        guard let inspectingApp = LKAppsManager.sharedInstance.inspectingApp else {
            LKHelper.alertError(LookinError.noConnect, window: window)
            return
        }

        Task { [weak self] in
            do {
                let imageData = try await inspectingApp.fetchImage(withImageViewOid: imageViewOid) as? Data
                guard let self else { return }
                guard let imageData else {
                    LKHelper.alertErrorText(NSLocalizedString("Operation failed. The image property value of selected UIImageView is nil.", comment: ""), "", window: self.window)
                    return
                }

                let fileName = String(format: "%.0f", Date().timeIntervalSince1970)
                let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("Lookin_UIImageView_\(fileName).png")
                do {
                    try imageData.write(to: URL(fileURLWithPath: filePath))
                } catch {
                    assertionFailure()
                    LKHelper.alertError(error, window: self.window)
                    return
                }
                NSWorkspace.shared.openFile(filePath, withApplication: "preview")

                // 记录临时文件地址以在 Lookin 退出时清理
                LKHelper.sharedInstance.tempImageFiles.append(filePath)
            } catch {
                LKHelper.alertError(error, window: self?.window)
            }
        }
    }
}
