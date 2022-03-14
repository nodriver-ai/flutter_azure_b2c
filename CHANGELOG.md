## 0.0.7
Bug fix:
* Web: solved issue when using REDIRECT method and user clicks forgot password and either INIT and PASSWORD_RESET callbacks are
triggered. Added session storage clean up before triggering PASSWORD_RESET callback to prevent interaction_in_progress MSAL error when calling the next authority.

## 0.0.6
Bug fix:
* Web: solved issue when user click back button from policy interactive that prevented further policies to be called

## 0.0.5
Bug fix:
* Resolved access token expireOn deserialization when locale was not en_US (same)

## 0.0.4
Bug fix:
* Resolved access token expireOn deserialization when locale was not en_US

## 0.0.3
Minor fixes:
* Mispelled enum for sign_out callback

## 0.0.2
Minor fixes:
* AzureB2C getters now check if value returned from channel is null


## 0.0.1

Intial release. Supported feauture:
* Platforms:
    * Android
    * Web
* Functionalities:
    * B2C user flow support:
        * Trigger any default or custom policy
        * Tokens storage
        * Sign out
        * (External providers (e.g. Google) not tested!)
            

