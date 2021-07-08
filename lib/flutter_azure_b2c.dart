import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_azure_b2c/B2CAccessToken.dart';
import 'package:flutter_azure_b2c/B2CUserInfo.dart';

class AzureB2C {
  static const MethodChannel _channel =
      const MethodChannel('flutter_azure_b2c');

  static Future<String?> init() async {
    _channel.setMethodCallHandler(_methodCallHandler);
    var args = {"configFile": "auth_config"};

    final String? res = await _channel.invokeMethod('init', args);
    return res;
  }

  static Future<String?> policyTriggerInteractive() async {
    var args = {
      "policyName": "B2C_1_Irreo_sign_up_in",
      "scopes": <String>[
        "https://nodriverservices.onmicrosoft.com/9c26e9a7-4bcf-4fb0-9582-3552a70219fe/Irreo.APIv2.Access"
      ],
      "loginHint": "luca.calacci@gmail.com"
    };

    final String? res =
        await _channel.invokeMethod('policyTriggerInteractive', args);
    return res;
  }

  static Future<String?> policyTriggerSilently(String subject) async {
    var args = {
      "policyName": "B2C_1_Irreo_sign_up_in",
      "scopes": <String>[
        "https://nodriverservices.onmicrosoft.com/9c26e9a7-4bcf-4fb0-9582-3552a70219fe/Irreo.APIv2.Access"
      ],
      "subject": subject
    };

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
      return B2CAccessToken.fromJson(subject, res);
    else
      return null;
  }

  static Future<void> _methodCallHandler(MethodCall call) async {
    print(call.arguments);
  }
}
