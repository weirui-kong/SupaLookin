//
//  LKAboutViewController.swift
//  SupaLookin
//
//  Created by 李凯 on 2019/10/30.
//  Copyright © 2019 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

private let photos: [(name: String, alpha: CGFloat)] = [
    ("photo0", 0.85),
    ("photo1", 0.85),
    ("photo2", 0.7),
    ("photo3", 0.8),
]

final class LKAboutViewController: LKBaseViewController {

    private var logoImageView: NSImageView!
    private var titleLabel: LKLabel!
    private var versionLabel: LKLabel!
    private var photoImageView: NSImageView!
    private var photoMaskView: LKBaseView!

    private let photoName: String
    private let maskFinalAlpha: CGFloat

    override init(containerView view: NSView?) {
        let photo = photos.randomElement()!
        photoName = photo.name
        maskFinalAlpha = photo.alpha

        super.init(containerView: view)
    }

    override func makeContainerView() -> NSView {
        let containerView = LKBaseView()

        photoImageView = NSImageView()
        photoImageView.image = NSImage(named: photoName)
        photoImageView.imageScaling = .scaleAxesIndependently
        containerView.addSubview(photoImageView)

        photoMaskView = LKBaseView()
        photoMaskView.backgroundColors = LKTwoColors(lightMode: .white, darkMode: .black)
        photoMaskView.alphaValue = 1
        containerView.addSubview(photoMaskView)

        logoImageView = NSImageView()
        logoImageView.image = NSImage(named: "logo_jump")
        logoImageView.animates = true
        containerView.addSubview(logoImageView)

        titleLabel = LKLabel()
        titleLabel.stringValue = "Lookin"
        titleLabel.textColors = LKTwoColors(lightMode: .black, darkMode: .white)
        titleLabel.font = .boldSystemFont(ofSize: 15)
        containerView.addSubview(titleLabel)

        let infoDictionary = Bundle.main.infoDictionary
        let dotVersion = infoDictionary?["CFBundleShortVersionString"] as? String ?? "(null)"
        let numberVersion = infoDictionary?["CFBundleVersion"] as? String ?? "(null)"
        versionLabel = LKLabel()
        versionLabel.stringValue = "Version \(dotVersion) (\(numberVersion))"
        versionLabel.textColors = LKTwoColors(lightMode: .black, darkMode: .white)
        versionLabel.font = .systemFont(ofSize: 13)
        containerView.addSubview(versionLabel)

        return containerView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        photoImageView.fillSuperview()
        photoMaskView.fillSuperview()
        logoImageView.setWidth(100).setHeight(88).centerHorizontally()
        titleLabel.fitSize().centerHorizontally().setY(logoImageView.frame.maxY - 6)
        versionLabel.fitSize().centerHorizontally().setY(titleLabel.frame.maxY + 3)
        let group: [NSView] = [logoImageView, titleLabel, versionLabel]
        group.centerGroupVertically()
        group.offset(y: -10)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 8
                self.photoMaskView.animator().alphaValue = self.maskFinalAlpha
            }, completionHandler: nil)
        }
    }
}
