//
//  EndToEndTests.swift
//  SPLKEndToEndTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Testing
import SPLKProtocol
import SPLKServer

// Runs against the demo in Scripts/e2e on a simulator; Scripts/e2e-sim.sh sets everything up.
private let enabled = ProcessInfo.processInfo.environment["SPLK_E2E"] == "1"
private let demoBundleID = "icu.retrouvailles.splkdemo"

private let allCapabilities: Set<String> = [
    SPLKCapability.app, SPLKCapability.hierarchy, SPLKCapability.details, SPLKCapability.attrModify,
    SPLKCapability.attrCustom, SPLKCapability.attrGroups, SPLKCapability.object, SPLKCapability.objectInvoke,
    SPLKCapability.objectSelectors, SPLKCapability.image, SPLKCapability.gestureToggle,
    SPLKCapability.controlLease, SPLKCapability.events,
    SPLKCapability.inputTouch, SPLKCapability.inputMotion, SPLKCapability.inputText,
    SPLKCapability.actionSemantic, SPLKCapability.waitIdle, SPLKCapability.eventsHierarchy,
]

private func connect() async throws -> SPLKClientSession {
    let configuration = SPLKClientSession.Configuration(clientName: "SPLKEndToEndTests", clientVersion: "1.0", capabilities: allCapabilities)
    for port in UInt16(SPLKSimulatorIPv4PortNumberStart)...UInt16(SPLKSimulatorIPv4PortNumberEnd) {
        guard let session = try? await SPLKClientSession.connect(configuration: configuration, open: { _ in
            try await SPLKNetworkByteStream.connect(host: "127.0.0.1", port: port, timeout: 1)
        }) else { continue }
        if session.serverHello.app.bundleIdentifier == demoBundleID {
            return session
        }
        await session.close()
    }
    throw SPLKStatusError(.unavailable, reason: "demo_not_found")
}

private struct Tree {
    let nodes: [SPLKV2Node]

    func node(ofClass name: String) throws -> SPLKV2Node {
        try #require(nodes.first { $0.view.classChain.first == name }, "no \(name)")
    }

    func controller() throws -> UInt64 {
        try #require(nodes.first { $0.hostViewController.classChain.first == "SPLKDemo.SPLKDemoViewController" }).hostViewController.oid
    }
}

private func hierarchy(_ session: SPLKClientSession) async throws -> Tree {
    let response = try await session.unary(.getHierarchy(SPLKV2GetHierarchy()))
    guard case .hierarchy(let snapshot) = response.result else {
        throw SPLKStatusError(.internal, reason: "no_hierarchy")
    }
    return Tree(nodes: snapshot.nodes)
}

private func attributeGroups(_ session: SPLKClientSession, layerOid: UInt64) async throws -> [SPLKV2AttributeGroup] {
    var call = SPLKV2GetAttributeGroups()
    call.oid = layerOid
    let response = try await session.unary(.getAttributeGroups(call))
    guard case .attributeGroups(let list) = response.result else { return [] }
    return list.groups
}

// Custom attributes, like v1's, only come with a node's details.
private func details(_ session: SPLKClientSession, layerOid: UInt64) async throws -> SPLKV2NodeDetail {
    var task = SPLKV2DetailTask()
    task.oid = layerOid
    task.screenshot = .group
    task.attrRequest = .attrNeed
    task.needBasicVisualInfo = true
    var package = SPLKV2DetailTaskPackage()
    package.tasks = [task]
    var call = SPLKV2FetchDetails()
    call.packages = [package]
    for try await item in try await session.stream(.fetchDetails(call)) {
        if case .nodeDetail(let detail) = item.item {
            return detail
        }
    }
    throw SPLKStatusError(.internal, reason: "no_details")
}

private func attribute(_ identifier: String, in groups: [SPLKV2AttributeGroup]) -> SPLKV2Attribute? {
    groups.flatMap(\.sections).flatMap(\.attributes).first { $0.identifier == identifier }
}

private func invoke(_ session: SPLKClientSession, oid: UInt64, _ text: String) async throws -> SPLKV2InvokeResult {
    var call = SPLKV2InvokeMethod()
    call.oid = oid
    call.text = text
    let response = try await session.unary(.invokeMethod(call))
    guard case .invokeResult(let result) = response.result else {
        throw SPLKStatusError(.internal, reason: "no_invoke_result")
    }
    return result
}

private func simctl(_ arguments: String...) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["simctl"] + arguments
    try process.run()
    process.waitUntilExit()
}

@Suite(.serialized, .enabled(if: enabled))
struct EndToEndTests {

    @Test func appInfoAndHierarchy() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        #expect(session.serverHello.protocolGeneration == 2)
        #expect(session.capabilities == allCapabilities)

        var call = SPLKV2GetAppInfo()
        call.needImages = true
        let response = try await session.unary(.getAppInfo(call))
        guard case .appInfo(let info) = response.result else {
            Issue.record("no app info")
            return
        }
        #expect(info.summary.name == "SPLKDemo")
        #expect(info.screenshot.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))

        let tree = try await hierarchy(session)
        for name in ["UILabel", "UITextField", "UITextView", "UIImageView", "UIButton", "UIVisualEffectView", "UITableView"] {
            _ = try tree.node(ofClass: name)
        }
        let custom = try await details(session, layerOid: tree.node(ofClass: "SPLKDemo.SPLKDemoCustomView").layer.oid)
        let types = Set(custom.customAttributeGroups.flatMap(\.sections).flatMap(\.attributes).map(\.type))
        #expect(types == [.attrString, .attrDouble, .attrBool, .attrUiColor, .attrCgRect, .attrCgSize, .attrCgPoint, .attrUiEdgeInsets, .attrShadow, .attrEnumString, .attrJson])
        let mode = custom.customAttributeGroups.flatMap(\.sections).flatMap(\.attributes).first { $0.type == .attrEnumString }
        #expect(mode?.enumCases == ["a", "b", "c"])
    }

    @Test func detailsAndPatches() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let label = try await hierarchy(session).node(ofClass: "UILabel")

        var task = SPLKV2DetailTask()
        task.oid = label.layer.oid
        task.screenshot = .group
        task.attrRequest = .attrNeed
        task.needBasicVisualInfo = true
        var package = SPLKV2DetailTaskPackage()
        package.tasks = [task]
        var call = SPLKV2FetchDetails()
        call.packages = [package]
        var details: [SPLKV2NodeDetail] = []
        for try await item in try await session.stream(.fetchDetails(call)) {
            if case .nodeDetail(let detail) = item.item {
                details.append(detail)
            }
        }
        let detail = try #require(details.first)
        #expect(detail.oid == label.layer.oid)
        #expect(detail.groupScreenshot.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(attribute(SPLKAttr_UILabel_Text_Text, in: detail.attributeGroups)?.value.stringValue == "SPLK e2e")

        var patch = SPLKV2FetchModificationPatch()
        patch.tasks = [task]
        var patches = 0
        for try await _ in try await session.stream(.fetchModificationPatch(patch)) {
            patches += 1
        }
        #expect(patches == 1)
    }

    @Test func attributeGroupsCoverObjectValues() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let tree = try await hierarchy(session)

        let labelGroups = try await attributeGroups(session, layerOid: tree.node(ofClass: "UILabel").layer.oid)
        #expect(attribute(SPLKAttr_UILabel_Text_Text, in: labelGroups)?.value.stringValue == "SPLK e2e")
        let classChain = attribute(SPLKAttr_Class_Class_Class, in: labelGroups)?.value.list.values.first?.list.values.map(\.stringValue)
        #expect(classChain?.first == "UILabel")

        let tableGroups = try await attributeGroups(session, layerOid: tree.node(ofClass: "UITableView").layer.oid)
        #expect(attribute(SPLKAttr_UITableView_RowsNumber_Number, in: tableGroups)?.value.list.values.map(\.intValue) == [30, 1])

        let customGroups = try await attributeGroups(session, layerOid: tree.node(ofClass: "SPLKDemo.SPLKDemoCustomView").layer.oid)
        #expect(attribute(SPLKAttr_AutoLayout_Constraints_Constraints, in: customGroups)?.value.list.values.isEmpty == false)

        let effectGroups = try await attributeGroups(session, layerOid: tree.node(ofClass: "UIVisualEffectView").layer.oid)
        #expect(attribute(SPLKAttr_UIVisualEffectView_Style_Style, in: effectGroups)?.value.intValue != nil)
    }

    @Test func modifications() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let tree = try await hierarchy(session)
        let label = try tree.node(ofClass: "UILabel")

        var modify = SPLKV2ModifyAttribute()
        modify.targetOid = label.view.oid
        modify.setter = "setAlpha:"
        modify.getter = "alpha"
        modify.type = .attrDouble
        modify.value.doubleValue = 0.5
        let response = try await session.unary(.modifyAttribute(modify))
        guard case .nodeDetail = response.result else {
            Issue.record("no detail after modifying")
            return
        }
        #expect(try await invoke(session, oid: label.view.oid, "alpha").description_p == "0.5")
        modify.value.doubleValue = 1
        _ = try await session.unary(.modifyAttribute(modify))

        let custom = try tree.node(ofClass: "SPLKDemo.SPLKDemoCustomView")
        let customDetail = try await details(session, layerOid: custom.layer.oid)
        let note = try #require(customDetail.customAttributeGroups.flatMap(\.sections).flatMap(\.attributes).first { $0.displayTitle == "Note" })
        var customModify = SPLKV2ModifyCustomAttribute()
        customModify.customSetterID = note.customSetterID
        customModify.type = .attrString
        customModify.value.stringValue = "changed"
        _ = try await session.unary(.modifyCustomAttribute(customModify))
        #expect(try await invoke(session, oid: custom.view.oid, "demoNote").description_p == "changed")
    }

    @Test func objectsMethodsImagesGestures() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let tree = try await hierarchy(session)
        let label = try tree.node(ofClass: "UILabel")

        #expect(try await invoke(session, oid: label.view.oid, "text").description_p == "SPLK e2e")
        #expect(try await invoke(session, oid: label.view.oid, "superview").hasObject)
        #expect(try await invoke(session, oid: label.view.oid, "layoutIfNeeded").returnsVoid)

        var getObject = SPLKV2GetObject()
        getObject.oid = label.view.oid
        let object = try await session.unary(.getObject(getObject))
        if case .object(let ref) = object.result {
            #expect(ref.classChain.first == "UILabel")
        } else {
            Issue.record("no object")
        }

        var image = SPLKV2GetImageViewImage()
        image.oid = try tree.node(ofClass: "UIImageView").view.oid
        let imageResponse = try await session.unary(.getImageViewImage(image))
        if case .image(let encoded) = imageResponse.result {
            #expect(encoded.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        } else {
            Issue.record("no image")
        }

        let custom = try tree.node(ofClass: "SPLKDemo.SPLKDemoCustomView")
        let recognizer = try #require(custom.eventHandlers.first { $0.kind == .gesture })
        for enabled in [false, true] {
            var toggle = SPLKV2SetGestureRecognizerEnabled()
            toggle.oid = recognizer.recognizerOid
            toggle.enabled = enabled
            let toggled = try await session.unary(.setGestureRecognizerEnabled(toggle))
            #expect(toggled.result == .gestureEnabled(enabled))
        }

        var selectors = SPLKV2ListSelectors()
        selectors.className = "UILabel"
        let names = try await session.unary(.listSelectors(selectors))
        if case .selectors(let list) = names.result {
            #expect(list.values.contains("text"))
        } else {
            Issue.record("no selectors")
        }
    }

    @Test func errors() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        do {
            _ = try await attributeGroups(session, layerOid: 999_999_999)
            Issue.record("expected NOT_FOUND")
        } catch let error as SPLKStatusError {
            #expect(error.code == .notFound)
            #expect(error.reason == "object_deallocated")
        }
        let label = try await hierarchy(session).node(ofClass: "UILabel")
        do {
            _ = try await invoke(session, oid: label.view.oid, "noSuchMethod")
            Issue.record("expected an error")
        } catch let error as SPLKStatusError {
            #expect(error.title.contains("noSuchMethod"))
        }
    }

    @Test func backgroundRejectsRequests() async throws {
        let udid = try #require(ProcessInfo.processInfo.environment["SPLK_E2E_UDID"])
        let session = try await connect()
        defer { Task { await session.close() } }
        try simctl("launch", udid, "com.apple.Preferences")
        try await Task.sleep(nanoseconds: 300_000_000)
        do {
            _ = try await session.unary(.getHierarchy(SPLKV2GetHierarchy()), deadlineMs: 2000)
            Issue.record("expected app_in_background")
        } catch let error as SPLKStatusError {
            // Once iOS suspends the app it can't answer at all, and the call times out, as it did in v1.
            let rejected = error.code == .failedPrecondition && error.reason == "app_in_background"
            #expect(rejected || error.code == .deadlineExceeded)
        }
        try simctl("launch", udid, demoBundleID)
        try await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func recognizerToggle(_ session: SPLKClientSession) async throws -> SPLKV2SetGestureRecognizerEnabled {
        let tree = try await hierarchy(session)
        let custom = try tree.node(ofClass: "SPLKDemo.SPLKDemoCustomView")
        var toggle = SPLKV2SetGestureRecognizerEnabled()
        toggle.oid = try #require(custom.eventHandlers.first { $0.kind == .gesture }).recognizerOid
        toggle.enabled = true
        return toggle
    }

    private func acquire(_ session: SPLKClientSession, preempt: Bool = false) async throws -> Data {
        var call = SPLKV2AcquireControl()
        call.kind = .liveControl
        call.holderLabel = "Tests"
        call.preempt = preempt
        guard case .lease(let lease) = try await session.unary(.acquireControl(call)).result else {
            throw SPLKStatusError(.internal, reason: "no_lease")
        }
        return lease.leaseID
    }

    private func release(_ session: SPLKClientSession, _ leaseID: Data) async throws {
        var call = SPLKV2ReleaseControl()
        call.leaseID = leaseID
        _ = try await session.unary(.releaseControl(call))
    }

    private func reason(_ body: () async throws -> Void) async -> String? {
        do {
            try await body()
            return nil
        } catch let error as SPLKStatusError {
            return error.reason
        } catch {
            return "\(error)"
        }
    }

    @Test func leasesGateMutations() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let toggle = try await recognizerToggle(session)
        let other = Data([1, 2, 3])

        let lease = try await acquire(session)
        #expect(await reason { _ = try await session.unary(.setGestureRecognizerEnabled(toggle)) } == "lease_required")
        #expect(await reason { _ = try await session.unary(.setGestureRecognizerEnabled(toggle), leaseID: other) } == "lease_revoked")
        #expect(await reason { _ = try await session.unary(.setGestureRecognizerEnabled(toggle), leaseID: lease) } == nil)
        // Reads never need a lease.
        _ = try await hierarchy(session)

        #expect(await reason { _ = try await self.acquire(session) } == "lease_held")
        let preempting = try await acquire(session, preempt: true)
        #expect(await reason { _ = try await session.unary(.setGestureRecognizerEnabled(toggle), leaseID: lease) } == "lease_revoked")

        try await release(session, preempting)
        #expect(await reason { _ = try await session.unary(.setGestureRecognizerEnabled(toggle)) } == nil)
        #expect(await reason { _ = try await session.unary(.setGestureRecognizerEnabled(toggle), leaseID: preempting) } == "lease_revoked")
    }

    @Test func leaseEndsWithItsSession() async throws {
        let first = try await connect()
        _ = try await acquire(first)
        await first.close()
        try await Task.sleep(nanoseconds: 300_000_000)

        let second = try await connect()
        defer { Task { await second.close() } }
        let toggle = try await recognizerToggle(second)
        #expect(await reason { _ = try await second.unary(.setGestureRecognizerEnabled(toggle)) } == nil)
    }

    @Test func eventsReportAppStateAndControl() async throws {
        let udid = try #require(ProcessInfo.processInfo.environment["SPLK_E2E_UDID"])
        let session = try await connect()
        defer { Task { await session.close() } }
        var subscribe = SPLKV2Subscribe()
        subscribe.topics = ["app_state", "control", "screen"]
        let events = try await session.stream(.subscribe(subscribe), deadlineMs: .max)
        var iterator = events.makeAsyncIterator()

        func next() async throws -> SPLKV2Event.OneOf_Kind? {
            try await iterator.next()?.event.kind
        }
        #expect(try await next() == .appInForeground(true))
        if case .screen(let screen) = try await next() {
            #expect(screen.size.width > 0)
        } else {
            Issue.record("no screen event")
        }

        let lease = try await acquire(session)
        guard case .leaseAcquired(let acquired) = try await next() else {
            Issue.record("no lease_acquired")
            return
        }
        #expect(acquired.leaseID == lease)
        try await release(session, lease)
        guard case .leaseReleased = try await next() else {
            Issue.record("no lease_released")
            return
        }

        try simctl("launch", udid, "com.apple.Preferences")
        #expect(try await next() == .appInForeground(false))
        try simctl("launch", udid, demoBundleID)
        #expect(try await next() == .appInForeground(true))
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    // MARK: - Input

    private func touch(_ id: UInt32, _ phase: SPLKV2Touch.Phase, _ point: CGPoint, screen: SPLKV2Size) -> SPLKV2InputEvent {
        var touch = SPLKV2Touch()
        touch.touchID = id
        touch.phase = phase
        touch.location.x = Double(point.x) / screen.width
        touch.location.y = Double(point.y) / screen.height
        var event = SPLKV2InputEvent()
        event.touch = touch
        return event
    }

    private func tap(at point: CGPoint, screen: SPLKV2Size) -> [SPLKV2InputEvent] {
        [touch(1, .began, point, screen: screen), touch(1, .ended, point, screen: screen)]
    }

    private func inject(_ session: SPLKClientSession, _ events: [SPLKV2InputEvent], leaseID: Data = Data()) async throws {
        var call = SPLKV2InjectInput()
        call.events = events
        try await session.oneway(.injectInput(call), leaseID: leaseID)
    }

    private func center(_ node: SPLKV2Node) -> CGPoint {
        CGPoint(x: node.frame.origin.x + node.frame.size.width / 2, y: node.frame.origin.y + node.frame.size.height / 2)
    }

    // Polls `selector` on `oid` until its description is `expected`.
    private func eventually(_ session: SPLKClientSession, oid: UInt64, _ selector: String, _ expected: (String) -> Bool) async throws -> Bool {
        for _ in 0..<40 {
            if expected(try await invoke(session, oid: oid, selector).description_p) {
                return true
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    @Test func touchesTapScrollAndPinch() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let screen = session.serverHello.app.screen.size
        let tree = try await hierarchy(session)
        let controller = try tree.controller()
        let before = Int(try await invoke(session, oid: controller, "buttonTaps").description_p) ?? 0

        try await inject(session, tap(at: center(try tree.node(ofClass: "UIButton")), screen: screen))
        #expect(try await eventually(session, oid: controller, "buttonTaps") { Int($0) == before + 1 })

        let viewTaps = Int(try await invoke(session, oid: controller, "viewTaps").description_p) ?? 0
        try await inject(session, tap(at: center(try tree.node(ofClass: "SPLKDemo.SPLKDemoCustomView")), screen: screen))
        #expect(try await eventually(session, oid: controller, "viewTaps") { Int($0) == viewTaps + 1 })

        let table = try tree.node(ofClass: "UITableView")
        let start = CGPoint(x: center(table).x, y: table.frame.origin.y + table.frame.size.height - 10)
        var drag = [touch(1, .began, start, screen: screen)]
        for step in 1...12 {
            drag.append(touch(1, .moved, CGPoint(x: start.x, y: start.y - CGFloat(step) * 12), screen: screen))
        }
        drag.append(touch(1, .ended, CGPoint(x: start.x, y: start.y - 144), screen: screen))
        try await inject(session, drag)
        #expect(try await eventually(session, oid: table.view.oid, "contentOffset") { description in
            let numbers = description.components(separatedBy: CharacterSet(charactersIn: "{}, ")).compactMap(Double.init)
            return (numbers.last ?? 0) > 20
        })

        let custom = center(try tree.node(ofClass: "SPLKDemo.SPLKDemoCustomView"))
        let pinch = [
            touch(1, .began, CGPoint(x: custom.x - 5, y: custom.y), screen: screen),
            touch(2, .began, CGPoint(x: custom.x + 5, y: custom.y), screen: screen),
            touch(1, .moved, CGPoint(x: custom.x - 30, y: custom.y), screen: screen),
            touch(2, .moved, CGPoint(x: custom.x + 30, y: custom.y), screen: screen),
            touch(1, .ended, CGPoint(x: custom.x - 30, y: custom.y), screen: screen),
            touch(2, .ended, CGPoint(x: custom.x + 30, y: custom.y), screen: screen),
        ]
        try await inject(session, pinch)
        try await Task.sleep(nanoseconds: 300_000_000)
        var failures = session.onewayFailures.makeAsyncIterator()
        await session.close()
        #expect(await failures.next() == nil)
    }

    @Test func shakeAndText() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let tree = try await hierarchy(session)
        let controller = try tree.controller()
        _ = try await invoke(session, oid: controller, "becomeFirstResponder")
        let shakes = Int(try await invoke(session, oid: controller, "shakes").description_p) ?? 0
        var shake = SPLKV2InputEvent()
        shake.motion.kind = .shake
        try await inject(session, [shake])
        #expect(try await eventually(session, oid: controller, "shakes") { Int($0) == shakes + 1 })

        let field = try tree.node(ofClass: "UITextField")
        _ = try await invoke(session, oid: field.view.oid, "becomeFirstResponder")
        var text = SPLKV2InputEvent()
        text.text.text = "abc"
        var delete = SPLKV2InputEvent()
        delete.key.code = .delete
        try await inject(session, [text, delete])
        #expect(try await eventually(session, oid: field.view.oid, "text") { $0 == "ab" })
        _ = try await invoke(session, oid: field.view.oid, "resignFirstResponder")
    }

    @Test func inputNeedsTheLease() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let lease = try await acquire(session)
        var shake = SPLKV2InputEvent()
        shake.motion.kind = .shake
        try await inject(session, [shake])
        var failures = session.onewayFailures.makeAsyncIterator()
        let failure = await failures.next()
        #expect(failure?.error.reason == "lease_required")
        try await inject(session, [shake], leaseID: lease)
        try await release(session, lease)
    }

    // MARK: - Agents

    private func perform(_ session: SPLKClientSession, _ action: SPLKV2PerformAction.Action, oid: UInt64, text: String = "", delta: CGPoint = .zero, leaseID: Data = Data()) async throws -> SPLKV2ActionResult {
        var call = SPLKV2PerformAction()
        call.oid = oid
        call.action = action
        call.text = text
        call.delta.x = Double(delta.x)
        call.delta.y = Double(delta.y)
        guard case .actionResult(let result) = try await session.unary(.performAction(call), leaseID: leaseID).result else {
            throw SPLKStatusError(.internal, reason: "no_action_result")
        }
        return result
    }

    @Test func semanticActions() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let tree = try await hierarchy(session)
        let controller = try tree.controller()

        let taps = Int(try await invoke(session, oid: controller, "buttonTaps").description_p) ?? 0
        let tapped = try await perform(session, .tap, oid: try tree.node(ofClass: "UIButton").view.oid)
        #expect(tapped.settled)
        #expect(try await invoke(session, oid: controller, "buttonTaps").description_p == "\(taps + 1)")

        let viewTaps = Int(try await invoke(session, oid: controller, "viewTaps").description_p) ?? 0
        _ = try await perform(session, .tap, oid: try tree.node(ofClass: "SPLKDemo.SPLKDemoCustomView").layer.oid)
        #expect(try await eventually(session, oid: controller, "viewTaps") { Int($0) == viewTaps + 1 })

        let field = try tree.node(ofClass: "UITextField")
        _ = try await perform(session, .setText, oid: field.view.oid, text: "hello")
        #expect(try await invoke(session, oid: field.view.oid, "text").description_p == "hello")
        _ = try await invoke(session, oid: field.view.oid, "resignFirstResponder")

        let table = try tree.node(ofClass: "UITableView")
        _ = try await perform(session, .scrollBy, oid: table.view.oid, delta: CGPoint(x: 0, y: -10_000))
        _ = try await perform(session, .scrollBy, oid: table.view.oid, delta: CGPoint(x: 0, y: 100))
        let offset = try await invoke(session, oid: table.view.oid, "contentOffset").description_p
        #expect(offset.contains("100"))

        _ = try await invoke(session, oid: controller, "pushDetail")
        #expect(try await invoke(session, oid: controller, "detailShown").description_p == "YES")
        let back = try await perform(session, .goBack, oid: 0)
        #expect(back.settled)
        #expect(try await invoke(session, oid: controller, "detailShown").description_p == "NO")

        do {
            _ = try await perform(session, .setText, oid: try tree.node(ofClass: "UIButton").view.oid, text: "x")
            Issue.record("expected no_text_input")
        } catch let error as SPLKStatusError {
            #expect(error.reason == "no_text_input")
        }
    }

    @Test func idleAndHierarchyEvents() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        var wait = SPLKV2WaitForIdle()
        wait.timeoutMs = 3000
        guard case .actionResult(let idle) = try await session.unary(.waitForIdle(wait)).result else {
            Issue.record("no wait result")
            return
        }
        #expect(idle.settled)

        var subscribe = SPLKV2Subscribe()
        subscribe.topics = ["hierarchy_changed"]
        let events = try await session.stream(.subscribe(subscribe), deadlineMs: .max)
        var iterator = events.makeAsyncIterator()
        // The current version comes first, once the subscription is in place.
        guard case .hierarchyChangedVersion = try await iterator.next()?.event.kind else {
            Issue.record("no initial version")
            return
        }
        let table = try await hierarchy(session).node(ofClass: "UITableView")
        let scrolled = try await perform(session, .scrollBy, oid: table.view.oid, delta: CGPoint(x: 0, y: 40))
        guard case .hierarchyChangedVersion(let version) = try await iterator.next()?.event.kind else {
            Issue.record("no hierarchy_changed")
            return
        }
        #expect(version <= scrolled.hierarchyVersion)
        let snapshot = try await session.unary(.getHierarchy(SPLKV2GetHierarchy()))
        if case .hierarchy(let tree) = snapshot.result {
            #expect(tree.version >= scrolled.hierarchyVersion)
        }
    }

    @Test func actionsNeedTheLease() async throws {
        let session = try await connect()
        defer { Task { await session.close() } }
        let button = try await hierarchy(session).node(ofClass: "UIButton")
        let lease = try await acquire(session)
        #expect(await reason { _ = try await self.perform(session, .tap, oid: button.view.oid) } == "lease_required")
        #expect(await reason { _ = try await self.perform(session, .tap, oid: button.view.oid, leaseID: lease) } == nil)
        try await release(session, lease)
    }
}
