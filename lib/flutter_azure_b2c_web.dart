import 'dart:async';
import 'dart:convert';
// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'package:flutter/services.dart';
import 'package:flutter_azure_b2c/web/B2CProviderWeb.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the MsalAuth plugin.
class B2CPluginWeb {
  late B2CProviderWeb _provider;
  static late final MethodChannel _channel;

  B2CPluginWeb() {
    _provider = B2CProviderWeb("", callback: _pluginListener);
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

        String configFileName = args["configFile"];
        if (!configFileName.toLowerCase().endsWith(".json"))
          configFileName = configFileName + ".json";

        _provider.init(configFileName);
        return "B2C_PLUGIN_DEFAULT";

      case 'policyTriggerInteractive':
        var args = call.arguments;

        String policyName = args["policyName"];
        List<String> scopes = <String>[];
        for (var oScope in args["scopes"]) scopes.add(oScope);

        String? loginHint;
        if (args.containsKey("loginHint")) {
          loginHint = args["loginHint"];
        }
        await _provider.policyTriggerInteractive(policyName, scopes, loginHint);

        return "B2C_PLUGIN_DEFAULT";

      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'msal_auth for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  Future<void> _pluginListener(B2COperationResult result) async {
    _channel.invokeMethod("onEvent", json.encode(result));
  }
}
