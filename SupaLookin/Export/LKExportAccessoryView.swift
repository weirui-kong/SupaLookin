//
//  LKExportAccessoryView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/13.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine

final class LKExportAccessoryView: LKBaseView {

    private let compressionLabel = LKLabel()
    private let compressionButton = NSPopUpButton()
    private let sizeLabel = LKLabel()
    private let compressionArray: [CGFloat] = [0.1, 0.3, 0.5, 0.75, 1]

    private let insetTop: CGFloat = 20
    private let insetBottom: CGFloat = 10
    private let buttonWidth: CGFloat = 150
    private let sizeLabelTop: CGFloat = 5

    private var cancellables = Set<AnyCancellable>()

    var dataSize = 0 {
        didSet {
            sizeLabel.stringValue = String(format: NSLocalizedString("File Size: %.2f M", comment: ""), Double(dataSize) / 1000.0 / 1000.0)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        compressionLabel.stringValue = NSLocalizedString("Image Quality:", comment: "")
        compressionLabel.font = .systemFont(ofSize: 15)
        compressionLabel.alignment = .right
        addSubview(compressionLabel)

        compressionButton.font = .systemFont(ofSize: 14)
        compressionButton.onAction { [unowned self] button in
            let compression = self.compressionArray[button.indexOfSelectedItem]
            LKPreferenceManager.mainManager.preferredExportCompression = compression
        }
        compressionButton.addItems(withTitles: compressionArray.map { "\(NSNumber(value: Double($0) * 100))%" })
        addSubview(compressionButton)

        sizeLabel.font = .systemFont(ofSize: 13)
        sizeLabel.stringValue = NSLocalizedString("File Size", comment: "")
        sizeLabel.alignment = .right
        addSubview(sizeLabel)

        LKPreferenceManager.mainManager.preferredExportCompressionPublisher
            .removeDuplicates()
            .sink { [weak self] num in
                guard let self else { return }
                let shouldSelectIdx = self.compressionArray.firstIndex { abs(num - $0) < 0.05 } ?? NSNotFound
                if self.compressionButton.indexOfSelectedItem != shouldSelectIdx {
                    self.compressionButton.selectItem(at: shouldSelectIdx)
                }
            }
            .store(in: &cancellables)
    }

    override func layout() {
        super.layout()
        compressionLabel.fitSize().setY(insetTop).setX(0)
        compressionButton.setWidth(buttonWidth).fitHeight().setX(compressionLabel.frame.maxX).setMidY(compressionLabel.frame.midY)
        sizeLabel.fillWidth().fitHeight().setY(compressionButton.frame.maxY + sizeLabelTop)
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.width = compressionLabel.sizeThatFits(.max).width + buttonWidth
        size.height = insetTop + compressionLabel.sizeThatFits(.max).height + sizeLabelTop + sizeLabel.sizeThatFits(.max).height + insetBottom
        return size
    }
}
