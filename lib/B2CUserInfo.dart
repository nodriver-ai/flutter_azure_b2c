class B2CUserInfo {
  late final String subject;
  late final String username;
  late final Map<String, dynamic> claims;

  B2CUserInfo(this.subject, this.username, this.claims);

  B2CUserInfo.fromJson(String subject, Map<String, dynamic> data) {
    this.subject = subject;
    this.username = data["username"];
    this.claims = Map<String, dynamic>();

    Map<String, dynamic> dClaims = data["claims"];
    for (var key in dClaims.keys) {
      this.claims[key] = dClaims[key];
    }
  }

  Map toJson() => {"subject": subject, "username": username, "claims": claims};
}
