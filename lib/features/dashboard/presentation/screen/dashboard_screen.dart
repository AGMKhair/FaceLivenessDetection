import 'package:camera/camera.dart';
import 'package:facelivenessdetection/core/constants/string_constants.dart';
import 'package:facelivenessdetection/core/utils/permissions.dart';
import 'package:facelivenessdetection/features/face_liveness/presentation/screen/liveness_detection_screen.dart';
import 'package:facelivenessdetection/features/face_liveness/presentation/screen/liveness_screen.dart';
import 'package:facelivenessdetection/features/images/presentation/images_screen.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.blue.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Face Liveness Detection',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verify your identity with ease',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () async {
                    if (await requestCameraPermission(context)) {
                      List<CameraDescription>? cameras;
                      cameras = await availableCameras();
                      final front = cameras!.firstWhere((c) => c.lensDirection == CameraLensDirection.front,);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LivenessDetectionScreen(camera: front),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.blue.shade900,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                   StringConstants.START_VERIFICATION,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) =>  ImagesScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    StringConstants.SEE_IMAGES,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}