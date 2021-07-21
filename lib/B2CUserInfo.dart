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

/// Utility class to manage and store users informations.
class B2CUserInfo {
  /// Unique id string for each user. Dependant from the B2C configuration it
  /// uses the <oid> or the <sub> claims in the id-token.
  late final String subject;

  /// Email, username, or phone-number (depending on B2C configuration)
  late final String username;

  /// Map of user claims.
  late final Map<String, dynamic> claims;

  /// Default construtor. Use only in plugin extension.
  B2CUserInfo(this.subject, this.username, this.claims);

  /// Creates a [B2CUserInfo] from a JSON map.
  B2CUserInfo.fromJson(String subject, Map<String, dynamic> data) {
    this.subject = subject;
    this.username = data["username"];
    this.claims = Map<String, dynamic>();

    Map<String, dynamic> dClaims = data["claims"];
    for (var key in dClaims.keys) {
      this.claims[key] = dClaims[key];
    }
  }

  /// Returns a JSON representation.
  Map toJson() => {"subject": subject, "username": username, "claims": claims};
}
