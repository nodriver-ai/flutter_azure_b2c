import 'dart:convert';

class B2CAuthority {
  late final String authorityURL;
  late final String authorityType;
  late final bool isDefault;

  String get policyName => authorityURL.split(RegExp("https://|/"))[3];

  B2CAuthority(this.authorityURL, this.authorityType, this.isDefault);

  B2CAuthority.fromJson(Map<String, dynamic> data) {
    this.authorityURL = data["authority_url"];
    if (data.containsKey("type"))
      this.authorityType = data["type"];
    else
      this.authorityType = "B2C";

    if (data.containsKey("default"))
      this.isDefault = data["default"];
    else
      this.isDefault = false;
  }

  Map toJson() => {
        "authority_url": authorityURL,
        "type": authorityType,
        "default": isDefault
      };
}

class B2CConfiguration {
  late final String clientId;
  late final String redirectURI;
  late final String? cacheLocation;
  late final String? interactionMode;
  late final String? accountMode;
  late final bool? brokerRedirectUriRegistered;
  late final List<B2CAuthority> authorities;
  late final List<String>? defaultScopes;

  B2CAuthority get defaultAuthority =>
      authorities.firstWhere((element) => element.isDefault == true);

  B2CConfiguration(this.clientId, this.redirectURI, this.authorities,
      {this.cacheLocation,
      this.interactionMode,
      this.accountMode,
      this.brokerRedirectUriRegistered,
      this.defaultScopes});

  B2CConfiguration.fromJson(Map<String, dynamic> data) {
    this.clientId = data["client_id"];
    this.redirectURI = data["redirect_uri"];
    this.authorities = <B2CAuthority>[];
    for (Map<String, dynamic> authData in data["authorities"]) {
      this.authorities.add(B2CAuthority.fromJson(authData));
    }

    if (data.containsKey("cache_location"))
      this.cacheLocation = data["cache_location"];

    if (data.containsKey("interaction_mode"))
      this.interactionMode = data["interaction_mode"];

    if (data.containsKey("account_mode"))
      this.accountMode = data["account_mode"];

    if (data.containsKey("broker_redirect_uri_registered"))
      this.brokerRedirectUriRegistered = data["broker_redirect_uri_registered"];

    if (data.containsKey("default_scopes")) {
      List<String> defaultScopesData = [];
      for (var scope in data["default_scopes"]) {
        defaultScopesData.add(scope as String);
      }
      this.defaultScopes = defaultScopesData;
    }
  }

  Map toJson() {
    List<Map> authoritiesMap =
        this.authorities.map((authority) => authority.toJson()).toList();
    return {
      "client_id": clientId,
      "redirect_uri": redirectURI,
      "authorities": authoritiesMap,
      "cache_location": cacheLocation != null ? cacheLocation : null,
      "interaction_mode": interactionMode != null ? interactionMode : null,
      "account_mode": accountMode != null ? accountMode : null,
      "broker_redirect_uri_registered": brokerRedirectUriRegistered != null
          ? brokerRedirectUriRegistered
          : null,
      "default_scopes": defaultScopes != null ? defaultScopes : null
    };
  }
}
