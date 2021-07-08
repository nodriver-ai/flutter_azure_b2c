import 'dart:async';
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
  B2CProviderWeb _provider = B2CProviderWeb();

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'flutter_azure_b2c',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = B2CPluginWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'init':
        var args = call.arguments;

        String configFileName = args["configFile"];
        if (!configFileName.toLowerCase().endsWith(".json"))
          configFileName = configFileName + ".json";

        await _provider.init(configFileName);
        return "B2C_PLUGIN_DEFAULT";

      case 'policyTriggerInteractive':
        var args = call.arguments;

        String policyName = args["policyName"];
        List<String> scopes = args["scopes"];
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

  /// Returns a [String] containing the version of the platform.
  Future<String> getPlatformVersion() {
    final version = html.window.navigator.userAgent;
    return Future.value(version);
  }
}
