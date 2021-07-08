class B2CAccessToken {
  late final String subject;
  late final String token;
  late final DateTime expireOn;

  B2CAccessToken(this.subject, this.token, this.expireOn);

  B2CAccessToken.fromJson(String subject, Map<String, dynamic> data) {
    this.subject = subject;
    this.token = data["token"];
    this.expireOn = DateTime.parse(data["expireOn"]);
  }
}
