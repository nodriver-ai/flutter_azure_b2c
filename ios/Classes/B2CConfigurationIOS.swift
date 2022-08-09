//
//  B2CConfigurationIOS.swift
//  flutter_azure_b2c
//
//  Created by andrea on 27/07/22.
//

import Foundation

class B2CAuthority {
    
    var authorityUrl: String
    var authorityType: String
    var isDefault: Bool
    
    init(authorityUrl: String, authorityType: String, isDefault: Bool) {
        self.authorityUrl = authorityUrl
        self.authorityType = authorityType
        self.isDefault = isDefault
    }
    
    init(fromDictionary dictionary: Dictionary<String, AnyObject>) {
        self.authorityUrl = dictionary["authority_url"] as! String
        self.authorityType = dictionary["type"] as! String
        self.isDefault = dictionary["default"] != nil ? dictionary["default"] as! Bool : false
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "authority_url": authorityUrl,
            "type": authorityType,
            "default": isDefault
        ]
    }
}

class B2CConfigurationIOS {
    
    var clientId: String
    var redirectUri: String
    var accountMode: String
    var brokerRedirectUriRegistered: Bool
    var authorities: [B2CAuthority]
    var defaultScopes: [String]?
    
    init(clientId: String, redirectUri: String, accountMode: String = "MULTI",
         brokerRedirectUriRegistered: Bool = false, authorities: [B2CAuthority],
         defaultScopes: [String]?) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.accountMode = accountMode
        self.brokerRedirectUriRegistered = brokerRedirectUriRegistered
        self.authorities = authorities
        self.defaultScopes = defaultScopes
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "client_id": clientId,
            "redirect_uri": redirectUri,
            "authorities": authorities.map({ authority in
                return authority.toDictionary()
            }),
            "account_mode": accountMode,
            "broker_redirect_uri_registered": brokerRedirectUriRegistered,
            "default_scopes": defaultScopes ?? []
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
