package com.nodriver.flutter_azure_b2c


class B2COperationResult(val tag: String, val source: String,
                         val reason: B2COperationState, val data: Any? = null) {

}

enum class B2COperationState {
    READY,
    SUCCESS,
    PASSWORD_RESET,
    USER_CANCELLED_OPERATION,
    USER_INTERACTION_REQUIRED,
    CLIENT_ERROR,
    SERVICE_ERROR
}

interface IB2COperationListener {
    fun onEvent(operationResult: B2COperationResult);
}