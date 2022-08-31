# flutter_azure_b2c

A flutter library to handle the Azure B2C authentication protocol.
This library is based on native implementation of MSAL for each target platform
and aims to provide a common interface to easily manage Azure AD B2C authentication
process for flutter developer.

There is a common interface that permits to handle the authentication and authorization
process and it is entirely designed to work with the Azure B2C service. For each platform
is then implemented a B2CProvider that permits to adapt the common interface to the selected
device.


Aim of this library is NOT to replicate the entire MSAL library in flutter and never
will be. The entire capabilities of MSAL are not exposed. Furthermore, the library is
not designed to work with any OAuth2 or OpenID provider. It may work or may not but it
is not guaranteed. 

Actual limitation:
* Some platform still miss an implementation as there are out of our business scope
at the moment. All contributions are appreciated! ;)


## Installation

Add flutter_azure_b2c to your pubspec:
```yaml
    dependencies:
        flutter_azure_b2c: any # or the latest version on Pub
```

### Android

* Configure your app to use the INTERNET and ACCESS_NETWORK_STATE permission in the manifest file located in <project root>/android/app/src/main/AndroidManifest.xml:
```xml
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.INTERNET"/>
```

* Add also an intent filter in the manifest file to capture redirect from MSAL service:
```xml
    <!--Intent filter to capture System Browser or Authenticator calling back to our app after sign-in-->
    <activity
        android:name="com.microsoft.identity.client.BrowserTabActivity">
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="msauth"
                android:host="<YOUR_PACKAGE_NAME>"
                android:path="<YOUR_BASE64_URL_ENCODED_PACKAGE_SIGNATURE>" />
        </intent-filter>
    </activity>
```
For more information see https://github.com/AzureAD/microsoft-authentication-library-for-android.

* Prepare a JSON configuration file (named `auth_config.json` in the example code) for AzureB2C initialization(`AzureB2C.init("auth_config"));`) in <project root>/android/app/main/res/raw/ following this template:
```json
    {
        "client_id" : "<application (client) id>",
        "redirect_uri" : "msauth://<YOUR_PACKAGE_NAME>/<YOUR_BASE64_URL_ENCODED_PACKAGE_SIGNATURE>",
        "account_mode" : "<MULTIPLE|SINGLE>",
        "broker_redirect_uri_registered": false,
        "authorities": [
            {
                "type": "B2C",
                "authority_url": "https://<youractivedirectoryname>.b2clogin.com/<youractivedirectoryname>.onmicrosoft.com/<sign_in_up_policy_name>/",
                "default": true
            },
            {
                "type": "B2C",
                "authority_url": "https://<youractivedirectoryname>.b2clogin.com/<youractivedirectoryname>.onmicrosoft.com/<other_policy e.g. reset_pass>/"
            }
        ],
        "default_scopes": [
            "https://<youractivedirectoryname>.onmicrosoft.com/<application (server) id>/<API name>"
        ]
    }
```
See https://docs.microsoft.com/en-us/azure/active-directory/develop/tutorial-v2-android for information about how to configure your B2C application and generate <YOUR_BASE64_URL_ENCODED_PACKAGE_SIGNATURE>.

### IOS

* Prepare a JSON configuration file (named `auth_config.json` in the example code) for AzureB2C initialization(`AzureB2C.init("auth_config"));`) in <project root>/ios/Resources following this template:
```json
    {
        "client_id" : "<application (client) id>",
        "redirect_uri" : "msauth://<YOUR_PACKAGE_NAME>/<YOUR_BASE64_URL_ENCODED_PACKAGE_SIGNATURE>",
        "account_mode" : "<MULTIPLE|SINGLE>",
        "broker_redirect_uri_registered": false,
        "authorities": [
            {
                "type": "B2C",
                "authority_url": "https://<youractivedirectoryname>.b2clogin.com/<youractivedirectoryname>.onmicrosoft.com/<sign_in_up_policy_name>/",
                "default": true
            },
            {
                "type": "B2C",
                "authority_url": "https://<youractivedirectoryname>.b2clogin.com/<youractivedirectoryname>.onmicrosoft.com/<other_policy e.g. reset_pass>/"
            }
        ],
        "default_scopes": [
            "https://<youractivedirectoryname>.onmicrosoft.com/<application (server) id>/<API name>"
        ]
    }
```
See https://github.com/AzureAD/microsoft-authentication-library-for-objc for information about how to configure your B2C application.

### Web

* Add a CDN dependecy in your index.html file:
```html
  <script type="text/javascript" src="https://alcdn.msauth.net/browser/<MSAL_VERSION>/js/msal-browser.min.js"></script>
```
Web implementation depends from the package msal_js (for more information see https://pub.dev/packages/msal_js), depending on the version imported follow the package documentation in order to select the correct <MSAL_VERSION>.

For more information about MSAL web see https://github.com/AzureAD/microsoft-authentication-library-for-js/tree/dev/lib/msal-browser#usage.


* Prepare a JSON configuration file (named `auth_config.json` in the example code) for AzureB2C initialization(`AzureB2C.init("auth_config"));`) in <project root>/web/asset/ following this template:
```json
    {
        "client_id" : "<application (client) id>",
        "redirect_uri" : "<your app domain>",
        "cache_location": "<localStorage|sessionStorage>",
        "interaction_mode": "<popup|redirect>",
        "authorities": [
            {
                "type": "B2C",
                "authority_url": "https://<youractivedirectoryname>.b2clogin.com/<youractivedirectoryname>.onmicrosoft.com/<sign_in_up_policy_name>/",
                "default": true
            },
            {
                "type": "B2C",
                "authority_url": "https://<youractivedirectoryname>.b2clogin.com/<youractivedirectoryname>.onmicrosoft.com/<other_policy e.g. reset_pass>/"
            }
        ],
        "default_scopes": [
            "https://<youractivedirectoryname>.onmicrosoft.com/<application (server) id>/<API name>"
        ]
    }
```

## Run the example

In <root>/example/lib/main.dart there is a simple demonstration app. In order to test your setting you can follow these next steps:

* Configure a B2C app following Microsoft documentation (see https://docs.microsoft.com/en-us/azure/active-directory/develop/msal-overview).

* Prepare a configuration file using previous templates to match the init (e.g. `AzureB2C.init("auth_config"));`):
    * Android: 
        * path: android/app/main/res/raw/
    * IOS:
        * path: ios/Resources/
    * Web:
        * path: web/assets/

* launch the application:
    * Android: 
        * flutter launch
        * choose an android emulator or device
    * IOS: 
        * flutter launch
        * choose an ios emulator or device
    * Web:
        * flutter launch -d chrome --web-port <port>
        * Note: choose port number according to the redirect uri registered in the B2C app.

In VS Code you can create a launch configuration like the one below:
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "touchscreen",
            "request": "launch",
            "type": "dart",
            "args": ["--web-port", "<REDIRECT_PORT>"]
        },
        {
            "name": "touchscreen (profile mode)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "profile",
            "args": ["--web-port", "<REDIRECT_PORT>"]
        },
        {
            "name": "touchscreen (release mode)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "release",
            "args": ["--web-port", "<REDIRECT_PORT>"]
        }
    ]
}
```


