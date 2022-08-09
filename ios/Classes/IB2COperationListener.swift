//
//  IB2COperationListener.swift
//  flutter_azure_b2c
//
//  Created by andrea on 27/07/22.
//

import Foundation

enum B2COperationState {
    case READY
    case SUCCESS
    case PASSWORD_RESET
    case USER_CANCELLED_OPERATION
    case USER_INTERACTION_REQUIRED
    case CLIENT_ERROR
    case SERVICE_ERROR
}

extension B2COperationState {
    func toString() -> String {
        switch self {
        case .READY: return "READY"
        case .SUCCESS: return "SUCCESS"
        case .PASSWORD_RESET: return "PASSWORD_RESET"
        case .USER_CANCELLED_OPERATION: return "USER_CANCELLED_OPERATION"
        case .USER_INTERACTION_REQUIRED: return "USER_INTERACTION_REQUIRED"
        case .CLIENT_ERROR: return "CLIENT_ERROR"
        case .SERVICE_ERROR: return "SERVICE_ERROR"
        }
    }
}

class B2COperationResult {
    
    var tag: String
    var source: String
    var reason: B2COperationState
    var data: Any? = nil
    
    init(tag: String, source: String, reason: B2COperationState, data: Any?) {
        self.tag = tag
        self.source = source
        self.reason = reason
        self.data = data
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "source": source,
            "reason": reason.toString(),
            "data": data ?? "",
            "tag": tag
        ]
    }
    
    func toJson() -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: toDictionary(), options: [])
            let decoded = String(data: jsonData, encoding: .utf8)
            return decoded;
        } catch {
            print(error.localizedDescription)
        }
        return nil;
    }
}

protocol IB2COperationListener {
    func onEvent(operationResult: B2COperationResult) -> Void
}
