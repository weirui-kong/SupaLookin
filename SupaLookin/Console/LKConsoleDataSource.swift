//
//  LKConsoleDataSource.swift
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

final class LKConsoleDataSource {

    var rowItems: [LKConsoleDataSourceRowItem] = [] {
        didSet {
            rowItemsObservation.notify()
        }
    }

    private(set) var currentObject: LookinObject? {
        didSet {
            currentObjectObservation.notify()
        }
    }

    private lazy var rowItemsObservation = LKKVOSubject { [unowned self] in self.rowItems }
    private lazy var currentObjectObservation = LKKVOSubject { [unowned self] in self.currentObject }
    var rowItemsPublisher: AnyPublisher<[LKConsoleDataSourceRowItem], Never> { rowItemsObservation.publisher }
    var currentObjectPublisher: AnyPublisher<LookinObject?, Never> { currentObjectObservation.publisher }

    private(set) var recentObjects: [(object: LookinObject, message: String)] = []

    private(set) var selectedObjects: [LookinObject]? {
        didSet {
            syncConsoleTargetIfNeeded()
        }
    }

    var isShowingConsole = false {
        didSet {
            syncConsoleTargetIfNeeded()
        }
    }

    /**
     [
         "UIView": ["layoutSubviews", ...],
         "UIViewController": ["viewDidAppear:", ...],
         ...
     ]
     */
    private var classesToSelsDict: [String: [String]] = [:]

    private var cancellables = Set<AnyCancellable>()

    init(hierarchyDataSource: LKHierarchyDataSource) {
        let item = LKConsoleDataSourceRowItem()
        item.type = .input
        rowItems = [item]

        hierarchyDataSource.selectedItemPublisher
            .map { item -> [LookinObject]? in
                guard let item else {
                    return nil
                }
                return [item.hostViewControllerObject, item.layerObject, item.viewObject].compactMap { $0 }
            }
            .sink { [weak self] objs in
                self?.selectedObjects = objs
            }
            .store(in: &cancellables)
    }

    func submit(_ text: String) async throws {
        try await submit(withObj: currentObject, text: text)
    }

    func submit(withObj obj: LookinObject?, text: String) async throws {
        guard currentObject != nil, let obj else {
            throw LookinError.inner
        }
        if text.isEmpty {
            throw LookinError.make(NSLocalizedString("Content is empty.", comment: ""), "")
        }
        guard let inspectingApp = LKAppsManager.sharedInstance.inspectingApp else {
            throw LookinError.noConnect
        }
        if text.contains(":") {
            let className = obj.rawClassName() ?? "(null)"
            let address = obj.memoryAddress ?? "(null)"
            let errDesc = String(format: NSLocalizedString("You can click \"Pause\" button near the bottom-left corner in Xcode to pause your iOS app, and input in Xcode console like the contents below:\nexpr [((%@ *)%@) %@]", comment: ""), className, address, text)
            throw LookinError.make(NSLocalizedString("Lookin doesn't support invoking methods with arguments yet.", comment: ""), errDesc)
        }
        if text.contains(".") {
            throw LookinError.make(NSLocalizedString("Lookin doesn't support this syntax yet. Please input a method or property name.", comment: ""), "")
        }
        let dict = try await inspectingApp.invokeMethod(withOid: obj.oid, text: text)
        let returnDescription = dict?["description"] as? String
        let returnObject = dict?["object"] as? LookinObject

        var rowItems = self.rowItems
        let submitItem = LKConsoleDataSourceRowItem()
        submitItem.type = .submit
        submitItem.normalText = text
        submitItem.highlightText = "<\(obj.simpleDemangledClassName): \(obj.memoryAddress ?? "(null)")>"
        rowItems.insert(submitItem, at: rowItems.count - 1)
        if let returnDescription, !returnDescription.isEmpty {
            let returnItem = LKConsoleDataSourceRowItem()
            returnItem.type = .return
            returnItem.normalText = returnDescription
            rowItems.insert(returnItem, at: rowItems.count - 1)
        }
        if let returnObject {
            let message = "<\(obj.simpleDemangledClassName): \(obj.memoryAddress ?? "(null)")> => \(text)"
            addRecentObject(returnObject, message: message)
        }

        self.rowItems = rowItems
    }

    func makeObjectAsCurrent(_ obj: LookinObject?) async throws {
        guard let className = obj?.rawClassName(), !className.isEmpty, let obj else {
            throw LookinError.inner
        }
        guard let inspectingApp = LKAppsManager.sharedInstance.inspectingApp else {
            throw LookinError.noConnect
        }
        if classesToSelsDict[className] != nil {
            currentObject = obj
            return
        }

        let sels = try await inspectingApp.fetchSelectorNames(withClass: className, hasArg: true)
        classesToSelsDict[className] = sels
        currentObject = obj
    }

    func currentObjectSelectorNameList() -> [String]? {
        guard let className = currentObject?.rawClassName() else {
            return nil
        }
        return classesToSelsDict[className]
    }

    func clearHistoryContents() {
        let item = LKConsoleDataSourceRowItem()
        item.type = .input
        rowItems = [item]
    }

    private func syncConsoleTargetIfNeeded() {
        if isShowingConsole, let selectedObjects, !selectedObjects.isEmpty {
            if LKPreferenceManager.mainManager.syncConsoleTarget || currentObject == nil {
                let target = selectedObjects.last
                Task {
                    try? await self.makeObjectAsCurrent(target)
                }
            }
        }
    }

    private func addRecentObject(_ object: LookinObject, message: String) {
        if let sameObjIdx = recentObjects.firstIndex(where: { $0.object.oid == object.oid }) {
            recentObjects.remove(at: sameObjIdx)
        }

        let maxCount = 5
        recentObjects.insert((object, message), at: 0)

        if recentObjects.count > maxCount {
            recentObjects.removeLast()
        }
    }
}
