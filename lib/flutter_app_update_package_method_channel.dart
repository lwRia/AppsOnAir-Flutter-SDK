import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flutter_app_update_package_platform_interface.dart';

/// An implementation of [FlutterAppUpdatePackagePlatform] that uses method channels.
class MethodChannelFlutterAppUpdatePackage
    extends FlutterAppUpdatePackagePlatform {
  /// The method channel used to interact with the native platform.

  bool _dialogOpen = false;

  @visibleForTesting
  final methodChannel = const MethodChannel('updateCheck/isUpdateAvailable');

  ///[context] is required to show dialog
  ///[isShowNative] is used to show [customWidget]
  ///[isShowNative] turn it off if you want to show your [customWidget]
  /// you can show your [customWidget] ui
  @override
  Future<void> initMethod(
    BuildContext context, {
    required String appId,
    bool showNativeUI = false,
    Widget? Function(Map<String, dynamic> response)? customWidget,
  }) async {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final result = await methodChannel.invokeMethod(
        'setApplicationID',
        {
          "AppId": appId,
          "showNativeUI": showNativeUI,
        },
      );
      if (result) {
        // ignore: use_build_context_synchronously
        _listenToNativeMethod(context);
        final appUpdateResponse = await _check();
        if (customWidget != null) {
          final widget = customWidget.call(appUpdateResponse);

          ///custom ui dialog
          if (!showNativeUI && widget != null) {
            _alertDialog(
              context: context,
              widget: widget,
            );
          }
        }
      }
    });
  }

  void _listenToNativeMethod(BuildContext context) {
    if (Platform.isIOS) {
      methodChannel.setMethodCallHandler((call) {
        switch (call.method) {
          case "openDialog":
            _showIgnorePointerDialog(context);
            break;
          case "closeDialog":
            if (_dialogOpen) {
              _dialogOpen = false;
              Navigator.pop(context);
            }
        }
        return Future.sync(() => _dialogOpen);
      });
    }
  }

  // while native dialog is open (in IOS), Flutter ui is still accessible
  // This dialog is solution for to prevent flutter ui access
  void _showIgnorePointerDialog(BuildContext context) {
    if (!_dialogOpen) {
      _dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        barrierColor: Colors.transparent,
        builder: (context) => Container(
          color: Colors.transparent,
        ),
      );
    }
  }

  void _alertDialog({
    required BuildContext context,
    required Widget widget,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            return false;
          },
          child: AlertDialog(
            content: widget,
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _check() async {
    String updateCheck = '';
    try {
      final result = await methodChannel.invokeMethod(
        'isUpdateAvailable',
      );
      if (result != null && result is String) {
        return Map<String, dynamic>.from(json.decode(result));
      }
      return Map<String, dynamic>.from(((result ?? {}) as Map));
    } on PlatformException catch (e) {
      updateCheck = "Failed to check for update: '${e.message}'.";
    }
    if (kDebugMode) {
      print(updateCheck);
    }
    return {"exception": updateCheck};
  }
}
