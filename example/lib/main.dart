import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gt4_flutter_plugin/gt4_flutter_plugin.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  /// 监控页面配置变化
  static const MethodChannel _demoChannel = MethodChannel('gt4_flutter_demo');
  final Gt4FlutterPlugin captcha = Gt4FlutterPlugin();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await Gt4FlutterPlugin.platformVersion ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    try {

      _demoChannel.setMethodCallHandler(_configurationChanged);

      captcha.addEventHandler(onSuccess: (Map<String, dynamic> message) async {
        debugPrint("Captcha onSuccess: " + message.toString());
        Fluttertoast.showToast(
          msg: message.toString(),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );

        bool state = message["state"];
        if (state == true) {
          // TODO
          // 发送 message["response"] 中的数据向服务端二次查询接口查询结果
          Map response = message["response"] as Map;
          await validateCaptchaResult(response
              .map((key, value) => MapEntry(key.toString(), value.toString())));
        } else {
          // 终端用户完成验证错误，自动重试
          debugPrint("Captcha 'onSuccess' state: $state");
        }
      }, onFailure: (Map<String, dynamic> message) async {
        debugPrint("Captcha onFailure: " + message.toString());
        Fluttertoast.showToast(
          msg: message.toString(),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
        );
        String code = message["code"];
        // TODO 处理验证中返回的错误
        if (Platform.isAndroid) {
          // Android 平台
          if (code == "-14460	") {
            // 验证会话已取消
          } else {
            // 更多错误码参考开发文档
            // https://docs.geetest.com/gt4/apirefer/errorcode/android
          }
        }

        if (Platform.isIOS) {
          // iOS 平台
        }
      });
    } catch (e) {
      debugPrint("Event handler exception " + e.toString());
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void verifyWithCaptcha() async {
    debugPrint("Start captcha. Current version: " + _platformVersion);
    captcha.verifyWithCaptcha("647f5ed2ed8acb4be36784e01556bb71");
  }

  Future<dynamic> _configurationChanged(MethodCall methodCall) async {
    debugPrint("Activity configurationChanged");
    return captcha.configurationChanged(methodCall.arguments.cast<String, dynamic>());
  }

  Future<dynamic> validateCaptchaResult(Map<String, String> result) async {
    debugPrint("Captcha validateCaptchaResult");
    String validate = "Your server url";
    final response = await http.post(Uri.parse(validate),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
        },
        body: result);
    if (response.statusCode == 200) {
      debugPrint("Validate response: " + response.body);
    } else {
      debugPrint("URL: $validate, Response statusCode: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Running on: $_platformVersion\n'),
              TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                    overlayColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.hovered)) {
                          return Colors.blue.withOpacity(0.04);
                        }
                        if (states.contains(MaterialState.focused) ||
                            states.contains(MaterialState.pressed)) {
                          return Colors.blue.withOpacity(0.12);
                        }
                        return null; // Defer to the widget's default.
                      },
                    ),
                  ),
                  onPressed: verifyWithCaptcha,
                  child: const Text('点击验证')),
            ],
          ),
        ),
      ),
    );
  }
}