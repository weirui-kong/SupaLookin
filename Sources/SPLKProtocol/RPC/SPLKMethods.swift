//
//  SPLKMethods.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation

public enum SPLKProtocolInfo {
    public static let generation: UInt32 = 2
    public static let defaultDeadline: TimeInterval = 5
    public static let handshakeTimeout: TimeInterval = 2
    public static let heartbeatInterval: TimeInterval = 2
    public static let livenessTimeout: TimeInterval = 6
}

public enum SPLKCapability {
    public static let app = "app"
    public static let hierarchy = "hierarchy"
    public static let details = "details"
    public static let attrModify = "attr.modify"
    public static let attrCustom = "attr.custom"
    public static let attrGroups = "attr.groups"
    public static let object = "object"
    public static let objectInvoke = "object.invoke"
    public static let objectSelectors = "object.selectors"
    public static let image = "image"
    public static let gestureToggle = "gesture.toggle"

    public static let controlLease = "control.lease"
    public static let events = "events"
    public static let eventsHierarchy = "events.hierarchy"
    public static let inputTouch = "input.touch"
    public static let inputMotion = "input.motion"
    public static let inputText = "input.text"
    public static let actionSemantic = "action.semantic"
    public static let waitIdle = "wait.idle"
    public static let hierarchyDiff = "hierarchy.diff"
    public static let videoInAppH264 = "video.inapp.h264"
}

extension SPLKV2Request.OneOf_Call {

    public var channel: SPLKV2ChannelRole {
        switch self {
        case .getHierarchy, .fetchDetails, .fetchModificationPatch, .getImageViewImage:
            return .bulk
        default:
            return .control
        }
    }

    public var isMutating: Bool {
        switch self {
        case .modifyAttribute, .modifyCustomAttribute, .invokeMethod, .setGestureRecognizerEnabled, .injectInput, .performAction:
            return true
        default:
            return false
        }
    }

    public var requiredCapabilities: Set<String> {
        switch self {
        case .getAppInfo: return [SPLKCapability.app]
        case .getHierarchy: return [SPLKCapability.hierarchy]
        case .fetchDetails: return [SPLKCapability.details]
        case .modifyAttribute, .fetchModificationPatch: return [SPLKCapability.attrModify]
        case .modifyCustomAttribute: return [SPLKCapability.attrCustom]
        case .getAttributeGroups: return [SPLKCapability.attrGroups]
        case .getObject: return [SPLKCapability.object]
        case .invokeMethod: return [SPLKCapability.objectInvoke]
        case .listSelectors: return [SPLKCapability.objectSelectors]
        case .getImageViewImage: return [SPLKCapability.image]
        case .setGestureRecognizerEnabled: return [SPLKCapability.gestureToggle]
        case .acquireControl, .releaseControl: return [SPLKCapability.controlLease]
        case .subscribe: return [SPLKCapability.events]
        case .performAction: return [SPLKCapability.actionSemantic]
        case .waitForIdle: return [SPLKCapability.waitIdle]
        case .injectInput(let input):
            return Set(input.events.compactMap { event -> String? in
                switch event.kind {
                case .touch: return SPLKCapability.inputTouch
                case .motion: return SPLKCapability.inputMotion
                case .text, .key: return SPLKCapability.inputText
                case nil: return nil
                }
            })
        }
    }
}
