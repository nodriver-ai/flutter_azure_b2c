import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter_azure_b2c/B2CAccessToken.dart';
import 'package:flutter_azure_b2c/B2CConfiguration.dart';
import 'package:flutter_azure_b2c/B2COperationResult.dart';
import 'package:flutter_azure_b2c/B2CUserInfo.dart';
import 'package:flutter_azure_b2c/GUIDGenerator.dart';

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

  static Future<String> init(String configFileName) async {
    _channel.setMethodCallHandler(_methodCallHandler);
    var tag = GUIDGen.generate();
    var args = {"tag": tag, "configFile": configFileName};

    await _channel.invokeMethod('init', args);
    return tag;
  }

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

  static Future<String> policyTriggerSilently(
      String policyName, List<String> scopes, String subject) async {
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

  static Future<String> signOut(String subject) async {
    var tag = GUIDGen.generate();
    var args = {"tag": tag, "subject": subject};
    await _channel.invokeMethod('signOut', args);
    return tag;
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
    print("[AzureB2C] [getB2CAccessToken] invoked...");
    var args = {"subject": subject};
    final Map<String, dynamic>? res =
        json.decode(await _channel.invokeMethod('getAccessToken', args));
    if (res != null) {
      print("[AzureB2C] [getB2CAccessToken] data: $res");
      return B2CAccessToken.fromJson(res);
    } else
      return null;
  }

  static Future<B2CConfiguration?> getConfiguration() async {
    print("[AzureB2C] [getConfiguration] invoked...");
    final Map<String, dynamic>? res =
        json.decode(await _channel.invokeMethod('getConfiguration'));
    if (res != null) {
      print("[AzureB2C] [getConfiguration] data: $res");
      return B2CConfiguration.fromJson(res);
    } else
      return null;
  }

  static Future<void> _methodCallHandler(MethodCall call) async {
    print("[AzureB2C] Callback received...");
    var result = B2COperationResult.fromJson(json.decode(call.arguments));
    print("[AzureB2C] Callback data: ${json.encode(result)}");

    for (var callback in _callbacks[result.source]!) {
      await callback(result.reason);
    }
  }
}
