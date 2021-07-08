package com.nodriver.flutter_azure_b2c

import android.app.Activity
import android.content.Context
import androidx.annotation.NonNull
import com.google.gson.Gson
import com.microsoft.identity.client.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


/** MsalAuthPlugin */
class B2CPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel : MethodChannel
    private lateinit var context: Context
    private lateinit var activity: Activity
    private lateinit var provider: B2CProvider
    private val json = Gson()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_azure_b2c")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        provider = B2CProvider("B2C_PLUGIN_DEFAULT", pluginListener)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("android")
        }
        else if (call.method == "init"){
            var args = call.arguments as Map<String, Any>
            var configFile = args["configFile"] as String

            provider.init(context, configFile)
            result.success("B2C_PLUGIN_DEFAULT");
        }
        else if (call.method == "policyTriggerInteractive"){
            var args = call.arguments as Map<String, Any>
            var policyName = args["policyName"] as String
            var scopes = args["scopes"] as List<String>
            var loginHint : String? = null
            if (args.containsKey("loginHint")) {
                loginHint = args["loginHint"] as String
            }

            provider.policyTriggerInteractive(context, activity, policyName, scopes, loginHint)
            result.success("B2C_PLUGIN_DEFAULT")
        }
        else if (call.method == "policyTriggerSilently") {
            var args = call.arguments as Map<String, Any>
            var subject = args["subject"] as String
            var policyName = args["policyName"] as String
            var scopes = args["scopes"] as List<String>

            if (!provider.hasSubject(subject))
                result.error("SubjectNotExist",
                    "Unable to find stored user: $subject", null)
            else
            {
                provider.policyTriggerSilently(subject, policyName, scopes)
                result.success("B2C_PLUGIN_DEFAULT")
            }
        }
        else if (call.method == "signOut") {
            var args = call.arguments as Map<String, Any>
            var subject = args["subject"] as String

            if (!provider.hasSubject(subject))
                result.error("SubjectNotExist",
                    "Unable to find stored user: $subject", null)
            else {
                provider.signOut(subject)
                result.success("B2C_PLUGIN_DEFAULT")
            }
        }
        else if (call.method == "getConfiguration") {

            var configuration: PublicClientApplicationConfiguration
                = provider.getConfiguration()

            result.success(json.toJson(configuration))
        }
        else if (call.method == "getSubjects") {
            var subjects = provider.getSubjects()

            result.success(json.toJson(mapOf(
                "subjects" to subjects
            )))
        }
        else if (call.method == "hasSubject") {
            var args = call.arguments as Map<String, Any>
            var subject = args["subject"] as String

            result.success(provider.hasSubject(subject))
        }
        else if (call.method == "getSubjectInfo") {
            var args = call.arguments as Map<String, Any>
            var subject = args["subject"] as String

            var username = provider.getUsername(subject)
            var claims = provider.getClaims(subject)

            if (username == null && claims == null)
                result.error(
                    "SubjectNotExist",
                    "Unable to find stored user: $subject", null)
            else
                result.success(json.toJson(mapOf(
                    "username" to username,
                    "claims" to claims
            )))
        }
        else if (call.method == "getAccessToken") {
            var args = call.arguments as Map<String, Any>
            var subject = args["subject"] as String

            var accessToken = provider.getAccessToken(subject)
            var expireDate = provider.getAccessTokenExpireDate(subject)

            if (accessToken == null)
                result.error(
                    "SubjectNotExist|SubjectNotAuthenticated",
                    "Unable to find authenticated user: $subject", null)
            else
                result.success(json.toJson(mapOf(
                    "token" to accessToken,
                    "expireOn" to PluginUtilities.toIsoFormat(expireDate!!)
                )))
        }
        else {
            result.notImplemented()
        }
    }


    /**
    * B2C provider listener.
    */
    private val pluginListener: IB2COperationListener
        private get() = object : IB2COperationListener {
            override fun onEvent(operationResult: B2COperationResult) {
//                var result : Map<String, String> = mapOf(
//                    "tag" to operationResult.tag,
//                    "source" to operationResult.source,
//                    "reason" to operationResult.reason.toString()
//                )
                var result: Map<String, Any> = operationResult.serializeToMap()
                channel.invokeMethod("onEvent", result)
            }
        }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onDetachedFromActivity() {
        TODO("Not yet implemented")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        TODO("Not yet implemented")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity;
    }

    override fun onDetachedFromActivityForConfigChanges() {
        TODO("Not yet implemented")
    }
}
