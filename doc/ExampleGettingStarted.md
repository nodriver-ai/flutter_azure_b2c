# flutter_azure_b2c example

Demonstrates how to use the flutter_azure_b2c plugin.

## Getting Started

* Configure a B2C app following Microsoft documentation.
* Prepare a configuration file:
    * Android: 
        * path: android/app/main/res/raw/
        * template:
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
        * launch:
            * flutter launch
            * choose an android emulator or device
    * Web:
        * path: web/assets/
        * template:
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
        * launch:
            * flutter launch -d chrome --web-port <port>
            * Note: choose port number according to the redirect uri registered in the B2C app.

