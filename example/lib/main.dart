import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
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
    AzureB2C.registerCallback(B2COperationSource.INIT, (result) async {
      if (result == B2COperationState.SUCCESS) {
        _configuration = await AzureB2C.getConfiguration();
      }
    });
    AzureB2C.handleRedirectFuture()
        .then((value) => AzureB2C.init("auth_config"));
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
                      var data = await AzureB2C.policyTriggerInteractive(
                          _configuration!.defaultAuthority.policyName,
                          _configuration!.defaultScopes!
                          // <String>[
                          //   //you may ask user scopes here e.g.
                          //   //https://<hostname>/<server:client_id>/<scope_name>
                          //   "https://nodriverservices.onmicrosoft.com/9c26e9a7-4bcf-4fb0-9582-3552a70219fe/Irreo.APIv2.Access"
                          // ]
                          ,
                          null);
                      setState(() {
                        _retdata = data;
                      });
                    },
                    child: Text("LogIn")),
                TextButton(
                    onPressed: () async {
                      var subjects = await AzureB2C.getSubjects();
                      var info = await AzureB2C.getB2CUserInfo(subjects![0]);
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
                      var token =
                          await AzureB2C.getB2CAccessToken(_subjects![0]);
                      setState(() {
                        _retdata = json.encode(token);
                      });
                    },
                    child: Text("AccessToken")),
                TextButton(
                    onPressed: () async {
                      var data = await AzureB2C.policyTriggerSilently(
                          _configuration!.defaultAuthority.policyName,
                          _configuration!.defaultScopes!,
                          _subjects![0]);
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
