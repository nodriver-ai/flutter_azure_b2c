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

/// Access token utility class.
class B2CAccessToken {
  /// Owner of the access token.
  late final String subject;

  /// Access token string.
  late final String token;

  /// Access token expiration date in UTC format.
  late final DateTime expireOn;

  /// Creates an access token.
  ///
  /// The [subject] express the owner of the access token, the [token] argument
  /// is the string representation of the token itself, and [expireOn] indicates
  /// the date-time when the token will expire.
  ///
  B2CAccessToken(this.subject, this.token, this.expireOn);

  /// Creates an access token from a JSON map.
  ///
  B2CAccessToken.fromJson(Map<String, dynamic> data) {
    this.subject = data["subject"];
    this.token = data["token"];
    this.expireOn = DateTime.parse(data["expire"]).toUtc();
  }

  /// Transform the token to a JSON representation.
  ///
  Map toJson() => {
        "subject": subject,
        "token": token,
        "expire": expireOn.toIso8601String()
      };
}
