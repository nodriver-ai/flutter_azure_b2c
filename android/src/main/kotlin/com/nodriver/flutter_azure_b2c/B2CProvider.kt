package com.nodriver.flutter_azure_b2c

import android.app.Activity
import android.content.Context
import android.util.Log
import com.microsoft.identity.client.*
import com.microsoft.identity.client.IPublicClientApplication.IMultipleAccountApplicationCreatedListener
import com.microsoft.identity.client.IPublicClientApplication.LoadAccountsCallback
import com.microsoft.identity.client.exception.MsalClientException
import com.microsoft.identity.client.exception.MsalException
import com.microsoft.identity.client.exception.MsalServiceException
import com.microsoft.identity.client.exception.MsalUiRequiredException
import com.microsoft.identity.common.internal.authorities.Authority
import java.util.*


/**
 * Azure AD B2C protocol provider.
 *
 */
class B2CProvider(
    private var TAG: String,
    private var operationListener: IB2COperationListener
) {

    companion object {
        const val B2C_PASSWORD_CHANGE = "AADB2C90118"
        const val INIT = "init"
        const val POLICY_TRIGGER_SILENTLY = "sign_in_silently"
        const val POLICY_TRIGGER_INTERACTIVE = "sign_in_interactive"
        const val SING_OUT = "sign_out"
    }


    private var users: List<B2CUser>? = null

    /* Azure AD Variables */
    private var b2cApp: IMultipleAccountPublicClientApplication? = null
    private lateinit var hostName: String
    private lateinit var tenantName: String

    private val authResults: MutableMap<String, IAuthenticationResult> = mutableMapOf()


    /**
     * Init B2C application. It look for existing accounts and retrieves information.
     *
     */
    fun init(context: Context, configFileName: String) {
        var configFileId = PluginUtilities.getRawResourceIdentifier(context, configFileName)

        PublicClientApplication.createMultipleAccountPublicClientApplication(context,
            configFileId,
            object : IMultipleAccountApplicationCreatedListener {
                override fun onCreated(application: IMultipleAccountPublicClientApplication) {
                    b2cApp = application
                    setHostAndTenantFromAuthority(b2cApp!!.configuration.defaultAuthority)

                    Log.d(TAG, "Init success")
                    loadAccounts(INIT)

                }

                override fun onError(exception: MsalException) {
                    Log.d(TAG, "Init failed: $exception")
                    operationListener.onEvent(B2COperationResult(TAG, INIT, B2COperationState.CLIENT_ERROR))
                }
            })

    }



    /**
     * Runs user flow interactively.
     *
     *
     * Once the user finishes with the flow, you will also receive an access token containing the
     * claims for the scope you passed in, which you can subsequently use to obtain your resources.
     */
    fun policyTriggerInteractive(context: Context, activity: Activity,
                                 policyName: String, scopes: List<String>, loginHint: String?) {
        if (b2cApp == null) {
            return
        }

//        if (users!!.count() > 0) {
//            for (user in users!!) {
//                signOut(user)
//            }
//            loadAccounts(POLICY_TRIGGER_INTERACTIVE)
//        }

        val parameters = AcquireTokenParameters.Builder()
            .startAuthorizationFromActivity(activity)
            .fromAuthority(getAuthorityFromPolicyName(policyName))
            .withScopes(scopes)
            .withPrompt(Prompt.LOGIN)
            .withLoginHint(loginHint)
            .withCallback(authInteractiveCallback)
            .build()

        b2cApp!!.acquireToken(parameters)
    }

    /**
     * Authenticate user silently using stored refresh token.
     *
     *
     * Once the operation is completed, you will also receive an access token containing the
     * claims for the scope you passed in, which you can subsequently use to obtain your resources.
     */
    fun policyTriggerSilently(subject: String, policyName: String, scopes: List<String>) {
        if (b2cApp == null) {
            return
        }

        var selectedUser: B2CUser? = findB2CUser(subject)
        selectedUser!!.acquireTokenSilentAsync(b2cApp!!,
            hostName,
            tenantName,
            policyName,
            scopes,
            authSilentCallback)
    }

    /**
     * Sign out user and erases associated tokens
     *
     */
    fun signOut(subject: String) {
        if (b2cApp == null) {
            return
        }

        var selectedUser: B2CUser? = findB2CUser(subject)
        selectedUser!!.signOutAsync(b2cApp!!,
            object : IMultipleAccountPublicClientApplication.RemoveAccountCallback {
                override fun onRemoved() {
                    loadAccounts(SING_OUT)
                    synchronized(authResults) {
                        authResults.remove(subject);
                    }
                }

                override fun onError(exception: MsalException) {
                    Log.d(TAG, "Sign Out error: $exception")
                    operationListener.onEvent(B2COperationResult(TAG, SING_OUT, B2COperationState.CLIENT_ERROR))
                }
            })
    }

    /**
     * Get provider configuration.
     *
     * @return the provider configuration
     */
    fun getConfiguration() : PublicClientApplicationConfiguration {
        return b2cApp!!.configuration
    }

    /**
     * Returns a list of stored subjects. Each subject represents a stored B2C user.
     *
     * Subjects are used to identify specific users and perform operations on them.
     *
     * @return a list of stored user represented by their subjects
     */
    fun getSubjects(): List<String> {
        synchronized(this){
            var subjects : MutableList<String> = mutableListOf()
            for (user in users!!) {
                subjects.add(user.subject!!)
            }

            return subjects
        }
    }

    fun hasSubject(subject: String): Boolean {
        synchronized(this){
            if (findB2CUser(subject) == null) return false
            return true
        }
    }

    /**
     * Get user claims.
     * @return the user claims or null if user is not stored
     */
    fun getClaims(subject: String): MutableMap<String, *>? {
        synchronized(this){
            var subUser: B2CUser? = findB2CUser(subject) ?: return null
            return subUser!!.claims
        }
    }

    /**
     * Get user preferred username.
     * @return the preferred username or null if user is not stored
     */
    fun getUsername(subject: String): String? {
        synchronized(this){
            var subUser: B2CUser? = findB2CUser(subject) ?: return null
            return subUser!!.username
        }
    }

    /**
     * Get the last access token obtained for the user.
     * @return the accessToken or null if user is not logged in
     */
    fun getAccessToken(subject: String): String? {
        synchronized(authResults) {
            if (!authResults.containsKey(subject)) return null
            return authResults[subject]!!.accessToken
        }
    }

    /**
     * Get the expire date of the last access token obtained for the user.
     * @return the expire date or null if user is not logged in
     */
    fun getAccessTokenExpireDate(subject: String): Date? {
        synchronized(authResults) {
            if (!authResults.containsKey(subject)) return null
            return authResults[subject]!!.expiresOn
        }
    }

    private fun findB2CUser(subject: String): B2CUser? {
        return users!!.find { user -> user.subject == subject }
    }

    /**
     * Load signed-in accounts, if there's any.
     */
    private fun loadAccounts(source: String) {
        if (b2cApp == null) {
            return
        }
        b2cApp!!.getAccounts(object : LoadAccountsCallback {
            override fun onTaskCompleted(result: List<IAccount>) {
                synchronized(this){
                    users = B2CUser.getB2CUsersFromAccountList(result)
                }
                operationListener.onEvent(B2COperationResult(TAG, source, B2COperationState.SUCCESS))
            }

            override fun onError(exception: MsalException) {
                operationListener.onEvent(B2COperationResult(TAG, source, B2COperationState.CLIENT_ERROR))
            }
        })
    }

    /**
     * Callback used for interactive request.
     * If succeeds we use the access token to call the Microsoft Graph.
     * Does not check cache.
     */
    private val authInteractiveCallback: AuthenticationCallback
        private get() = object : AuthenticationCallback {
            override fun onSuccess(authenticationResult: IAuthenticationResult) {
                /* Successfully got a token, use it to call a protected resource - MSGraph */
                Log.d(TAG, "Successfully authenticated")

                /* Stores in memory the access token. Note: refresh token managed by MSAL */
                var subject = B2CUser.getSubjectFromAccount(authenticationResult.account)

                synchronized(authResults) {
                    authResults[subject!!] = authenticationResult
                }

                /* Reload account asynchronously to get the up-to-date list. */
                loadAccounts(POLICY_TRIGGER_INTERACTIVE)
            }

            override fun onError(exception: MsalException) {
                if (exception.message!!.contains(B2C_PASSWORD_CHANGE)) {
                    operationListener.onEvent(B2COperationResult(TAG, POLICY_TRIGGER_INTERACTIVE,
                        B2COperationState.PASSWORD_RESET))
                }
                else {
                    /* Failed to acquireToken */
                    Log.d(TAG, "Authentication failed: $exception")
                    if (exception is MsalClientException) {
                        /* Exception inside MSAL, more info inside MsalError.java */
                        operationListener.onEvent(
                            B2COperationResult(
                                TAG, POLICY_TRIGGER_INTERACTIVE,
                                B2COperationState.CLIENT_ERROR
                            )
                        )

                    } else if (exception is MsalServiceException) {
                        /* Exception when communicating with the STS, likely config issue */
                        operationListener.onEvent(
                            B2COperationResult(
                                TAG, POLICY_TRIGGER_INTERACTIVE,
                                B2COperationState.SERVICE_ERROR
                            )
                        )
                    }
                }
            }

            override fun onCancel() {
                /* User canceled the authentication */
                Log.d(TAG, "User cancelled login.")
                operationListener.onEvent(B2COperationResult(TAG, POLICY_TRIGGER_INTERACTIVE,
                    B2COperationState.USER_CANCELLED_OPERATION))
            }
        }

    /**
     * Callback used in for silent acquireToken calls.
     */
    private val authSilentCallback: SilentAuthenticationCallback
        private get() = object : SilentAuthenticationCallback {
            override fun onSuccess(authenticationResult: IAuthenticationResult) {
                /* Successfully got a token. */
                Log.d(TAG, "Successfully authenticated")

                /* Stores in memory the access token. Note: refresh token managed by MSAL */
                var subject = B2CUser.getSubjectFromAccount(authenticationResult.account)

                synchronized(authResults) {
                    authResults[subject!!] = authenticationResult
                }

                /* Signal operation completed */
                operationListener.onEvent(B2COperationResult(TAG, POLICY_TRIGGER_SILENTLY,
                    B2COperationState.SUCCESS))

            }

            override fun onError(exception: MsalException) {
                /* Failed to acquireToken */
                Log.d(TAG, "Authentication failed: $exception")
                if (exception is MsalClientException) {
                    /* Exception inside MSAL, more info inside MsalError.java */
                    operationListener.onEvent(B2COperationResult(TAG, POLICY_TRIGGER_SILENTLY,
                        B2COperationState.CLIENT_ERROR))
                } else if (exception is MsalServiceException) {
                    /* Exception when communicating with the STS, likely config issue */
                    operationListener.onEvent(B2COperationResult(TAG, POLICY_TRIGGER_SILENTLY,
                        B2COperationState.SERVICE_ERROR))
                } else if (exception is MsalUiRequiredException) {
                    /* Tokens expired or no session, retry with interactive */
                    operationListener.onEvent(B2COperationResult(TAG, POLICY_TRIGGER_SILENTLY,
                        B2COperationState.USER_INTERACTION_REQUIRED))
                }
            }
        }

    private fun setHostAndTenantFromAuthority(authority: Authority) {
        var parts = authority.authorityURL.toString().split(Regex("https://|/"))
        hostName = parts[1]
        tenantName = parts[2]
        Log.d(TAG, "host: $hostName, tenant: $tenantName")
    }

    private fun getAuthorityFromPolicyName(policyName: String) : String{
        return "https://$hostName/$tenantName/$policyName/"
    }
}