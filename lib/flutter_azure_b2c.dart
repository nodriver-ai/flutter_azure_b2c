import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_azure_b2c/B2CAccessToken.dart';
import 'package:flutter_azure_b2c/B2CConfiguration.dart';
import 'package:flutter_azure_b2c/B2COperationResult.dart';
import 'package:flutter_azure_b2c/B2CUserInfo.dart';

typedef AzureB2CCallback = Future<void> Function(B2COperationState);

class AzureB2C {
  static const MethodChannel _channel =
      const MethodChannel('flutter_azure_b2c');

  static Map<B2COperationSource, List<AzureB2CCallback>> _callbacks = {
    B2COperationSource.INIT: <AzureB2CCallback>[],
    B2COperationSource.POLICY_TRIGGER_INTERACTIVE: <AzureB2CCallback>[],
    B2COperationSource.POLICY_TRIGGER_SILENTLY: <AzureB2CCallback>[],
    B2COperationSource.SING_OUT: <AzureB2CCallback>[],
  };

  static void registerCallback(
      B2COperationSource source, AzureB2CCallback callback) {
    _callbacks[source]!.add(callback);
  }

  static void unregisterCallback(
      B2COperationSource source, AzureB2CCallback callback) {
    _callbacks[source]!.remove(callback);
  }

  static Future handleRedirectFuture() async {
    await _channel.invokeMethod('handleRedirectFuture');
  }

  static Future<String?> init(String configFileName) async {
    _channel.setMethodCallHandler(_methodCallHandler);
    var args = {"configFile": configFileName};

    final String? res = await _channel.invokeMethod('init', args);
    return res;
  }

  static Future<String?> policyTriggerInteractive(
      String policyName, List<String> scopes, String? loginHint) async {
    var args = {
      "policyName": policyName,
      "scopes": scopes,
      "loginHint": loginHint
    };

    final String? res =
        await _channel.invokeMethod('policyTriggerInteractive', args);
    return res;
  }

  static Future<String?> policyTriggerSilently(
      String policyName, List<String> scopes, String subject) async {
    var args = {"policyName": policyName, "scopes": scopes, "subject": subject};

    final String? res =
        await _channel.invokeMethod('policyTriggerSilently', args);
    return res;
  }

  static Future<String?> signOut(String subject) async {
    var args = {"subject": subject};
    final String? res = await _channel.invokeMethod('signOut', args);
    return res;
  }

  static Future<List<String>?> getSubjects() async {
    final Map<String, dynamic>? res =
        json.decode(await _channel.invokeMethod('getSubjects'));
    print(res);
    if (res != null && res.containsKey("subjects")) {
      var subjects = res["subjects"];
      var toRet = <String>[];
      for (var dSub in subjects) toRet.add(dSub);
      return toRet;
    }
    return null;
  }

  static Future<B2CUserInfo?> getB2CUserInfo(String subject) async {
    var args = {"subject": subject};
    final Map<String, dynamic>? res =
        json.decode(await _channel.invokeMethod('getSubjectInfo', args));
    print(res);
    if (res != null)
      return B2CUserInfo.fromJson(subject, res);
    else
      return null;
  }

  static Future<B2CAccessToken?> getB2CAccessToken(String subject) async {
    var args = {"subject": subject};
    final Map<String, dynamic>? res =
        json.decode(await _channel.invokeMethod('getAccessToken', args));
    if (res != null)
      return B2CAccessToken.fromJson(res);
    else
      return null;
  }

  static Future<B2CConfiguration?> getConfiguration() async {
    return B2CConfiguration.fromJson(
        json.decode(await _channel.invokeMethod('getConfiguration')));
  }

  static Future<void> _methodCallHandler(MethodCall call) async {
    print(call.arguments);
    var result = B2COperationResult.fromJson(json.decode(call.arguments));
    for (var callback in _callbacks[result.source]!) {
      await callback(result.reason);
    }
  }
}
