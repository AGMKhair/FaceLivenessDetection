import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:facelivenessdetection/core/constants/string_constants.dart';

Future<bool> requestCameraPermission(BuildContext context) async {
  final status = await Permission.camera.request();
  if (status.isGranted) {
    return true;
  } else {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:  Text(StringConstants.CAMERA_PERMISSION_REQUIRED),
        content: const Text(StringConstants.CAMERA_PERMISSION_REQUIRED_MESSAGE),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(StringConstants.CANCEL),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text(StringConstants.CAMERA_PERMISSION_DENIED_FOREVER_SETTINGS),
          ),
        ],
      ),
    );
    return false;
  }
}