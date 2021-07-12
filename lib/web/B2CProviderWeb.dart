import 'dart:convert';
import 'dart:developer';
import 'dart:html';

import 'package:flutter_azure_b2c/B2CAccessToken.dart';
import 'package:flutter_azure_b2c/B2CUserInfo.dart';
import 'package:intl/intl.dart';
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
  Map<String, AccountInfo> _users = {};
  Map<String, B2CAccessToken> _accessTokens = {};
  Configuration? _configuration;
  B2CInteractionMode _interactionMode = B2CInteractionMode.POPUP;
  String? _hostName;
  String? _tenantName;
  static String? _lastHash;

  String tag;
  B2CCallback? callback;

  static const String _B2C_PASSWORD_CHANGE = "AADB2C90118";
  static const String _B2C_USER_CANCELLED = "user_cancelled";
  static const String _B2C_PLUGIN_LAST_ACCESS = "b2c_plugin_last_access";

  static const String _INIT = "init";
  static const String _POLICY_TRIGGER_SILENTLY = "policy_trigger_silently";
  static const String _POLICY_TRIGGER_INTERACTIVE =
      "policy_trigger_interactive";
  static const String _SING_OUT = "sign_out";

  static final DateFormat _format = DateFormat("E MMM dd yyyy hh:mm:ss Z");

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
      _loadAllAccounts();

      if (window.localStorage.containsKey(_B2C_PLUGIN_LAST_ACCESS)) {
        try {
          B2CAccessToken lastAccessToken = B2CAccessToken.fromJson(
              json.decode(window.localStorage[_B2C_PLUGIN_LAST_ACCESS]!));
          if (_users.containsKey(lastAccessToken.subject)) {
            _accessTokens[lastAccessToken.subject] = lastAccessToken;
          }
        } catch (exception) {
          log("SessionStorage temp access token parse failed: $exception",
              name: tag);
        } finally {
          window.localStorage.remove(_B2C_PLUGIN_LAST_ACCESS);
        }
      }

      if (_lastHash != null && _lastHash != "#/") {
        var result = await _b2cApp!.handleRedirectFuture(_lastHash);
        if (result != null) {
          _users[result.uniqueId] = result.account!;
          _accessTokens[result.uniqueId] = _accessTokenFromAuthResult(result);

          // MSAL seams to reload the page after the handleRedirectFuture is
          // completed, so we temporarly store the access token in the session
          // storage to use it later, e.g. see code before.
          window.localStorage[_B2C_PLUGIN_LAST_ACCESS] =
              json.encode(_accessTokenFromAuthResult(result));
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

        _users[result.uniqueId] = result.account!;
        _accessTokens[result.uniqueId] = _accessTokenFromAuthResult(result);
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
        _emitCallback(B2COperationResult(
            tag, _POLICY_TRIGGER_SILENTLY, B2COperationState.CLIENT_ERROR));
        return;
      }
      var result = await _b2cApp!.acquireTokenSilent(SilentRequest()
        ..account = user
        ..scopes = scopes
        ..authority = getAuthorityFromPolicyName(policyName));

      _accessTokens[subject] = _accessTokenFromAuthResult(result);

      _emitCallback(B2COperationResult(
          tag, _POLICY_TRIGGER_SILENTLY, B2COperationState.SUCCESS));
    } on AuthException catch (exception) {
      log("Authentication failed: $exception", name: tag);
      if (exception is ClientAuthException) {
        _emitCallback(B2COperationResult(
            tag, _POLICY_TRIGGER_SILENTLY, B2COperationState.CLIENT_ERROR));
      } else if (exception is ServerException) {
        /* Exception when communicating with the STS, likely config issue */
        _emitCallback(B2COperationResult(
            tag, _POLICY_TRIGGER_SILENTLY, B2COperationState.SERVICE_ERROR));
      } else if (exception is InteractionRequiredAuthException) {
        /* Tokens expired or no session, retry with interactive */
        _emitCallback(B2COperationResult(tag, _POLICY_TRIGGER_SILENTLY,
            B2COperationState.USER_INTERACTION_REQUIRED));
      }
    }
  }

  Future signOut(String subject) async {
    try {
      var user = _users[subject];
      if (user == null) {
        _emitCallback(B2COperationResult(
            tag, _POLICY_TRIGGER_SILENTLY, B2COperationState.CLIENT_ERROR));
        return;
      }

      if (_interactionMode == B2CInteractionMode.REDIRECT) {
        await _b2cApp!.logoutRedirect(EndSessionRequest()..account = user);
        return; //redirect flow will restart the app
      } else {
        await _b2cApp!.logoutPopup(EndSessionPopupRequest()..account = user);

        _users.remove(user.idTokenClaims!["sub"]);
      }
    } on AuthException {
      _emitCallback(
          B2COperationResult(tag, _SING_OUT, B2COperationState.CLIENT_ERROR));
    }
  }

  List<String> getSubjects() {
    List<String> toRet = [];
    for (var sub in _users.keys) toRet.add(sub);

    return toRet;
  }

  B2CUserInfo? getSubjectInfo(String subject) {
    if (_users.containsKey(subject)) {
      var user = _users[subject]!;
      return B2CUserInfo(subject, user.username, user.idTokenClaims!);
    }
    return null;
  }

  B2CAccessToken? getAccessToken(String subject) {
    if (_accessTokens.containsKey(subject)) {
      return _accessTokens[subject]!;
    }
    return null;
  }

  static void storeRedirectHash() {
    _lastHash = window.location.hash;
    log(_lastHash!, name: "B2CProviderWebStatic");
  }

  B2CAccessToken _accessTokenFromAuthResult(AuthenticationResult result) {
    return B2CAccessToken(result.uniqueId, result.accessToken,
        _format.parse(result.expiresOn.toString()));
  }

  void _loadAllAccounts() {
    var accounts = _b2cApp!.getAllAccounts();
    for (var account in accounts) {
      _users[account.idTokenClaims!["sub"]] = account;
    }
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
