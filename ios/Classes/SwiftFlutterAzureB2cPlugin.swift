import Flutter
import UIKit
import MSAL

public class SwiftFlutterAzureB2cPlugin: NSObject, FlutterPlugin, IB2COperationListener {
    var controller: FlutterViewController!
    var provider: B2CProvider!
    var channel: FlutterMethodChannel!
  
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_azure_b2c", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterAzureB2cPlugin()
        instance.controller = ((UIApplication.shared.delegate?.window??.rootViewController)! as! FlutterViewController)
        instance.provider = B2CProvider(operationListener: instance, controller: instance.controller)
        instance.channel = channel
        registrar.addApplicationDelegate(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "handleRedirectFuture" {
            result("B2C_PLUGIN_DEFAULT")
        }
        
        else if call.method == "init" {
            let args = call.arguments as! [String: AnyObject]
            let configFile = args["configFile"] as! String
            let tag = args["tag"] as! String
            provider.initMSAL(tag: tag, fileName: configFile)
            result(nil)
        }
        
        else if call.method == "policyTriggerInteractive" {
            let args = call.arguments as! [String: AnyObject]
            let policyName = args["policyName"] as! String
            let scopes = args["scopes"] as! [String]
            let tag = args["tag"] as! String
            var loginHint: String? = nil
            
            if (args.contains(where: { key, value in return key == "loginHint" }) && args["loginHint"] != nil) {
                loginHint = args["loginHint"] as? String
            }
            
            provider.policyTriggerInteractive(tag: tag, policyName: policyName, scopes: scopes, loginHint: loginHint)
            result(nil)
        }
        
        else if call.method == "policyTriggerSilently" {
            let args = call.arguments as! [String: AnyObject]
            let subject = args["subject"] as! String
            let tag = args["tag"] as! String
            let policyName = args["policyName"] as! String
            let scopes = args["scopes"] as! [String]
            
            if provider.hasSubject(subject: subject) {
                provider.policyTriggerSilently(tag: tag, subject: subject, policyName: policyName, scopes: scopes)
                result(nil)
            }
            else {
                result("SubjectNotExist: Unable to find stored user: \(subject)")
            }
        }
        
        else if call.method == "signOut" {
            let args = call.arguments as! [String: AnyObject]
            let subject = args["subject"] as! String
            let tag = args["tag"] as! String
            
            if provider.hasSubject(subject: subject) {
                provider.signOut(tag: tag, subject: subject)
                result(nil)
            }
            else {
                result("SubjectNotExist: Unable to find stored user: $\(subject)")
            }
        }
        
        else if call.method == "getConfiguration" {
            let configuration: B2CConfigurationIOS = provider.getConfiguration()
            result(configuration.toJson())
        }
        
        else if call.method == "getSubjects" {
            let subjects = provider.getSubjects()
            var decoded: String? = nil
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: ["subjects": subjects], options: [])
                decoded = String(data: jsonData, encoding: .utf8)
            } catch {
                print(error.localizedDescription)
            }
            result(decoded)
        }
        
        else if call.method == "hasSubject" {
            let args = call.arguments as! [String: Any]
            let subject = args["subject"] as! String
            result(provider.hasSubject(subject: subject))
        }
        
        else if call.method == "getSubjectInfo" {
            let args = call.arguments as! [String: Any]
            let subject = args["subject"] as! String
            
            let usernm = provider.getUsername(subject: subject)
            let clms = provider.getClaims(subject: subject)
            
            if let username = usernm, let claims = clms {
                var decoded: String? = nil
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: [
                        "username": username,
                        "claims": claims
                    ], options: [])
                    decoded = String(data: jsonData, encoding: .utf8)
                } catch {
                    print(error.localizedDescription)
                }
                result(decoded)
            }
            else {
                result("SubjectNotExist: Unable to find stored user: \(subject)")
            }
        }
        
        else if call.method == "getAccessToken" {
            let args = call.arguments as! [String: Any]
            let subject = args["subject"] as! String
            
            let accessToken = provider.getAccessToken(subject: subject)
            let expireDate = provider.getAccessTokenExpireDate(subject: subject)
            
            if let token = accessToken, let expiry = expireDate {
                var decoded: String? = nil
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: [
                        "subject": subject,
                        "token": token,
                        "expire": PluginUtilities.toIsoFormat(date: expiry)
                    ], options: [])
                    decoded = String(data: jsonData, encoding: .utf8)
                } catch {
                    print(error.localizedDescription)
                }
                result(decoded)
            }
            else {
                result("SubjectNotExist|SubjectNotAuthenticated: Unable to find authenticated user: \(subject)")
            }
        }
        else {
            result("NotImplemented")
        }
    }
    
    /**
     * B2C provider listener.
     */
    func onEvent(operationResult: B2COperationResult) {
        channel.invokeMethod("onEvent", arguments: operationResult.toJson())
    }
    
    /**
     * Intercepts redirect URIs which match the application's registered URI schemes.
     */
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String)
    }
}
