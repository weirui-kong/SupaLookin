//
//  LKConsoleInputRowView.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/6/1.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import LookinShared

final class LKConsoleInputRowView: LKTableRowView, LKInputSearchViewDelegate {

    private let dataSource: LKConsoleDataSource
    private let selectButton = NSButton()
    private let inputView = LKInputSearchView(throttleTime: 0.15)
    private let selectPopoverController: LKConsoleSelectPopoverController
    private var cancellables = Set<AnyCancellable>()

    init(dataSource: LKConsoleDataSource) {
        self.dataSource = dataSource
        selectPopoverController = LKConsoleSelectPopoverController(dataSource: dataSource)
        super.init(frame: .zero)

        selectPopoverController.needShowError = { [weak self] error in
            guard let window = self?.window else { return }
            NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
        }

        selectButton.font = .systemFont(ofSize: 13)
        selectButton.imagePosition = .imageRight
        selectButton.bezelStyle = .roundRect
        selectButton.isBordered = false
        selectButton.image = NSImage(named: "Console_UpDownArrow")
        selectButton.onAction { [unowned self] _ in
            self.handleSelectButton()
        }
        addSubview(selectButton)

        inputView.delegate = self
        inputView.textField.focusRingType = .none
        addSubview(inputView)

        dataSource.currentObjectPublisher
            .sink { [weak self] _ in
                self?.handleCurrentObjectDidChange()
            }
            .store(in: &cancellables)
    }

    override func layout() {
        super.layout()
        selectButton.fillHeight().fitWidth().limitWidth(max: frame.width * 0.5).setX(ConsoleInsetLeft)
        inputView.setX(selectButton.frame.maxX + 5).extendToRight(ConsoleInsetRight).fillHeight()
    }

    override func isDarkModeDidChange() {
        super.isDarkModeDidChange()
        // 更新 selectButton textColor
        handleCurrentObjectDidChange()
    }

    func makeTextFieldAsFirstResponder() {
        window?.makeFirstResponder(inputView.textField)
    }

    private func handleSelectButton() {
        selectPopoverController.reRender()
        let popover = NSPopover()
        popover.animates = false
        popover.behavior = .transient
        popover.contentSize = NSSize(width: LKHelper.isEnglish ? 465 : 400, height: selectPopoverController.bestHeight())
        popover.contentViewController = selectPopoverController
        popover.show(relativeTo: NSRect(x: 0, y: 0, width: selectButton.bounds.size.width, height: selectButton.bounds.size.height), of: selectButton, preferredEdge: .minY)

        selectPopoverController.needClose = { [weak popover] in
            popover?.close()
        }
    }

    private func handleCurrentObjectDidChange() {
        inputView.clearContentAndSuggestions()

        let selectButtonColor = isDarkMode ? NSColor(lookinRed: 85, green: 200, blue: 95) : NSColor(lookinRed: 54, green: 155, blue: 62)
        if let obj = dataSource.currentObject {
            let string = "<\(obj.simpleDemangledClassName): \(obj.memoryAddress ?? "(null)")>"
            selectButton.attributedTitle = LKAttributedStringBuilder(string).textColor(selectButtonColor).attributedString ?? NSAttributedString()
            inputView.textField.isEditable = true
            inputView.textField.placeholderString = NSLocalizedString("Type property or method name here", comment: "")
        } else {
            let str = NSLocalizedString("Select target object", comment: "")
            selectButton.attributedTitle = LKAttributedStringBuilder(str).textColor(selectButtonColor).attributedString ?? NSAttributedString()
            inputView.textField.isEditable = false
            inputView.textField.placeholderString = ""
        }
        needsLayout = true
    }

    // MARK: - LKInputSearchViewDelegate

    func inputSearchView(_ view: LKInputSearchView, suggestionsFor string: String) -> [LKInputSearchSuggestionItem]? {
        if string.utf16.count < 3 {
            return nil
        }
        let candidates = dataSource.currentObjectSelectorNameList() ?? []
        let suggestions = LKHelper.bestMatches(in: candidates, input: string, maxResultsCount: 8)
        return suggestions.map { suggestion in
            let item = LKInputSearchSuggestionItem()
            item.image = NSImage(named: "icon_method")
            item.text = suggestion
            return item
        }
    }

    func inputSearchView(_ view: LKInputSearchView, submitText text: String) {
        Task { [weak self, weak view] in
            do {
                try await self?.dataSource.submit(text)
                view?.clearContentAndSuggestions()
            } catch {
                LKHelper.alertError(error, window: self?.window)
            }
        }
    }
}
