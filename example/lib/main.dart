import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_azure_b2c/flutter_azure_b2c.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _retdata = "";
  List<String>? _subjects;

  @override
  void initState() {
    super.initState();
    var a = AzureB2C.handleRedirectFuture();
    // a.then((value) => AzureB2C.init());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Container(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                TextButton(
                    onPressed: () async {
                      var data = await AzureB2C.init();
                      setState(() {
                        _retdata = data!;
                      });
                    },
                    child: Text("Init")),
                TextButton(
                    onPressed: () async {
                      var data = await AzureB2C.policyTriggerInteractive();
                      setState(() {
                        _retdata = data!;
                      });
                    },
                    child: Text("LogIn")),
                TextButton(
                    onPressed: () async {
                      var subjects = await AzureB2C.getSubjects();
                      var info = await AzureB2C.getB2CUserInfo(subjects![0]);
                      setState(() {
                        _subjects = subjects;
                        _retdata = info.toString();
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
                        _retdata = token.toString();
                      });
                    },
                    child: Text("AccessToken")),
                TextButton(
                    onPressed: () async {
                      var data =
                          await AzureB2C.policyTriggerSilently(_subjects![0]);
                      setState(() {
                        _retdata = data!;
                      });
                    },
                    child: Text("Refresh")),
                TextButton(
                    onPressed: () async {
                      var data = await AzureB2C.signOut(_subjects![0]);
                      setState(() {
                        _retdata = data!;
                      });
                    },
                    child: Text("LogOut")),
              ],
            ),
            Text('Running on: $_platformVersion\n'),
            Text(_retdata)
          ],
        )),
      ),
    );
  }
}
