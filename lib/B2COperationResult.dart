enum B2COperationState {
  READY,
  SUCCESS,
  PASSWORD_RESET,
  USER_CANCELLED_OPERATION,
  USER_INTERACTION_REQUIRED,
  CLIENT_ERROR,
  SERVICE_ERROR
}

enum B2COperationSource {
  // static const String _INIT = "init";
  // static const String _POLICY_TRIGGER_SILENTLY = "policy_trigger_silently";
  // static const String _POLICY_TRIGGER_INTERACTIVE =
  //     "policy_trigger_interactive";
  // static const String _SING_OUT = "sign_out";
  INIT,
  POLICY_TRIGGER_SILENTLY,
  POLICY_TRIGGER_INTERACTIVE,
  SING_OUT
}

class B2COperationResult {
  late String tag;
  late B2COperationSource source;
  late B2COperationState reason;
  Object? data;

  B2COperationResult(this.tag, this.source, this.reason, {this.data});

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
      case "SING_OUT":
        this.source = B2COperationSource.SING_OUT;
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

  Map toJson() => {
        "tag": tag,
        "source": source.toString().split(".")[1].toLowerCase(),
        "reason": reason.toString().split(".")[1]
      };
}
