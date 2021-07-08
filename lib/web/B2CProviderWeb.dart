import 'dart:convert';

import 'package:msal_js/msal_js.dart';
import 'package:flutter/services.dart' show rootBundle;

enum _B2CLoginMode { REDIRECT, POPUP }

class B2CProviderWeb {
  PublicClientApplication? _b2cApp;
  Configuration? _configuration;
  _B2CLoginMode _loginMode = _B2CLoginMode.REDIRECT;
  String? _hostName;
  String? _tenantName;

  Future init(String configFileName) async {
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

    if (conf.containsKey("login_mode")) {
      if (conf["login_mode"] == "popup") _loginMode = _B2CLoginMode.POPUP;
    }

    String? defaultAuthority;
    List<String> authorities = <String>[];
    if (conf.containsKey("authorities")) {
      for (Map<String, dynamic> authority in conf["authorities"]) {
        if (authority.containsKey("default") && authority["default"] == true) {
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
  }

  Future policyTriggerInteractive(
      String policyName, List<String> scopes, String? loginHint) async {
    if (_loginMode == _B2CLoginMode.REDIRECT) {
      _b2cApp!.loginRedirect(RedirectRequest()
        ..scopes = scopes
        ..authority = getAuthorityFromPolicyName(policyName)
        ..loginHint = loginHint);
    } else {
      _b2cApp!.loginPopup(PopupRequest()
        ..scopes = scopes
        ..authority = getAuthorityFromPolicyName(policyName)
        ..loginHint = loginHint);
    }
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
