import 'package:facelivenessdetection/features/face_liveness/presentation/screen/liveness_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandlerScreen extends StatefulWidget {
  const PermissionHandlerScreen({super.key});

  @override
  State<PermissionHandlerScreen> createState() => _PermissionHandlerScreenState();
}

class _PermissionHandlerScreenState extends State<PermissionHandlerScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LivenessScreen()),
      );
    } else {
      // Handle permission denied
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text('Camera permission is needed for face detection.'),
          actions: [
            TextButton(onPressed: () => openAppSettings(), child: const Text('Open Settings')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
