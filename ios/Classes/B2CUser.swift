//
//  B2CUser.swift
//  flutter_azure_b2c
//
//  Created by andrea on 28/07/22.
//

import Foundation
import MSAL

class B2CUser {
    
    /**
     * List of account objects that are associated to this B2C user.
     */
    var accounts: [MSALAccount] = []
    
    var displayName: String? {
        get {
            if accounts.isEmpty { return nil }
            return B2CUser.getB2CDisplayNameFromAccount(account: accounts.first!)
        }
    }
    
    var subject: String? {
        get {
            if accounts.isEmpty { return nil }
            return B2CUser.getSubjectFromAccount(account: accounts.first!)
        }
    }
    
    var username: String? {
        get {
            if accounts.isEmpty { return nil }
            return accounts.first!.username
        }
    }
    
    var claims: [String: Any]? {
        get {
            if accounts.isEmpty { return nil }
            // NOTE: It looks like the accountClaims array property on the MSALAccount object
            // comes back empty. Instead the first tenantProfile object on a given account contains
            // the expected claims array.
            return accounts.first!.tenantProfiles?.first?.claims ?? nil
        }
    }
    
    /**
     * Acquires a token without interrupting the user.
     */
    func acquireTokenSilentAsync(application: MSALPublicClientApplication,
                                 policyName: String,
                                 authority: MSALB2CAuthority?,
                                 scopes: [String]?,
                                 callback: @escaping MSALCompletionBlock) {
        var policyFound = false
        accounts.forEach { account in
            if policyName == B2CUser.getB2CPolicyNameFromAccount(account: account) {
                let parameters = MSALSilentTokenParameters(scopes: scopes ?? [], account: account)
                parameters.authority = authority
                application.acquireTokenSilent(with: parameters, completionBlock: callback)
                policyFound = true
                return
            }
        }
        if !policyFound { callback(nil, B2CError.NO_ACCOUNT_FOUND) }
    }
    
    /**
     * Signs the user out of your application.
     */
    func signOutAsync(application: MSALPublicClientApplication, callback: @escaping MSALSignoutCompletionBlock) {
        DispatchQueue.main.async {
            do {
                try self.accounts.forEach { account in
                    try application.remove(account)
                }
                self.accounts.removeAll()
                callback(true, nil)
            }
            catch {
                callback(true, error)
            }
        }
    }
}

extension B2CUser {
    
    /**
     * A factory method for generating B2C users based on the given IAccount list.
     */
    static func getB2CUsersFromAccountList(accounts: [MSALAccount]) -> [B2CUser] {
        var b2CUserHashMap: [String?: B2CUser] = [:]
        accounts.forEach { account in
            /**
             * NOTE: Because B2C treats each policy as a separate authority, the access tokens, refresh tokens, and id tokens returned from each policy are considered logically separate entities.
             * In practical terms, this means that each policy returns a separate MSALAccount object whose tokens cannot be used to invoke other policies.
             *
             * You can use the 'Subject' claim to identify that those accounts belong to the same user.
             */
            let subject = getSubjectFromAccount(account: account)
            var user = b2CUserHashMap[subject]
            if (user == nil) {
                user = B2CUser()
                b2CUserHashMap[subject] = user
            }
            user?.accounts.append(account)
        }
        var users: [B2CUser] = []
        users.append(contentsOf: b2CUserHashMap.values)
        return users
    }
    
    /**
     * Get name of the policy associated with the given B2C account.
     * See https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-reference-tokens for more info.
     */
    static func getB2CPolicyNameFromAccount(account: MSALAccount) -> String? {
        if let claims = account.tenantProfiles?.first?.claims {
            if let policy = claims["tfp"] {
                return policy as? String
            }
            if let policy = claims["acr"] {
                return policy as? String
            }
        }
        return nil
    }
    
    /**
     * Get subject of the given B2C account.
     *
     * Subject is the principal about which the token asserts information, such as the user of an application.
     * See https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-reference-tokens for more info.
     */
    static func getSubjectFromAccount(account: MSALAccount) -> String? {
        if let claims = account.tenantProfiles?.first?.claims {
            if let displayName = claims[IDToken.SUBJECT] {
                return displayName as? String
            }
        }
        return nil
    }
    
    /**
     * Get a displayable name of the given B2C account.
     * This claim is optional.
     */
    static func getB2CDisplayNameFromAccount(account: MSALAccount) -> String? {
        if let claims = account.accountClaims {
            if let displayName = claims[IDToken.NAME] {
                return displayName as? String
            }
        }
        return nil
    }
}
