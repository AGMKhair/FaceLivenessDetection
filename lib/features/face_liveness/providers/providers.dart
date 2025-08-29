import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

// Camera controller provider
final camerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

final cameraControllerProvider = FutureProvider<CameraController>((ref) async {
  final cameras = await ref.watch(camerasProvider.future);
  final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
  );
  final controller = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
  await controller.initialize();
  return controller;
});

// Face detector provider
final faceDetectorProvider = Provider<FaceDetector>((ref) {
  final options = FaceDetectorOptions(
    enableContours: true,
    enableClassification: true,
    enableLandmarks: true,
    performanceMode: FaceDetectorMode.fast,
  );
  return FaceDetector(options: options);
});

// Liveness state notifier
enum LivenessState { idle, detecting, blink, turnLeft, turnRight, success, failure }

class LivenessNotifier extends Notifier<LivenessState> {
  String errorMessage = '';
  List<String> capturedImages = [];
  List<Face> currentFaces = [];
  int capturesNeeded = 2; // blink করে ৩টা ছবি নেবে
  int capturesTaken = 0;

  bool blinkDetected = false;
  bool leftTurnDetected = false;
  bool rightTurnDetected = false;

  bool _isCapturing = false;

  @override
  LivenessState build() => LivenessState.idle;

  void startDetection() {
    state = LivenessState.detecting;
    errorMessage = '';
    capturedImages.clear();
    capturesTaken = 0;
    blinkDetected = false;
    leftTurnDetected = false;
    rightTurnDetected = false;
  }

  void processFaces(List<Face> faces) {
    currentFaces = faces;
    if (faces.isEmpty) {
      errorMessage = 'No face found.';
      // state = LivenessState.failure;
      return;
    } else if (faces.length > 1) {
      errorMessage = 'Multiple faces detected. Please stay alone in frame.';
      // state = LivenessState.failure;
      return;
    }

    final face = faces.first;

    // Blink detection
    final leftProb = face.leftEyeOpenProbability ?? 1.0;
    final rightProb = face.rightEyeOpenProbability ?? 1.0;

    if (leftProb < 0.3 && rightProb < 0.3) {
      // Blink moment detected
      if (!blinkDetected) {
        blinkDetected = true;
        _captureOnBlink(); // <-- capture when blink happens
      }
    } else {
      blinkDetected = false; // reset so next blink also works
    }

    // Head movement detection
    final eulerY = face.headEulerAngleY ?? 0.0;
    if (eulerY > 20) {
      rightTurnDetected = true;
    } else if (eulerY < -20) {
      leftTurnDetected = true;
    }

    // Check completion
    int actionsCompleted = 0;
    if (leftTurnDetected) actionsCompleted++;
    if (rightTurnDetected) actionsCompleted++;

    if (actionsCompleted >= 1 && capturesTaken >= capturesNeeded) {
      state = LivenessState.success;
      stopDetection();
    }
  }

  Future<void> _captureOnBlink() async {
    if (_isCapturing || capturesTaken >= capturesNeeded) return;
    _isCapturing = true;

    try {
      final controller = await ref.read(cameraControllerProvider.future);
      if (!controller.value.isInitialized) return;

      final xFile = await controller.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '_');
      final path = '${dir.path}/blink_$timestamp.jpg';
      await File(xFile.path).copy(path);

      capturedImages.add(path);
      capturesTaken++;
    } catch (e) {
      errorMessage = "Capture error: $e";
    } finally {
      _isCapturing = false;
    }
  }

  void stopDetection() {
    state = LivenessState.idle;
  }
}


final livenessProvider = NotifierProvider<LivenessNotifier, LivenessState>(() => LivenessNotifier());

// Providers for accessing notifier properties
final errorMessageProvider = Provider<String>((ref) => ref.watch(livenessProvider.notifier).errorMessage);
final capturedImagesProvider = Provider<List<String>>((ref) => ref.watch(livenessProvider.notifier).capturedImages);
final currentFacesProvider = Provider<List<Face>>((ref) => ref.watch(livenessProvider.notifier).currentFaces);
final capturesTakenProvider = Provider<int>((ref) => ref.watch(livenessProvider.notifier).capturesTaken);
final capturesNeededProvider = Provider<int>((ref) => ref.watch(livenessProvider.notifier).capturesNeeded);


// import 'dart:async';
// import 'dart:io';
// import 'dart:math';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:path_provider/path_provider.dart';
//
// // Camera controller provider
// final camerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
//   return await availableCameras();
// });
//
// final cameraControllerProvider = FutureProvider<CameraController>((ref) async {
//   final cameras = await ref.watch(camerasProvider.future);
//   final frontCamera = cameras.firstWhere(
//         (camera) => camera.lensDirection == CameraLensDirection.front,
//   );
//   final controller = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
//   await controller.initialize();
//   return controller;
// });
//
// // Face detector provider
// final faceDetectorProvider = Provider<FaceDetector>((ref) {
//   final options = FaceDetectorOptions(
//     enableContours: true,
//     enableClassification: true,
//     enableLandmarks: true,
//     performanceMode: FaceDetectorMode.fast,
//   );
//   return FaceDetector(options: options);
// });
//
// // Liveness state notifier
// enum LivenessState { idle, detecting, blink, turnLeft, turnRight, success, failure }
//
// class LivenessNotifier extends Notifier<LivenessState> {
//   String errorMessage = '';
//   List<String> capturedImages = [];
//   List<Face> currentFaces = [];
//   Timer? captureTimer;
//   int capturesNeeded = Random().nextInt(2) + 4; // 4-5 photos
//   int capturesTaken = 0;
//   bool blinkDetected = false;
//   bool leftTurnDetected = false;
//   bool rightTurnDetected = false;
//   bool _isCapturing = false; // Flag to prevent overlapping captures
//
//   @override
//   LivenessState build() => LivenessState.idle;
//
//   void startDetection() {
//     state = LivenessState.detecting;
//     errorMessage = '';
//     capturedImages.clear();
//     capturesTaken = 0;
//     blinkDetected = false;
//     leftTurnDetected = false;
//     rightTurnDetected = false;
//     _startRandomCaptureTimer();
//   }
//
//   void processFaces(List<Face> faces) {
//     currentFaces = faces;
//     if (faces.isEmpty) {
//       errorMessage = 'No face found.';
//       state = LivenessState.failure;
//       return;
//     } else if (faces.length > 1) {
//       errorMessage = 'Multiple faces detected. Please stay alone in frame.';
//       state = LivenessState.failure;
//       return;
//     }
//
//     final face = faces.first;
//     // Blink detection
//     if ((face.leftEyeOpenProbability ?? 1.0) < 0.3 && (face.rightEyeOpenProbability ?? 1.0) < 0.3) {
//       blinkDetected = true;
//     }
//
//     // Head movement
//     final eulerY = face.headEulerAngleY ?? 0.0;
//     if (eulerY > 20) {
//       rightTurnDetected = true;
//     } else if (eulerY < -20) {
//       leftTurnDetected = true;
//     }
//
//     // Check if at least two actions detected
//     int actionsCompleted = 0;
//     if (blinkDetected) actionsCompleted++;
//     if (leftTurnDetected) actionsCompleted++;
//     if (rightTurnDetected) actionsCompleted++;
//
//     if (actionsCompleted >= 2 && capturesTaken >= capturesNeeded) {
//       state = LivenessState.success;
//       stopDetection(); // Stop capturing when successful
//     }
//   }
//
//   void _startRandomCaptureTimer() {
//     if (capturesTaken >= capturesNeeded || state != LivenessState.detecting) {
//       captureTimer?.cancel();
//       return;
//     }
//
//     // Schedule the next capture with a random delay between 2-4 seconds
//     captureTimer = Timer(Duration(seconds: 2 + Random().nextInt(3)), () async {
//       if (_isCapturing || capturesTaken >= capturesNeeded || state != LivenessState.detecting) return;
//
//       _isCapturing = true;
//       try {
//         final controller = await ref.read(cameraControllerProvider.future);
//         final xFile = await controller.takePicture();
//         final dir = await getApplicationDocumentsDirectory();
//         final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '_');
//         final path = '${dir.path}/face_$timestamp.jpg';
//         await File(xFile.path).copy(path);
//         capturedImages.add(path);
//         capturesTaken++;
//       } catch (e) {
//         print('Error capturing image: $e');
//         // Optionally set error message
//         errorMessage = 'Failed to capture image.';
//       } finally {
//         _isCapturing = false;
//         // Schedule the next capture
//         _startRandomCaptureTimer();
//       }
//     });
//   }
//
//   void stopDetection() {
//     captureTimer?.cancel();
//     state = LivenessState.idle;
//   }
// }
//
// final livenessProvider = NotifierProvider<LivenessNotifier, LivenessState>(() => LivenessNotifier());
//
// // Providers for accessing notifier properties
// final errorMessageProvider = Provider<String>((ref) => ref.watch(livenessProvider.notifier).errorMessage);
// final capturedImagesProvider = Provider<List<String>>((ref) => ref.watch(livenessProvider.notifier).capturedImages);
// final currentFacesProvider = Provider<List<Face>>((ref) => ref.watch(livenessProvider.notifier).currentFaces);
// final capturesTakenProvider = Provider<int>((ref) => ref.watch(livenessProvider.notifier).capturesTaken);
// final capturesNeededProvider = Provider<int>((ref) => ref.watch(livenessProvider.notifier).capturesNeeded);