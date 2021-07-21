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
import 'package:flutter_azure_b2c/web/B2CProviderWeb.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'B2COperationResult.dart';

/// A web implementation of the AzureB2C plugin. It implements the comm
/// protocol define in [AzureB2C] using the [B2CProviderWeb] provider.
///
/// For more information, see:
///   * [B2CProviderWeb]
///
/// Note: No need to never istantiate this class as the flutter plugin mechanism
/// will automatically istantiate one in case the app is compiled for the web
/// platform.
class B2CPluginWeb {
  late B2CProviderWeb _provider;
  static late final MethodChannel _channel;

  /// Default construtor. Exclusevely used from the plugin itself.
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

  /// Register a callback channel to trigger back to flutter asynchronous
  /// results generated from the native implementation.
  Future<void> _pluginListener(B2COperationResult result) async {
    _channel.invokeMethod("onEvent", json.encode(result));
  }
}
