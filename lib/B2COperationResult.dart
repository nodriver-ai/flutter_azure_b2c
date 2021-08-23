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

/// Operation states enum used in [AzureB2C] callbacks.
enum B2COperationState {
  READY,
  SUCCESS,
  PASSWORD_RESET,
  USER_CANCELLED_OPERATION,
  USER_INTERACTION_REQUIRED,
  CLIENT_ERROR,
  SERVICE_ERROR
}

/// Operation states sources used in [AzureB2C] callbacks.
enum B2COperationSource {
  INIT,
  POLICY_TRIGGER_SILENTLY,
  POLICY_TRIGGER_INTERACTIVE,
  SIGN_OUT
}

/// Operation result used in [AzureB2C] callbacks.
class B2COperationResult {
  /// A tag used to differentiate operations. AzureB2C plugin put a GUID
  /// (i.e. unique id) different for each operation. Tags are returned from
  /// [AzureB2C] plugin for each asynchronous operation.
  ///
  /// See also:
  ///   * [AzureB2C]
  late String tag;

  /// Source of the operation.
  late B2COperationSource source;

  /// Reason why the callback was launched. In this field is stored the state of
  /// the async operation that has emitted the callback.
  late B2COperationState reason;

  /// Possible data payload in the callback for possible extensions.
  Object? data;

  /// Default constructor.
  ///
  /// The [tag] is a string generated from the [AzureB2C] plugin and is used to
  /// differentiate operation in the callback functions. The [source] argument
  /// is a [B2COperationSource] enum that express which method has generated the
  /// callback, and [reason] is a [B2COperationState] enum that express the
  /// result of the operation.
  ///
  B2COperationResult(this.tag, this.source, this.reason, {this.data});

  /// Creates a [B2COperationResult] from a JSON map.
  B2COperationResult.fromJson(Map<String, dynamic> data) {
    this.tag = data["tag"];
    switch ((data["source"]! as String).toUpperCase()) {
      case "INIT":
        this.source = B2COperationSource.INIT;
        break;
      case "POLICY_TRIGGER_SILENTLY":
        this.source = B2COperationSource.POLICY_TRIGGER_SILENTLY;
        break;
      case "POLICY_TRIGGER_INTERACTIVE":
        this.source = B2COperationSource.POLICY_TRIGGER_INTERACTIVE;
        break;
      case "SIGN_OUT":
        this.source = B2COperationSource.SIGN_OUT;
        break;
    }
    switch ((data["reason"]! as String).toUpperCase()) {
      case "READY":
        this.reason = B2COperationState.READY;
        break;
      case "SUCCESS":
        this.reason = B2COperationState.SUCCESS;
        break;
      case "PASSWORD_RESET":
        this.reason = B2COperationState.PASSWORD_RESET;
        break;
      case "USER_CANCELLED_OPERATION":
        this.reason = B2COperationState.USER_CANCELLED_OPERATION;
        break;
      case "USER_INTERACTION_REQUIRED":
        this.reason = B2COperationState.USER_INTERACTION_REQUIRED;
        break;
      case "CLIENT_ERROR":
        this.reason = B2COperationState.CLIENT_ERROR;
        break;
      case "SERVICE_ERROR":
        this.reason = B2COperationState.SERVICE_ERROR;
        break;
    }
  }

  /// Returns a JSON representation.
  Map toJson() => {
        "tag": tag,
        "source": source.toString().split(".")[1].toLowerCase(),
        "reason": reason.toString().split(".")[1]
      };
}
