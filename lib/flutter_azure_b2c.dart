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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_azure_b2c/B2CAccessToken.dart';
import 'package:flutter_azure_b2c/B2CConfiguration.dart';
import 'package:flutter_azure_b2c/B2COperationResult.dart';
import 'package:flutter_azure_b2c/B2CUserInfo.dart';
import 'package:flutter_azure_b2c/GUIDGenerator.dart';

/// Standard callback type used from the [AzureB2C] plugin.
///
/// It receives a [B2COperationResult] object.
///
/// Returns an awaitable [Future]. The [AzureB2C] plugin is responsible to
/// (async) wait for callback execution whenever an event is emitted.
typedef AzureB2CCallback = Future<void> Function(B2COperationResult);

/// Azure AD B2C protocol provider.
///
/// This static class permits to:
///   * Init a proper AzureB2C provider using a native MSAL implementation.
///   * Trigger, interactively or silently, B2C policies (user-flows) (e.g.
///   sing-up/sing-in users, reset password, or modify information)
///   * Sign-out users (i.e. erases completelly associated user's information,
///   id-token, ecc).
///
class AzureB2C {
  static const MethodChannel _channel =
      const MethodChannel('flutter_azure_b2c');

  static Map<B2COperationSource, List<AzureB2CCallback>> _callbacks = {
    B2COperationSource.INIT: <AzureB2CCallback>[],
    B2COperationSource.POLICY_TRIGGER_INTERACTIVE: <AzureB2CCallback>[],
    B2COperationSource.POLICY_TRIGGER_SILENTLY: <AzureB2CCallback>[],
    B2COperationSource.SIGN_OUT: <AzureB2CCallback>[],
  };

  /// Register a callback to manage result of [AzureB2C] asynchronous
  /// operations.
  ///
  /// The [source] argument is a [B2COperationSource] enum and set which result
  /// the callback is interested in. The [callback] is an [AzureB2CCallback].
  ///
  /// See also:
  ///   * [AzureB2C]
  ///   * [AzureB2CCallback]
  ///   * [B2COperationSource]
  ///
  /// Note:
  ///   * consider to maintain a reference to the callback itself in case in
  ///   your scenario it is necessary to unregister it.
  static void registerCallback(
      B2COperationSource source, AzureB2CCallback callback) {
    _callbacks[source]!.add(callback);
  }

  /// Unregister a callback to manage result of [AzureB2C] asynchronous
  /// operations.
  ///
  /// The [source] argument is a [B2COperationSource] enum and set which result
  /// the callback is interested in. The [callback] is an [AzureB2CCallback].
  ///
  /// See also:
  ///   * [AzureB2C]
  ///   * [AzureB2CCallback]
  ///   * [B2COperationSource]
  ///
  static void unregisterCallback(
      B2COperationSource source, AzureB2CCallback callback) {
    _callbacks[source]!.remove(callback);
  }

  /// This method permits to handle scenarios in which after the policy is
  /// triggered the application is reloaded (e.g. web if redirect mode is
  /// selected).
  ///
  /// This method should be called as soon as the application launches as some
  /// platforms (web) may erases the information state as soon as the Material
  /// app is started. A good place to call this method is the [State.initState]
  /// function of the main widget of the app.
  ///
  /// Note:
  ///   * This function must execute before the [init] function is called.
  ///
  /// See also:
  ///   * [init]
  ///
  static Future handleRedirectFuture() async {
    await _channel.invokeMethod('handleRedirectFuture');
  }

  /// Init B2C application. It look for existing accounts and retrieves
  /// information.
  ///
  /// The [configFileName] argument specifies the name of the json configuration
  /// file. Placement of the configuration file depends from the platform:
  ///   * Android: android/app/main/res/raw
  ///   * Web: web/assets
  ///
  /// This method should be called as soon as the application launches. A good
  /// place to call this method is the [State.initState] function of the main
  /// widget of the app (just after the [handleRedirectFuture] has completed).
  ///
  /// {@tool snippet}
  /// ```dart
  ///   class _MyAppState extends State<MyApp> {
  ///
  ///     @override
  ///     void initState() {
  ///       super.initState();
  ///       AzureB2C.handleRedirectFuture()
  ///           .then((_) => AzureB2C.init("auth_config"));
  ///     }
  /// ```
  /// {@end tool}
  ///
  /// The result of the method call is returned asynchronously to any
  /// [AzureB2CCallback] registered to the [B2COperationSource.INIT] topic.
  /// Possible operation states are:
  ///   * [B2COperationState.SUCCESS] if init is successful.
  ///   * [B2COperationState.CLIENT_ERROR] if an error occurred.
  ///
  /// See also:
  ///   * [handleRedirectFuture]
  ///
  static Future<String> init(String configFileName) async {
    _channel.setMethodCallHandler(_methodCallHandler);
    var tag = GUIDGen.generate();
    var args = {"tag": tag, "configFile": configFileName};

    await _channel.invokeMethod('init', args);
    return tag;
  }

  /// Runs user flow interactively.
  ///
  /// On complete, access, refresh and id tokens are stored correctly according
  /// to the platform-specific implementation. And it is possible to retrive the
  /// access token or user information (id-token) via the provided methods.
  ///
  /// The [policyName] permits to select which authority (user-flow) trigger
  /// from the ones specified in the configuration file. It must be indicated
  /// just the name of the policy without the host and tenat part. It is
  /// possible to indicate user's [scopes] for the request (i.e it is also
  /// possible to indicate default scopes in the configuration file that can be
  /// then accessed from [B2CConfiguration.defaultScopes]). A [loginHint] may be
  /// passed to directly fill the email/username/phone-number field in the
  /// policy flow.
  ///
  /// Returns a [Future] containing a tag [String]. The tag can be used to
  /// differentiate operations. In fact, every [AzureB2C] asynchronous operation
  /// return a [B2COperationResult] in which the source [tag] is indicated.
  ///
  /// The result of the method call is returned asynchronously to any
  /// [AzureB2CCallback] registered to the
  /// [B2COperationSource.POLICY_TRIGGER_INTERACTIVE] topic.
  ///
  /// Possible operation states are:
  ///   * [B2COperationState.SUCCESS] if policy trigger is successful.
  ///   * [B2COperationState.CLIENT_ERROR] if an error occurred,
  ///   * [B2COperationState.PASSWORD_RESET] if user requested a password reset,
  ///   * [B2COperationState.USER_CANCELLED_OPERATION] if the user cancelled the
  ///   operation,
  ///   * [B2COperationState.SERVICE_ERROR] if there is a configuration error
  ///   with respect to the authority setting or if the authentication provider
  ///   is down for some reasons.
  ///
  /// See also:
  ///   * [B2COperationResult]
  ///   * [AzureB2CCallback]
  ///   * [B2CConfiguration]
  ///
  static Future<String> policyTriggerInteractive(
      String policyName, List<String> scopes, String? loginHint) async {
    var tag = GUIDGen.generate();
    var args = {
      "tag": tag,
      "policyName": policyName,
      "scopes": scopes,
      "loginHint": loginHint
    };

    await _channel.invokeMethod('policyTriggerInteractive', args);
    return tag;
  }

  /// Run user flow silently using stored refresh token.
  ///
  /// On successful complete, the stored access-token will be refreshed
  /// (if necessary) and stored in the sessionStorage or localStorage
  /// respectively as specified in the configuration file.
  ///
  /// The [subject] is used to specify the user to authenticate (it corresponds
  /// to the <oid> or <sub> claims specified in the id-token of the user (i.e.
  /// subject are stored from the[AzureB2C] and can be accessed via the
  /// [getSubjects] method).
  /// The [policyName] permits to select which authority (user-flow) trigger
  /// from the ones specified in the configuration file. It must be indicated
  /// just the name of the policy without the host and tenat part. It is
  /// possible to indicate user's [scopes] for the request (i.e it is also
  /// possible to indicate default scopes in the configuration file that can be
  /// then accessed from [B2CConfiguration.defaultScopes]). A [loginHint] may be
  /// passed to directly fill the email/username/phone-number field in the
  /// policy flow.
  ///
  /// Returns a [Future] containing a tag [String]. The tag can be used to
  /// differentiate operations. In fact, every [AzureB2C] asynchronous operation
  /// return a [B2COperationResult] in which the source [tag] is indicated.
  ///
  /// The result of the method call is returned asynchronously to any
  /// [AzureB2CCallback] registered to the
  /// [B2COperationSource.POLICY_TRIGGER_SILENTLY] topic.
  ///
  /// Possible operation states are:
  ///   * [B2COperationState.SUCCESS] if successful,
  ///   * [B2COperationState.CLIENT_ERROR] if an error occurred,
  ///   * [B2COperationState.USER_INTERACTION_REQUIRED] if it the policy trigger
  ///   cannot be completed without user intervention (e.g. refresh token
  ///   expired).
  ///   * [B2COperationState.SERVICE_ERROR] if there is a configuration error
  ///   with respect to the authority setting or if the authentication provider
  ///   is down for some reasons.
  ///
  static Future<String> policyTriggerSilently(
      String subject, String policyName, List<String> scopes) async {
    var tag = GUIDGen.generate();
    var args = {
      "tag": tag,
      "policyName": policyName,
      "scopes": scopes,
      "subject": subject
    };

    await _channel.invokeMethod('policyTriggerSilently', args);
    return tag;
  }

  /// Sign out user and erases associated tokens.
  ///
  /// The [subject] is used to specify the user to authenticate (it corresponds
  /// to the <oid> or <sub> claims specified in the id-token of the user (i.e.
  /// subject are stored from the[AzureB2C] and can be accessed via the
  /// [getSubjects] method).
  ///
  /// Returns a [Future] containing a tag [String]. The tag can be used to
  /// differentiate operations. In fact, every [AzureB2C] asynchronous operation
  /// return a [B2COperationResult] in which the source [tag] is indicated.
  ///
  /// The result of the method call is returned asynchronously to any
  /// [AzureB2CCallback] registered to the [B2COperationSource.SIGN_OUT] topic.
  ///
  /// Possible operation states are:
  ///   * [B2COperationState.SUCCESS] if successful (some platform may reload
  ///   the app and so return nothing (e.g. web)),
  ///   * [B2COperationState.CLIENT_ERROR] if an error occurred,
  ///
  static Future<String> signOut(String subject) async {
    var tag = GUIDGen.generate();
    var args = {"tag": tag, "subject": subject};
    await _channel.invokeMethod('signOut', args);
    return tag;
  }

  /// Returns a list of stored subjects.
  ///
  /// Each subject represents a stored B2C user (i.e. id-token).
  /// Subjects are used to identify specific users and perform operations on.
  ///
  /// Returns a [Future] containing a [List] of stored subjects.
  ///
  static Future<List<String>?> getSubjects() async {
    print("[AzureB2C] [getSubjects] invoked...");

    var rawRes = await _channel.invokeMethod('getSubjects');

    if (rawRes != null) {
      final Map<String, dynamic>? res = json.decode(rawRes);
      print("[AzureB2C] [getSubjects] data: $res");

      if (res!.containsKey("subjects")) {
        var subjects = res["subjects"];
        var toRet = <String>[];
        for (var dSub in subjects) toRet.add(dSub);
        return toRet;
      }
    }
    return null;
  }

  /// Returns subject's stored information.
  ///
  /// Returns a [Future] containing a [B2CUserInfo] object or [null] if the
  /// subject does not exists.
  ///
  /// See also:
  ///   * [B2CUserInfo]
  ///
  static Future<B2CUserInfo?> getUserInfo(String subject) async {
    print("[AzureB2C] [getUserInfo] invoked...");

    var args = {"subject": subject};
    var rawRes = await _channel.invokeMethod('getSubjectInfo', args);

    if (rawRes != null) {
      final Map<String, dynamic>? res = json.decode(rawRes);
      print("[AzureB2C] [getUserInfo] data: $res");
      return B2CUserInfo.fromJson(subject, res!);
    } else
      return null;
  }

  /// Returns subject's stored access-token.
  ///
  /// Returns a [Future] containing a [B2CAccessToken] object or [null] if the
  /// subject does not exists.
  ///
  /// See also:
  ///   * [B2CAccessToken]
  ///
  static Future<B2CAccessToken?> getAccessToken(String subject) async {
    print("[AzureB2C] [getB2CAccessToken] invoked...");
    var args = {"subject": subject};
    var rawRes = await _channel.invokeMethod('getAccessToken', args);

    if (rawRes != null) {
      final Map<String, dynamic>? res = json.decode(rawRes);
      print("[AzureB2C] [getB2CAccessToken] data: $res");
      return B2CAccessToken.fromJson(res!);
    } else
      return null;
  }

  /// Get the provider configuration (i.e. a compact representation, NOT the
  /// full MSAL configuration).
  ///
  /// Returns a [Future] containing a [B2CConfiguration] object or [null] if
  /// the provider is not configured yet.
  ///
  /// See also:
  ///   * [B2CConfiguration]
  ///
  static Future<B2CConfiguration?> getConfiguration() async {
    print("[AzureB2C] [getConfiguration] invoked...");
    var rawRes = await _channel.invokeMethod('getConfiguration');
    if (rawRes != null) {
      final Map<String, dynamic>? res = json.decode(rawRes);
      print("[AzureB2C] [getConfiguration] data: $res");
      return B2CConfiguration.fromJson(res!);
    } else
      return null;
  }

  static Future<void> _methodCallHandler(MethodCall call) async {
    print("[AzureB2C] Callback received...");
    var result = B2COperationResult.fromJson(json.decode(call.arguments));
    print("[AzureB2C] Callback data: ${json.encode(result)}");

    for (var callback in _callbacks[result.source]!) {
      await callback(result);
    }
  }
}
