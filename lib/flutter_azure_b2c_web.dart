import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_azure_b2c/web/B2CProviderWeb.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'B2COperationResult.dart';

/// A web implementation of the MsalAuth plugin.
class B2CPluginWeb {
  late B2CProviderWeb _provider;
  static late final MethodChannel _channel;

  B2CPluginWeb() {
    _provider = B2CProviderWeb(callback: _pluginListener);
  }

  static void registerWith(Registrar registrar) {
    _channel = MethodChannel(
      'flutter_azure_b2c',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = B2CPluginWeb();
    _channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'handleRedirectFuture':
        B2CProviderWeb.storeRedirectHash();
        return "B2C_PLUGIN_DEFAULT";
      case 'init':
        var args = call.arguments;

        String tag = args["tag"];
        String configFileName = args["configFile"];
        if (!configFileName.toLowerCase().endsWith(".json"))
          configFileName = configFileName + ".json";

        _provider.init(tag, configFileName);
        return;

      case 'policyTriggerInteractive':
        var args = call.arguments;

        String tag = args["tag"];
        String policyName = args["policyName"];
        List<String> scopes = <String>[];
        for (var oScope in args["scopes"]) scopes.add(oScope);

        String? loginHint;
        if (args.containsKey("loginHint")) {
          loginHint = args["loginHint"];
        }
        await _provider.policyTriggerInteractive(
            tag, policyName, scopes, loginHint);

        return;

      case 'policyTriggerSilently':
        var args = call.arguments;

        String tag = args["tag"];
        String subject = args["subject"];
        String policyName = args["policyName"];
        List<String> scopes = <String>[];
        for (var oScope in args["scopes"]) scopes.add(oScope);

        await _provider.policyTriggerSilently(tag, subject, policyName, scopes);

        return;

      case 'signOut':
        var args = call.arguments;

        String tag = args["tag"];
        String subject = args["subject"];

        await _provider.signOut(tag, subject);

        return;

      case 'getSubjects':
        var res = _provider.getSubjects();
        return json.encode({"subjects": res});

      case 'getSubjectInfo':
        var args = call.arguments;
        String subject = args["subject"];

        var res = _provider.getSubjectInfo(subject);
        if (res != null) {
          return json.encode(res);
        }
        throw Exception("Subject not exists");

      case 'getAccessToken':
        var args = call.arguments;
        String subject = args["subject"];

        var res = _provider.getAccessToken(subject);
        if (res != null) {
          return json.encode(res);
        }
        throw Exception("Subject or AccessToken not exists");

      case 'getConfiguration':
        var res = _provider.getConfiguration();
        if (res != null) {
          return json.encode(res);
        }
        throw Exception("Configuration not valid");
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'flutter_azure_b2c for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  Future<void> _pluginListener(B2COperationResult result) async {
    _channel.invokeMethod("onEvent", json.encode(result));
  }
}
