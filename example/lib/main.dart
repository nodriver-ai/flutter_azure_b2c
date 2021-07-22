import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_azure_b2c/flutter_azure_b2c.dart';
import 'package:flutter_azure_b2c/B2COperationResult.dart';
import 'package:flutter_azure_b2c/B2CConfiguration.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _retdata = "";
  List<String>? _subjects;
  B2CConfiguration? _configuration;

  @override
  void initState() {
    super.initState();

    // It is possible to register callbacks in order to handle return values
    // from asynchronous calls to the plugin
    AzureB2C.registerCallback(B2COperationSource.INIT, (result) async {
      if (result.reason == B2COperationState.SUCCESS) {
        _configuration = await AzureB2C.getConfiguration();
      }
    });

    // Important: Remeber to handle redirect states (if you want to support
    // the web platform with redirect method) and init the AzureB2C plugin
    // before the material app starts.
    AzureB2C.handleRedirectFuture().then((_) => AzureB2C.init("auth_config"));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Azure AD B2C Plugin example app'),
        ),
        body: Container(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                TextButton(
                    onPressed: () async {
                      // you can just perform calls to the AzureB2C plugin to
                      // handle the B2C protocol (e.g. acquire, refresh tokens
                      // or sign out).
                      var data = await AzureB2C.policyTriggerInteractive(
                          _configuration!.defaultAuthority.policyName,
                          _configuration!.defaultScopes!,
                          null);
                      setState(() {
                        _retdata = data;
                      });
                    },
                    child: Text("LogIn")),
                TextButton(
                    onPressed: () async {
                      var subjects = await AzureB2C.getSubjects();
                      var info = await AzureB2C.getUserInfo(subjects![0]);
                      setState(() {
                        _subjects = subjects;
                        _retdata = json.encode(info);
                      });
                    },
                    child: Text("UserInfo")),
              ],
            ),
            Row(
              children: [
                TextButton(
                    onPressed: () async {
                      var token = await AzureB2C.getAccessToken(_subjects![0]);
                      setState(() {
                        _retdata = json.encode(token);
                      });
                    },
                    child: Text("AccessToken")),
                TextButton(
                    onPressed: () async {
                      var data = await AzureB2C.policyTriggerSilently(
                        _subjects![0],
                        _configuration!.defaultAuthority.policyName,
                        _configuration!.defaultScopes!,
                      );
                      setState(() {
                        _retdata = data;
                      });
                    },
                    child: Text("Refresh")),
                TextButton(
                    onPressed: () async {
                      var data = await AzureB2C.signOut(_subjects![0]);
                      setState(() {
                        _retdata = data;
                      });
                    },
                    child: Text("LogOut")),
              ],
            ),
            Text(_retdata)
          ],
        )),
      ),
    );
  }
}
