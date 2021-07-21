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

/// Authority representation.
class B2CAuthority {
  /// Complete URL of the authority.
  late final String authorityURL;

  /// Authority type (e.g. B2C).
  late final String authorityType;

  /// Indicates if it is the default authority or not (i.e. the default
  /// authority is used to obtain the configuration, typicaly in B2C the default
  /// authority is the sign_up_sign_in policy).
  late final bool isDefault;

  /// Return the policy name associathed to the authority.
  String get policyName => authorityURL.split(RegExp("https://|/"))[3];

  /// Default constructor.
  ///
  /// The [authorityURL] argument corresponds to the complete URL of the
  /// authority terminating with a '/', [authorityType] indicates if the type of
  /// the authority (e.g. B2C) and [isDefault] if this authority is the default
  /// one.
  B2CAuthority(this.authorityURL, this.authorityType, this.isDefault);

  /// Creates a [B2CAuthority] from a JSON map.
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

  /// Returns a JSON representation.
  Map toJson() => {
        "authority_url": authorityURL,
        "type": authorityType,
        "default": isDefault
      };
}

/// Compact configuration (not MSAL complete configuration) usefull for typical
/// app interactiona after the B2C provider has been configured using an MSAl
/// JSON configuration file.
class B2CConfiguration {
  /// The client_id of the B2C app.
  late final String clientId;

  /// Application redirect URI (dependant from the platform).
  late final String redirectURI;

  /// Cache location (web only).
  late final String? cacheLocation;

  /// Interaction mode [redirect|popup] (web only).
  late final String? interactionMode;

  /// Application account mode [SINGLE|MULTIPLE].
  late final String? accountMode;

  /// Broker mode (mobile only).
  late final bool? brokerRedirectUriRegistered;

  /// List of known authorities.
  late final List<B2CAuthority> authorities;

  /// App default scopes (in MSAL config file it can be added a field
  /// <default_scopes> that will fill this field).
  late final List<String>? defaultScopes;

  /// Gets the default authority.
  B2CAuthority get defaultAuthority =>
      authorities.firstWhere((element) => element.isDefault == true);

  /// Default contructor. (Do not use!)
  B2CConfiguration(this.clientId, this.redirectURI, this.authorities,
      {this.cacheLocation,
      this.interactionMode,
      this.accountMode,
      this.brokerRedirectUriRegistered,
      this.defaultScopes});

  /// Creates a [B2CConfiguration] from a JSON map.
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

  /// Returns a JSON representation.
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
