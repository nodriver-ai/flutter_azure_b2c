//
//  B2CProvider.swift
//  flutter_azure_b2c
//
//  Created by andrea on 27/07/22.
//

import Foundation
import MSAL

class B2CProvider {
    
    var operationListener: IB2COperationListener
    var controller: FlutterViewController
    
    var b2cApp: MSALPublicClientApplication?
    var b2cConfig: B2CConfigurationIOS?
    var webViewParameters : MSALWebviewParameters?
    var users: [B2CUser]?
    
    var hostName: String!
    var tenantName: String!
    var defaultScopes: [String]!
    var authResults: [String: MSALResult] = [:]
    
    init(operationListener: IB2COperationListener, controller: FlutterViewController) {
        self.operationListener = operationListener
        self.controller = controller
    }
    
    /**
     * Init B2C application. It looks for existing accounts and retrieves information.
     */
    func initMSAL(tag: String, fileName: String) {
        if let path = Bundle.main.path(forResource: fileName, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                
                if let jsonResult = jsonResult as? Dictionary<String, AnyObject> {
                    let clientId = jsonResult["client_id"] as! String
                    let redirectUri = jsonResult["redirect_uri"] as! String
                    let accountMode = jsonResult["account_mode"] as! String
                    let brokerRedirectUriRegistered = jsonResult["broker_redirect_uri_registered"] as! Bool
                    var authorities: [B2CAuthority] = []
                    
                    if let authorityDicts = jsonResult["authorities"] as? [Dictionary<String, AnyObject>] {
                        authorityDicts.forEach { dictionary in
                            authorities.append(B2CAuthority(fromDictionary: dictionary))
                        }
                    }
                    
                    if let scopes = jsonResult["default_scopes"] as? [String] {
                        defaultScopes = []
                        scopes.forEach { scope in
                            defaultScopes?.append(scope)
                        }
                    }
                    
                    b2cConfig = B2CConfigurationIOS(
                        clientId: clientId,
                        redirectUri: redirectUri,
                        accountMode: accountMode,
                        brokerRedirectUriRegistered: brokerRedirectUriRegistered,
                        authorities: authorities,
                        defaultScopes: defaultScopes
                    )
                    
                    if let kAuthority = b2cConfig?.authorities.first?.authorityUrl {
                        
                        guard let authorityURL = URL(string: kAuthority) else {
                            // handle error (authority url could not be parsed)
                            return
                        }

                        let authority = try MSALB2CAuthority(url: authorityURL)
                        let msalConfiguration = MSALPublicClientApplicationConfig(
                            clientId: b2cConfig!.clientId,
                            redirectUri: b2cConfig!.redirectUri,
                            authority: authority
                        )
                        msalConfiguration.knownAuthorities = try b2cConfig!.authorities.map({ b2cAuthority in
                            let authorityURL = URL(string: b2cAuthority.authorityUrl)
                            let authority = try MSALB2CAuthority(url: authorityURL!)
                            return authority
                        })
                        
                        self.b2cApp = try MSALPublicClientApplication(configuration: msalConfiguration)
                        self.setHostAndTenantFromAuthority(tag: tag, authority: b2cApp!.configuration.authority)
                        
                        self.initWebViewParams()
                        self.loadAccounts(tag: tag, source: B2CProvider.INIT)
                    }
                    else {
                        print("[B2CProvider] No authority URLs specified in configuration JSON file.")
                        operationListener.onEvent(operationResult: B2COperationResult(
                            tag: tag,
                            source: B2CProvider.INIT,
                            reason: B2COperationState.CLIENT_ERROR,
                            data: "No authority URLs specified in configuration JSON file."
                        ))
                    }
                }
                else {
                    print("[B2CProvider] Configuration JSON could not be parsed. Please ensure JSON is valid.")
                    operationListener.onEvent(operationResult: B2COperationResult(
                        tag: tag,
                        source: B2CProvider.INIT,
                        reason: B2COperationState.CLIENT_ERROR,
                        data: "Configuration JSON could not be parsed. Please ensure JSON is valid."
                    ))
                }
            }
            catch {
                print("[B2CProvider] Unexpected error: \(error.localizedDescription)")
                operationListener.onEvent(operationResult: B2COperationResult(
                    tag: tag,
                    source: B2CProvider.INIT,
                    reason: B2COperationState.CLIENT_ERROR,
                    data: error.localizedDescription
                ))
            }
        }
    }
    
    /**
     * Runs user flow interactively.
     *
     * Once the user finishes with the flow, you will also receive an access token containing the
     * claims for the scope you passed in, which you can subsequently use to obtain your resources.
     */
    func policyTriggerInteractive(tag: String, policyName: String, scopes: [String], loginHint: String?) {
        guard let b2cApp = self.b2cApp else { return }
        guard let webViewParameters = self.webViewParameters else { return }
        
        let parameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webViewParameters)
        parameters.promptType = .login
        parameters.loginHint = loginHint
        if let authority = getAuthorityFromPolicyName(
            tag: tag,
            policyName: policyName,
            source: B2CProvider.POLICY_TRIGGER_INTERACTIVE
        ) {
            parameters.authority = authority
        }
        
        b2cApp.acquireToken(
            with: parameters,
            completionBlock: authInteractiveCallback(tag: tag)
        )
    }
    
    /**
     * Run user flow silently using stored refresh token.
     *
     * Once the operation is completed, you will also receive an access token containing the
     * claims for the scope you passed in, which you can subsequently use to obtain your resources.
     */
    func policyTriggerSilently(tag: String, subject: String, policyName: String, scopes: [String]) {
        if b2cApp == nil { return }
        
        if let selectedUser = findB2CUser(subject: subject) {
            if let authority = getAuthorityFromPolicyName(
                tag: tag,
                policyName: policyName,
                source: B2CProvider.POLICY_TRIGGER_SILENTLY
            ) {
                selectedUser.acquireTokenSilentAsync(
                    application: b2cApp!,
                    policyName: policyName,
                    authority:authority,
                    scopes: scopes,
                    callback: authSilentCallback(tag: tag)
                )
            }
        }
    }
    
    /**
     * Sign out user and erases associated tokens
     *
     */
    func signOut(tag: String, subject: String) {
        if b2cApp == nil { return }
        if let selectedUser = findB2CUser(subject: subject) {
            selectedUser.signOutAsync(application: b2cApp!) { success, err in
                if success {
                    self.loadAccounts(tag: tag, source: B2CProvider.SIGN_OUT)
                    self.authResults.removeValue(forKey: subject)
                }
                else if let error = err {
                    print("B2CProvider [\(tag)] Sign Out error: \(error.localizedDescription)")
                    self.operationListener.onEvent(operationResult: B2COperationResult(
                        tag: tag,
                        source: B2CProvider.SIGN_OUT,
                        reason: B2COperationState.CLIENT_ERROR,
                        data: error.localizedDescription
                    ))
                }
            }
        }
    }
    
    /**
     * Get provider configuration.
     *
     * @return the provider configuration
     */
    func getConfiguration() -> B2CConfigurationIOS {
        return b2cConfig!
    }
    
    /**
     * Returns a list of stored subjects. Each subject represents a stored B2C user.
     *
     * Subjects are used to identify specific users and perform operations on them.
     *
     * @return a list of stored user represented by their subjects
     */
    func getSubjects() -> [String] {
        var subjects: [String] = []
        users!.forEach { user in
            if let subject = user.subject { subjects.append(subject) }
        }
        return subjects
    }
    
    func hasSubject(subject: String) -> Bool {
        return findB2CUser(subject: subject) != nil
    }

    /**
     * Get user claims.
     * @return the user claims or null if user is not stored
     */
    func getClaims(subject: String) -> [String: Any]? {
        let subUser: B2CUser? = findB2CUser(subject: subject)
        return subUser?.claims ?? nil
    }
    
    /**
     * Get user preferred username.
     * @return the preferred username or null if user is not stored
     */
    func getUsername(subject: String) -> String? {
        let subUser: B2CUser? = findB2CUser(subject: subject)
        return subUser?.username ?? nil
    }
    
    /**
     * Get the last access token obtained for the user.
     * @return the accessToken or null if user is not logged in
     */
    func getAccessToken(subject: String) -> String? {
        if !authResults.contains(where: { key, value in key == subject }) { return nil }
        return authResults[subject]!.accessToken
    }
    
    /**
     * Get the expire date of the last access token obtained for the user.
     * @return the expire date or null if user is not logged in
     */
    func getAccessTokenExpireDate(subject: String) -> Date? {
        if !authResults.contains(where: { key, value in key == subject }) { return nil }
        return authResults[subject]!.expiresOn
    }
    
    private func findB2CUser(subject: String) -> B2CUser? {
        return users!.first { user in
            return user.subject == subject
        }
    }
    
    /**
     * Load signed-in accounts, if there are any present.
     */
    private func loadAccounts(tag: String, source: String) {
        if (b2cApp == nil) { return }
        
        let msalParameters = MSALAccountEnumerationParameters()
        msalParameters.completionBlockQueue = DispatchQueue.main
        msalParameters.returnOnlySignedInAccounts = true
        
        b2cApp!.accountsFromDevice(for: msalParameters) { accs, err in
            if let error = err {
                print("[B2CProvider] Error loading accounts. Please ensure you have added keychain " +
                      "group com.microsoft.adalcache to your project's entitlements")
                self.operationListener.onEvent(operationResult: B2COperationResult(
                    tag: tag,
                    source: source,
                    reason: B2COperationState.CLIENT_ERROR,
                    data: error.localizedDescription
                ))
                // return
            }
            if let accounts = accs {
                self.users = B2CUser.getB2CUsersFromAccountList(accounts: accounts)
                self.operationListener.onEvent(operationResult: B2COperationResult(
                    tag: tag,
                    source: source,
                    reason: B2COperationState.SUCCESS,
                    data: nil
                ))
            }
            self.operationListener.onEvent(operationResult: B2COperationResult(
                tag: tag,
                source: source,
                reason: B2COperationState.SUCCESS,
                data: nil
            ))
        }
    }
    
    private func setHostAndTenantFromAuthority(tag: String, authority: MSALAuthority) {
        let parts = authority.url.absoluteString.split(usingRegex: "https://|/")
        hostName = parts[1]
        tenantName = parts[2]
        print("B2CProvider [\(tag)] host: \(hostName ?? "nil"), tenant: \(tenantName ?? "nil")")
    }
    
    private func getAuthorityFromPolicyName(tag: String, policyName: String, source: String) -> MSALB2CAuthority? {
        do {
            let urlString = "https://\(hostName!)/\(tenantName!)/\(policyName)/"
            let authorityURL = URL(string: urlString)!
            return try MSALB2CAuthority(url: authorityURL)
        }
        catch {
            self.operationListener.onEvent(operationResult: B2COperationResult(
                tag: tag,
                source: source,
                reason: B2COperationState.CLIENT_ERROR,
                data: error.localizedDescription
            ))
            return nil
        }
    }
    
    /**
     * Callback used for interactive request.
     * If succeeds we use the access token to call the Microsoft Graph.
     * Does not check cache.
     */
    private func authInteractiveCallback(tag: String) -> MSALCompletionBlock {
        return { res, err in
            if let result = res {
                /* Successfully got a token, use it to call a protected resource - MSGraph */
                print("[B2CProvider] Successfully authenticated.")
                /* Stores in memory the access token. Note: refresh token managed by MSAL */
                if let subject = B2CUser.getSubjectFromAccount(account: result.account) {
                    self.authResults[subject] = result
                }
                // The tenant profile object on the MSALAccount response is usually nil when coming from
                // an auth flow. It is however set when loading accounts. Thus we have a fallback here
                // to use the tenantProfile object on the result itself.
                else if let subject = result.tenantProfile.identifier {
                    self.authResults[subject] = result
                }
                /* Reload account asynchronously to get the up-to-date list. */
                self.loadAccounts(tag: tag, source: B2CProvider.POLICY_TRIGGER_INTERACTIVE)
            }
            
            if let error = err {
                if error.localizedDescription.contains(B2CProvider.B2C_PASSWORD_CHANGE) {
                    self.operationListener.onEvent(operationResult: B2COperationResult(
                        tag: tag,
                        source: B2CProvider.POLICY_TRIGGER_INTERACTIVE,
                        reason: B2COperationState.PASSWORD_RESET,
                        data: error.localizedDescription
                    ))
                }
                else {
                    // TODO: We have no real way to distinguish between client and service errors in Swift
                    // using exception types. We will have to look for specific exception messages in the
                    // error message. For now we just return every error as a client error, with the full
                    // error object.
                    self.operationListener.onEvent(operationResult: B2COperationResult(
                        tag: tag,
                        source: B2CProvider.POLICY_TRIGGER_INTERACTIVE,
                        reason: B2COperationState.CLIENT_ERROR,
                        data: error.localizedDescription
                    ))
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /**
     * Callback used in for silent acquireToken calls.
     */
    private func authSilentCallback(tag: String) -> MSALCompletionBlock {
        return { res, err in
            if let result = res {
                /* Successfully got a token, use it to call a protected resource - MSGraph */
                print("[B2CProvider] Successfully authenticated.")
                /* Stores in memory the access token. Note: refresh token managed by MSAL */
                if let subject = B2CUser.getSubjectFromAccount(account: result.account) {
                    self.authResults[subject] = result
                }
                // The tenant profile object on the MSALAccount response is usually nil when coming from
                // an auth flow. It is however set when loading accounts. Thus we have a fallback here
                // to use the tenantProfile object on the result itself.
                else if let subject = result.tenantProfile.identifier {
                    self.authResults[subject] = result
                }
                /* Reload account asynchronously to get the up-to-date list. */
                self.loadAccounts(tag: tag, source: B2CProvider.POLICY_TRIGGER_SILENTLY)
            }
            
            if let error = err {
                if error.localizedDescription.contains(B2CProvider.B2C_PASSWORD_CHANGE) {
                    self.operationListener.onEvent(operationResult: B2COperationResult(
                        tag: tag,
                        source: B2CProvider.POLICY_TRIGGER_SILENTLY,
                        reason: B2COperationState.PASSWORD_RESET,
                        data: error.localizedDescription
                    ))
                }
                else {
                    // TODO: We have no real way to distinguish between client and service errors in Swift
                    // using exception types. We will have to look for specific exception messages in the
                    // error message. For now we just return every error as a client error, with the full
                    // error object.
                    self.operationListener.onEvent(operationResult: B2COperationResult(
                        tag: tag,
                        source: B2CProvider.POLICY_TRIGGER_SILENTLY,
                        reason: B2COperationState.CLIENT_ERROR,
                        data: error.localizedDescription
                    ))
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func initWebViewParams() {
        self.webViewParameters = MSALWebviewParameters(authPresentationViewController: controller)
    }
    
    static let B2C_PASSWORD_CHANGE = "AADB2C90118"
    static let INIT = "init"
    static let POLICY_TRIGGER_SILENTLY = "policy_trigger_silently"
    static let POLICY_TRIGGER_INTERACTIVE = "policy_trigger_interactive"
    static let SIGN_OUT = "sign_out"
}
