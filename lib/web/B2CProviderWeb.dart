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

import 'dart:convert';
import 'dart:developer';
import 'dart:html';

import 'package:flutter_azure_b2c/B2CAccessToken.dart';
import 'package:flutter_azure_b2c/B2CConfiguration.dart';
import 'package:flutter_azure_b2c/B2COperationResult.dart';
import 'package:flutter_azure_b2c/B2CUserInfo.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:msal_js/msal_js.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Web interaction mode enum.
enum B2CInteractionMode { REDIRECT, POPUP }

/// Standard callback type used from the [B2CProviderWeb] provider.
///
/// It receives a [B2COperationResult] object.
///
/// Returns an awaitable [Future].
typedef B2CCallback = Future<void> Function(B2COperationResult);

/// Azure AD B2C protocol provider (web implementation).
///
class B2CProviderWeb {
  PublicClientApplication? _b2cApp;
  Map<String, AccountInfo> _users = {};
  Map<String, B2CAccessToken> _accessTokens = {};
  Configuration? _configuration;
  B2CInteractionMode _interactionMode = B2CInteractionMode.POPUP;
  String? _hostName;
  String? _tenantName;
  List<String> _defaultScopes = [];

  static String? _lastHash;

  B2CCallback? callback;

  static const String _B2C_PASSWORD_CHANGE = "AADB2C90118";
  static const String _B2C_USER_CANCELLED = "user_cancelled";
  static const String _B2C_PLUGIN_LAST_ACCESS = "b2c_plugin_last_access";

  static final DateFormat _format =
      DateFormat("E MMM dd yyyy HH:mm:ss Z", "en_US");

  /// Creates an istance of the B2CProviderWeb.
  ///
  B2CProviderWeb({this.callback});

  /// Init B2C application. It look for existing accounts and retrieves
  /// information.
  ///
  /// The [tag] argument is used to distinguish which invocation of the init
  /// generated the return callback. The [configFileName] argument specifies
  /// the name of the json configuration file in the web/assets folder.
  ///
  /// Returns a [Future] callable from the [AzureB2C] plugin.
  ///
  /// It emits a [B2COperationResult] with possible results:
  ///   * [B2COperationState.SUCCESS] from [B2COperationSource.INIT] if init is
  ///     successful.
  ///   * [B2COperationState.CLIENT_ERROR] from [B2COperationSource.INIT] if an
  ///     error occurred.
  /// If redirect mode is selected it also emits:
  ///   * [B2COperationState.SUCCESS] from
  ///   [B2COperationSource.POLICY_TRIGGER_INTERACTIVE] if the policy flow has
  ///   been successful after redirection to the app.
  ///   * [B2COperationState.PASSWORD_RESET] from
  ///   [B2COperationSource.POLICY_TRIGGER_INTERACTIVE] if the user has
  ///   requested a password change.
  ///
  Future init(String tag, String configFileName) async {
    initializeDateFormatting();

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

      if (conf.containsKey("default_scopes")) {
        for (String scope in conf["default_scopes"]) {
          _defaultScopes.add(scope);
        }
      }

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
            _emitCallback(B2COperationResult(
                tag,
                B2COperationSource.POLICY_TRIGGER_INTERACTIVE,
                B2COperationState.SUCCESS));
          }
        } catch (exception) {
          log("SessionStorage temp access token parse failed: $exception",
              name: tag);
        } finally {
          window.localStorage.remove(_B2C_PLUGIN_LAST_ACCESS);
        }
      }

      if (_lastHash != null && _lastHash != "#/") {
        if (_lastHash!.contains(_B2C_PASSWORD_CHANGE)) {
          window.sessionStorage
              .removeWhere((key, value) => key.startsWith("msal"));

          _emitCallback(B2COperationResult(
              tag,
              B2COperationSource.POLICY_TRIGGER_INTERACTIVE,
              B2COperationState.PASSWORD_RESET));
          return;
        } else {
          var result = await _b2cApp!.handleRedirectFuture(_lastHash);
          if (result != null) {
            _users[result.uniqueId] = result.account!;
            _accessTokens[result.uniqueId] = _accessTokenFromAuthResult(result);

            // MSAL seams to reload the page after the handleRedirectFuture is
            // completed, so we temporarly store the access token in the local
            // storage to use it later, e.g. see code before.
            window.localStorage[_B2C_PLUGIN_LAST_ACCESS] =
                json.encode(_accessTokenFromAuthResult(result));
          }
        }

        _lastHash = null;
      }

      _emitCallback(B2COperationResult(
          tag, B2COperationSource.INIT, B2COperationState.SUCCESS));
    } catch (ex) {
      _emitCallback(B2COperationResult(
          tag, B2COperationSource.INIT, B2COperationState.CLIENT_ERROR));
    }
  }

  /// Runs user flow interactively.
  ///
  /// Once the user finishes with the flow, an access-token and an id-token
  /// containing user's claims are stored in the sessionStorage or localStorage
  /// respectively as specified in the configuration file.
  ///
  /// The [tag] argument is used to distinguish which invocation of this
  /// function generated the return callback. The [policyName] permits to
  /// select which authority (user-flow) trigger from the ones specified in the
  /// configuration file. It must be indicated just the name of the policy
  /// without the host and tenat part. It is possible to indicate user's
  /// [scopes] for the request (i.e it is also possible to indicate default
  /// scopes in the configuration file that can be then accessed from
  /// [B2CConfiguration.defaultScopes]). A [loginHint] may be passed to directly
  /// fill the email/username/phone-number field in the policy flow.
  ///
  /// Based on the specified field [<interaction_mode>: popup|redirect] in the
  /// configuration file, the policy will be triggered via redirect or with a
  /// popup respectively if [B2CInteractionMode.REDIRECT] or
  /// [B2CInteractionMode.POPUP] is selected.
  /// In [B2CInteractionMode.REDIRECT] mode the policy state hash
  /// parameter must be intercepted during app startup as specified in the
  /// plugin implementation.
  ///
  /// Returns a [Future] callable from the [AzureB2C] plugin.
  ///
  /// It emits a [B2COperationResult] from
  /// [B2COperationSource.POLICY_TRIGGER_INTERACTIVE] with possible results:
  ///   * [B2COperationState.SUCCESS] if successful,
  ///   * [B2COperationState.CLIENT_ERROR] if an error occurred,
  ///   * [B2COperationState.PASSWORD_RESET] if user requested a password reset,
  ///   * [B2COperationState.USER_CANCELLED_OPERATION] if the user cancelled the
  ///   operation (only in [B2CInteractionMode.POPUP]),
  ///   * [B2COperationState.SERVICE_ERROR] if there is a configuration error
  ///   with respect to the authority setting or if the authentication provider
  ///   is down for some reasons.
  ///
  Future policyTriggerInteractive(String tag, String policyName,
      List<String> scopes, String? loginHint) async {
    try {
      if (_interactionMode == B2CInteractionMode.REDIRECT) {
        await _b2cApp!.acquireTokenRedirect(RedirectRequest()
          ..scopes = scopes
          ..authority = _getAuthorityFromPolicyName(policyName)
          ..loginHint = loginHint);
        return; //redirect flow will restart the app
      } else {
        var result = await _b2cApp!.acquireTokenPopup(PopupRequest()
          ..scopes = scopes
          ..authority = _getAuthorityFromPolicyName(policyName)
          ..loginHint = loginHint);

        _users[result.uniqueId] = result.account!;
        _accessTokens[result.uniqueId] = _accessTokenFromAuthResult(result);
      }
      _emitCallback(B2COperationResult(
          tag,
          B2COperationSource.POLICY_TRIGGER_INTERACTIVE,
          B2COperationState.SUCCESS));
    } on AuthException catch (exception) {
      if (exception.errorMessage.contains(_B2C_PASSWORD_CHANGE)) {
        _emitCallback(B2COperationResult(
            tag,
            B2COperationSource.POLICY_TRIGGER_INTERACTIVE,
            B2COperationState.PASSWORD_RESET));
      } else {
        /* Failed to acquireToken */
        log("Authentication failed: $exception", name: tag);
        if (exception is ClientAuthException) {
          /* Exception inside MSAL, more info inside MsalError.java */
          _emitCallback(B2COperationResult(
              tag,
              B2COperationSource.POLICY_TRIGGER_INTERACTIVE,
              B2COperationState.CLIENT_ERROR));
        } else if (exception is ServerException) {
          /* Exception when communicating with the STS, likely config issue */
          _emitCallback(B2COperationResult(
              tag,
              B2COperationSource.POLICY_TRIGGER_INTERACTIVE,
              B2COperationState.SERVICE_ERROR));
        } else if (exception is BrowserAuthException) {
          if (exception.errorCode.contains(_B2C_USER_CANCELLED)) {
            /* User closed popup */
            _emitCallback(B2COperationResult(
                tag,
                B2COperationSource.POLICY_TRIGGER_INTERACTIVE,
                B2COperationState.USER_CANCELLED_OPERATION));
            return;
          }
          _emitCallback(B2COperationResult(
              tag,
              B2COperationSource.POLICY_TRIGGER_INTERACTIVE,
              B2COperationState.CLIENT_ERROR));
        }
      }
    }
  }

  /// Run user flow silently using stored refresh token.
  ///
  /// Once the user finishes with the flow, the stored access-token will be
  /// refreshed and stored in the sessionStorage or localStorage
  /// respectively as specified in the configuration file.
  ///
  /// The [tag] argument is used to distinguish which invocation of this
  /// function generated the return callback. The [subject] is used to specify
  /// the user to authenticate (it corresponds to the <oid> or <sub> claims
  /// specified in the id-token of the user (i.e. subject are stored from the
  /// [B2CProviderWeb] and can be accessed via the [getSubjects] method).
  /// The [policyName] permits to select which authority (user-flow) trigger
  /// from the ones specified in the configuration file.
  /// It must be indicated just the name of the policy without the
  /// host and tenat part. It is possible to indicate user's
  /// [scopes] for the request (i.e it is also possible to indicate default
  /// scopes in the configuration file that can be then accessed from
  /// [B2CConfiguration.defaultScopes]).
  ///
  /// Returns a [Future] callable from the [AzureB2C] plugin.
  ///
  /// It emits a [B2COperationResult] from
  /// [B2COperationSource.POLICY_TRIGGER_SILENTLY] with possible results:
  ///   * [B2COperationState.SUCCESS] if successful,
  ///   * [B2COperationState.CLIENT_ERROR] if an error occurred,
  ///   * [B2COperationState.USER_INTERACTION_REQUIRED] if it the policy trigger
  ///   cannot be completed without user intervention (e.g. refresh token
  ///   expired).
  ///   * [B2COperationState.SERVICE_ERROR] if there is a configuration error
  ///   with respect to the authority setting or if the authentication provider
  ///   is down for some reasons.
  ///
  Future policyTriggerSilently(String tag, String subject, String policyName,
      List<String> scopes) async {
    try {
      var user = _users[subject];
      if (user == null) {
        _emitCallback(B2COperationResult(
            tag,
            B2COperationSource.POLICY_TRIGGER_SILENTLY,
            B2COperationState.CLIENT_ERROR));
        return;
      }
      var result = await _b2cApp!.acquireTokenSilent(SilentRequest()
        ..account = user
        ..scopes = scopes
        ..authority = _getAuthorityFromPolicyName(policyName));

      _accessTokens[subject] = _accessTokenFromAuthResult(result);

      _emitCallback(B2COperationResult(
          tag,
          B2COperationSource.POLICY_TRIGGER_SILENTLY,
          B2COperationState.SUCCESS));
    } on AuthException catch (exception) {
      log("Authentication failed: $exception", name: tag);
      if (exception is ClientAuthException) {
        _emitCallback(B2COperationResult(
            tag,
            B2COperationSource.POLICY_TRIGGER_SILENTLY,
            B2COperationState.CLIENT_ERROR));
      } else if (exception is InteractionRequiredAuthException) {
        /* Tokens expired or no session, retry with interactive */
        _emitCallback(B2COperationResult(
            tag,
            B2COperationSource.POLICY_TRIGGER_SILENTLY,
            B2COperationState.USER_INTERACTION_REQUIRED));
      } else if (exception is ServerException) {
        /* Exception when communicating with the STS, likely config issue */
        _emitCallback(B2COperationResult(
            tag,
            B2COperationSource.POLICY_TRIGGER_SILENTLY,
            B2COperationState.SERVICE_ERROR));
      }
    }
  }

  /// Sign out user and erases associated tokens.
  ///
  /// The [tag] argument is used to distinguish which invocation of this
  /// function generated the return callback. The [subject] is used to specify
  /// the user to authenticate (it corresponds to the <oid> or <sub> claims
  /// specified in the id-token of the user (i.e. subject are stored from the
  /// [B2CProviderWeb] and can be accessed via the [getSubjects] method).
  ///
  /// Returns a [Future] callable from the [AzureB2C] plugin.
  ///
  /// It emits a [B2COperationResult] from [B2COperationSource.SIGN_OUT] with
  /// possible results:
  ///   * [B2COperationState.SUCCESS] if successful (only in
  ///   [B2CInteractionMode.POPUP] mode or it will reload the app if in
  ///   [B2CInteractionMode.REDIRECT] mode),
  ///   * [B2COperationState.CLIENT_ERROR] if an error occurred,
  ///
  Future signOut(String tag, String subject) async {
    try {
      var user = _users[subject];
      if (user == null) {
        _emitCallback(B2COperationResult(
            tag,
            B2COperationSource.POLICY_TRIGGER_SILENTLY,
            B2COperationState.CLIENT_ERROR));
        return;
      }

      if (_interactionMode == B2CInteractionMode.REDIRECT) {
        await _b2cApp!.logoutRedirect(EndSessionRequest()..account = user);
        return; //redirect flow will restart the app
      } else {
        await _b2cApp!.logoutPopup(EndSessionPopupRequest()..account = user);

        _users.remove(_getUniqueId(user));
        _emitCallback(B2COperationResult(
            tag, B2COperationSource.SIGN_OUT, B2COperationState.SUCCESS));
      }
    } on AuthException {
      _emitCallback(B2COperationResult(
          tag, B2COperationSource.SIGN_OUT, B2COperationState.CLIENT_ERROR));
    }
  }

  /// Returns a list of stored subjects.
  ///
  /// Each subject represents a stored B2C user (i.e. id-token).
  /// Subjects are used to identify specific users and perform operations on.
  ///
  /// Returns a [List] of stored subjects.
  ///
  List<String> getSubjects() {
    List<String> toRet = [];
    for (var sub in _users.keys) toRet.add(sub);

    return toRet;
  }

  /// Returns subject's stored information.
  ///
  /// Returns a [B2CUserInfo] object or [null] if the subject does not exists.
  ///
  B2CUserInfo? getSubjectInfo(String subject) {
    if (_users.containsKey(subject)) {
      var user = _users[subject]!;
      return B2CUserInfo(subject, user.username, user.idTokenClaims!);
    }
    return null;
  }

  /// Returns subject's stored access-token.
  ///
  /// Returns a [B2CAccessToken] object or [null] if the subject does not
  /// exists.
  ///
  B2CAccessToken? getAccessToken(String subject) {
    if (_accessTokens.containsKey(subject)) {
      return _accessTokens[subject]!;
    }
    return null;
  }

  /// Get the provider configuration (i.e. a compact representation, NOT the
  /// full MSAL configuration).
  ///
  /// Returns a [B2CConfiguration] object or [null] if the provider is not
  /// configured yet.
  ///
  B2CConfiguration? getConfiguration() {
    var authorities = <B2CAuthority>[
      B2CAuthority(_configuration!.auth!.authority!, "B2C", true)
    ];
    for (var authority in _configuration!.auth!.knownAuthorities!) {
      //do not replicate default authority
      if (authorities[0].authorityURL != authority) {
        authorities.add(B2CAuthority(authority, "B2C", false));
      }
    }

    return B2CConfiguration(_configuration!.auth!.clientId!,
        _configuration!.auth!.redirectUri!, authorities,
        cacheLocation:
            _configuration!.cache!.cacheLocation.toString().split(".")[1],
        interactionMode: _interactionMode.toString().split(".")[1],
        defaultScopes: _defaultScopes);
  }

  /// Handles the state hash parameter returned from the authentication provider
  /// if [B2CInteractionMode.REDIRECT] mode is selected. This method should be
  /// called before the MaterialApp widget overwrites the url.
  ///
  /// See also:
  ///   * [AzureB2C] plugin
  static void storeRedirectHash() {
    _lastHash = window.location.hash;
    if (_lastHash == "#/") {
      bool interactionWasStarted = false;
      window.sessionStorage.forEach((key, value) {
        //this happens when user click back button on redirect hash
        if (key.startsWith("msal") && value == "interaction_in_progress") {
          interactionWasStarted = true;
        }
      });

      if (interactionWasStarted) {
        log("User pressed back button, cleaning", name: "B2CProviderWebStatic");
        window.sessionStorage
            .removeWhere((key, value) => key.startsWith("msal"));
      }
    }

    log(_lastHash!, name: "B2CProviderWebStatic");
  }

  B2CAccessToken _accessTokenFromAuthResult(AuthenticationResult result) {
    return B2CAccessToken(result.uniqueId, result.accessToken,
        _format.parse(result.expiresOn.toString()).toUtc());
  }

  void _loadAllAccounts() {
    var accounts = _b2cApp!.getAllAccounts();
    for (var account in accounts) {
      _users[_getUniqueId(account)] = account;
    }
  }

  String _getUniqueId(AccountInfo? accountInfo) {
    if (accountInfo!.idTokenClaims!.containsKey("oid"))
      return accountInfo.idTokenClaims!["oid"];
    return accountInfo.idTokenClaims!["sub"];
  }

  void _emitCallback(B2COperationResult result) {
    if (result.reason == B2COperationState.CLIENT_ERROR)
      window.sessionStorage.removeWhere((key, value) => key.startsWith("msal"));

    if (callback != null) callback!(result);
  }

  void _setHostAndTenantFromAuthority(String authority) {
    var parts = authority.split(RegExp("https://|/"));
    _hostName = parts[1];
    _tenantName = parts[2];
  }

  String _getAuthorityFromPolicyName(String policyName) {
    return "https://${_hostName!}/${_tenantName!}/$policyName/";
  }
}
