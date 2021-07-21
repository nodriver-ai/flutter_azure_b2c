// Copyright © 2021 <Luca Calacci - Nodriver S.r.l>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the “Software”), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

package com.nodriver.flutter_azure_b2c

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import com.google.gson.FieldNamingPolicy
import com.google.gson.Gson
import com.google.gson.GsonBuilder
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
    private val json = GsonBuilder()
            .setFieldNamingPolicy(FieldNamingPolicy.LOWER_CASE_WITH_UNDERSCORES).create()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_azure_b2c")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        provider = B2CProvider(pluginListener)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method == "handleRedirectFuture") {
            result.success("B2C_PLUGIN_DEFAULT")
        }
        else if (call.method == "init"){
            var args = call.arguments as Map<String, Any>
            var tag = args["tag"] as String
            var configFile = args["configFile"] as String

            provider.init(context, tag, configFile)
            result.success(null);
        }
        else if (call.method == "policyTriggerInteractive"){
            var args = call.arguments as Map<String, Any>
            var tag = args["tag"] as String
            var policyName = args["policyName"] as String
            var scopes = args["scopes"] as List<String>
            var loginHint : String? = null
            if (args.containsKey("loginHint") && args["loginHint"] != null) {
                loginHint = args["loginHint"] as String
            }

            provider.policyTriggerInteractive(context, activity, tag, policyName, scopes, loginHint)
            result.success(null)
        }
        else if (call.method == "policyTriggerSilently") {
            var args = call.arguments as Map<String, Any>
            var tag = args["tag"] as String
            var subject = args["subject"] as String
            var policyName = args["policyName"] as String
            var scopes = args["scopes"] as List<String>

            if (!provider.hasSubject(subject))
                result.error("SubjectNotExist",
                    "Unable to find stored user: $subject", null)
            else
            {
                provider.policyTriggerSilently(tag, subject, policyName, scopes)
                result.success(null)
            }
        }
        else if (call.method == "signOut") {
            var args = call.arguments as Map<String, Any>
            var tag = args["tag"] as String
            var subject = args["subject"] as String

            if (!provider.hasSubject(subject))
                result.error("SubjectNotExist",
                    "Unable to find stored user: $subject", null)
            else {
                provider.signOut(tag, subject)
                result.success(null)
            }
        }
        else if (call.method == "getConfiguration") {

            var configuration: B2CConfigurationAndroid
                = provider.getConfiguration()
            var toRet = json.toJson(configuration)
            result.success(toRet)
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
                    "subject" to subject,
                    "token" to accessToken,
                    "expire" to PluginUtilities.toIsoFormat(expireDate!!)
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
                channel.invokeMethod("onEvent", json.toJson(mapOf(
                    "tag" to operationResult.tag,
                    "source" to operationResult.source,
                    "reason" to operationResult.reason,
                    "data" to operationResult.data
                )))
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
