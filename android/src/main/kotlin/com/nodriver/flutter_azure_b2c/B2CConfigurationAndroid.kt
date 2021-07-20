package com.nodriver.flutter_azure_b2c

import com.google.gson.annotations.SerializedName


class B2CAuthority(val authorityUrl: String, @SerializedName("type")val authorityType: String,
                   @SerializedName("default")val isDefault: Boolean) {

}

class B2CConfigurationAndroid(
    val clientId: String,
    val redirectUri: String,
    val accountMode: String = "MULTI",
    val brokerRedirectUriRegistered: Boolean = false,
    val authorities: List<B2CAuthority>,
    val defaultScopes: List<String>?) {
}