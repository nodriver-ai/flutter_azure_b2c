import 'dart:convert';
import 'dart:developer';
import 'dart:html';

import 'package:msal_js/msal_js.dart';
import 'package:flutter/services.dart' show rootBundle;

enum B2CInteractionMode { REDIRECT, POPUP }

enum B2COperationState {
  READY,
  SUCCESS,
  PASSWORD_RESET,
  USER_CANCELLED_OPERATION,
  USER_INTERACTION_REQUIRED,
  CLIENT_ERROR,
  SERVICE_ERROR
}

class B2COperationResult {
  String tag;
  String source;
  B2COperationState reason;
  Object? data;

  B2COperationResult(this.tag, this.source, this.reason, {this.data});

  Map toJson() =>
      {"tag": tag, "source": source, "reason": reason.toString().split(".")[1]};
}

typedef B2CCallback = Future<void> Function(B2COperationResult);

class B2CProviderWeb {
  PublicClientApplication? _b2cApp;
  Map<String, AuthenticationResult> _users = {};
  Configuration? _configuration;
  B2CInteractionMode _interactionMode = B2CInteractionMode.POPUP;
  String? _hostName;
  String? _tenantName;
  static String? _lastHash;

  String tag;
  B2CCallback? callback;

  static const String _B2C_PASSWORD_CHANGE = "AADB2C90118";
  static const String _B2C_USER_CANCELLED = "user_cancelled";

  static const String _INIT = "init";
  static const String _POLICY_TRIGGER_SILENTLY = "policy_trigger_silently";
  static const String _POLICY_TRIGGER_INTERACTIVE =
      "policy_trigger_interactive";
  static const String _SING_OUT = "sign_out";

  B2CProviderWeb(this.tag, {this.callback});

  Future init(String configFileName) async {
    try {
      var conf = json.decode(await rootBundle.loadString(configFileName));

      BrowserCacheLocation cache = BrowserCacheLocation.sessionStorage;
      if (conf.containsKey("cache_location")) {
        if (conf["cache_location"] == "localStorage")
          cache = BrowserCacheLocation.localStorage;
        else if (conf["cache_location"] == "memoryStorage")
          cache = BrowserCacheLocation.memoryStorage;
      }

      String clientId = conf["client_id"];
      String redirectURI = conf["redirect_uri"];

      if (conf.containsKey("interaction_mode")) {
        if (conf["interaction_mode"] == "redirect")
          _interactionMode = B2CInteractionMode.REDIRECT;
      }

      String? defaultAuthority;
      List<String> authorities = <String>[];
      if (conf.containsKey("authorities")) {
        for (Map<String, dynamic> authority in conf["authorities"]) {
          if (authority.containsKey("default") &&
              authority["default"] == true) {
            defaultAuthority = authority["authority_url"];
          }
          authorities.add(authority["authority_url"]);
        }
      }
      _setHostAndTenantFromAuthority(defaultAuthority!);

      _configuration = Configuration()
        ..cache = (CacheOptions()..cacheLocation = cache)
        ..auth = (BrowserAuthOptions()
          ..authority = defaultAuthority
          ..clientId = clientId
          ..redirectUri = redirectURI
          ..knownAuthorities = authorities);

      _b2cApp = PublicClientApplication(_configuration!);

      if (_lastHash != null && _lastHash != "#/") {
        var result = await _b2cApp!.handleRedirectFuture(_lastHash);
        if (result != null) {
          _users[result.uniqueId] = result;
        }

        _lastHash = null;
        _emitCallback(B2COperationResult(
            tag, _POLICY_TRIGGER_INTERACTIVE, B2COperationState.SUCCESS));
      }

      _emitCallback(B2COperationResult(tag, _INIT, B2COperationState.SUCCESS));
    } catch (ex) {
      _emitCallback(
          B2COperationResult(tag, _INIT, B2COperationState.CLIENT_ERROR));
    }
  }

  Future policyTriggerInteractive(
      String policyName, List<String> scopes, String? loginHint) async {
    try {
      if (_interactionMode == B2CInteractionMode.REDIRECT) {
        await _b2cApp!.acquireTokenRedirect(RedirectRequest()
          ..scopes = scopes
          ..authority = getAuthorityFromPolicyName(policyName)
          ..loginHint = loginHint);
        return; //redirect flow will restart the app
      } else {
        var result = await _b2cApp!.acquireTokenPopup(PopupRequest()
          ..scopes = scopes
          ..authority = getAuthorityFromPolicyName(policyName)
          ..loginHint = loginHint);

        _users[result.uniqueId] = result;
      }
      _emitCallback(B2COperationResult(
          tag, _POLICY_TRIGGER_INTERACTIVE, B2COperationState.SUCCESS));
    } on AuthException catch (exception) {
      if (exception.errorMessage.contains(_B2C_PASSWORD_CHANGE)) {
        _emitCallback(B2COperationResult(tag, _POLICY_TRIGGER_INTERACTIVE,
            B2COperationState.PASSWORD_RESET));
      } else {
        /* Failed to acquireToken */
        log("Authentication failed: $exception", name: tag);
        if (exception is ClientAuthException) {
          /* Exception inside MSAL, more info inside MsalError.java */
          _emitCallback(B2COperationResult(tag, _POLICY_TRIGGER_INTERACTIVE,
              B2COperationState.CLIENT_ERROR));
        } else if (exception is ServerException) {
          /* Exception when communicating with the STS, likely config issue */
          _emitCallback(B2COperationResult(tag, _POLICY_TRIGGER_INTERACTIVE,
              B2COperationState.SERVICE_ERROR));
        } else if (exception is BrowserAuthException) {
          if (exception.errorCode.contains(_B2C_USER_CANCELLED)) {
            /* User closed popup */
            _emitCallback(B2COperationResult(tag, _POLICY_TRIGGER_INTERACTIVE,
                B2COperationState.USER_CANCELLED_OPERATION));
            return;
          }
          _emitCallback(B2COperationResult(tag, _POLICY_TRIGGER_INTERACTIVE,
              B2COperationState.CLIENT_ERROR));
        }
      }
    }
  }

  Future policyTriggerSilently(
      String subject, String policyName, List<String> scopes) async {
    try {
      var user = _users[subject];
      if (user == null) {
        return;
      }
      _users[subject] = await _b2cApp!.acquireTokenSilent(SilentRequest()
        ..account = user.account
        ..scopes = scopes
        ..authority = getAuthorityFromPolicyName(policyName));
    } on AuthException catch (exception) {}
  }

  static void storeRedirectHash() {
    _lastHash = window.location.hash;
    log(_lastHash!, name: "B2CProviderWebStatic");
  }

  void _emitCallback(B2COperationResult result) {
    if (callback != null) callback!(result);
  }

  void _setHostAndTenantFromAuthority(String authority) {
    var parts = authority.split(RegExp("https://|/"));
    _hostName = parts[1];
    _tenantName = parts[2];
  }

  String getAuthorityFromPolicyName(String policyName) {
    return "https://${_hostName!}/${_tenantName!}/$policyName/";
  }
}
