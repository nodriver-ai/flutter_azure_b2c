//
//  B2CError.swift
//  flutter_azure_b2c
//
//  Created by andrea on 28/07/22.
//

import Foundation

public enum B2CError: String, LocalizedError {
    
    case NO_ACCOUNT_FOUND = "Account associated to the policy is not found."

    public var errorDescription: String? { self.rawValue }
}
