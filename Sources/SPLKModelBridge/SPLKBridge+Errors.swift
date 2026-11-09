//
//  SPLKBridge+Errors.swift
//  SPLKModelBridge
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SHARED

import Foundation
import SPLKProtocol
import SPLKServer

extension SPLKBridge {

    public enum Reason {
        public static let objectDeallocated = "object_deallocated"
        public static let valueTypeInvalid = "value_type_invalid"
        public static let exception = "exception"
        public static let inner = "inner"
        public static let error = "error"
        public static let appInBackground = "app_in_background"
    }

    public static func statusError(_ error: NSError) -> SPLKStatusError {
        let title = error.userInfo[NSLocalizedDescriptionKey] as? String ?? ""
        let detail = error.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String ?? ""
        guard error.domain == SPLKErrorDomain else {
            return SPLKStatusError(.internal, reason: Reason.error, title: title, detail: detail)
        }
        switch error.code {
        case SPLKErrCode_ObjectNotFound:
            return SPLKStatusError(.notFound, reason: Reason.objectDeallocated, title: title, detail: detail)
        case SPLKErrCode_ModifyValueTypeInvalid:
            return SPLKStatusError(.invalidArgument, reason: Reason.valueTypeInvalid, title: title, detail: detail)
        case SPLKErrCode_Exception:
            return SPLKStatusError(.internal, reason: Reason.exception, title: title, detail: detail)
        case SPLKErrCode_Inner:
            return SPLKStatusError(.internal, reason: Reason.inner, title: title, detail: detail)
        default:
            return SPLKStatusError(.internal, reason: Reason.error, title: title, detail: detail)
        }
    }
}

#endif
