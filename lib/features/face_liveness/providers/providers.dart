import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

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

final faceDetectorProvider = Provider<FaceDetector>((ref) {
  final options = FaceDetectorOptions(
    enableContours: true,
    enableClassification: true,
    enableLandmarks: true,
    performanceMode: FaceDetectorMode.fast,
  );
  return FaceDetector(options: options);
});

enum LivenessState { idle, detecting, blink, turnLeft, turnRight, success, failure }

class LivenessNotifier extends Notifier<LivenessState> {
  String errorMessage = '';
  List<String> capturedImages = [];
  List<Face> currentFaces = [];
  Timer? captureTimer;
  int capturesNeeded = Random().nextInt(2) + 4; // 4-5 photos
  int capturesTaken = 0;
  bool blinkDetected = false;
  bool leftTurnDetected = false;
  bool rightTurnDetected = false;

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
    _startRandomCaptureTimer();
  }

  void processFaces(List<Face> faces) {
    currentFaces = faces;
    if (faces.isEmpty) {
      errorMessage = 'No face found.';
      state = LivenessState.failure;
      return;
    } else if (faces.length > 1) {
      errorMessage = 'Multiple faces detected. Please stay alone in frame.';
      state = LivenessState.failure;
      return;
    }

    final face = faces.first;
    // Blink detection
    if ((face.leftEyeOpenProbability ?? 1.0) < 0.3 && (face.rightEyeOpenProbability ?? 1.0) < 0.3) {
      blinkDetected = true;
    }

    // Head movement
    final eulerY = face.headEulerAngleY ?? 0.0;
    if (eulerY > 20) {
      rightTurnDetected = true;
    } else if (eulerY < -20) {
      leftTurnDetected = true;
    }

    // Check if at least two actions detected
    int actionsCompleted = 0;
    if (blinkDetected) actionsCompleted++;
    if (leftTurnDetected) actionsCompleted++;
    if (rightTurnDetected) actionsCompleted++;

    if (actionsCompleted >= 2 && capturesTaken >= capturesNeeded) {
      state = LivenessState.success;
    }
  }

  void _startRandomCaptureTimer() {
    captureTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (capturesTaken < capturesNeeded && state == LivenessState.detecting) {
        final controller = await ref.read(cameraControllerProvider.future);
        final xFile = await controller.takePicture();
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '_');
        final path = '${dir.path}/face_$timestamp.jpg';
        await File(xFile.path).copy(path);
        capturedImages.add(path);
        capturesTaken++;
      }
    });
  }

  void stopDetection() {
    captureTimer?.cancel();
    state = LivenessState.idle;
  }
}

final livenessProvider = NotifierProvider<LivenessNotifier, LivenessState>(() => LivenessNotifier());

final errorMessageProvider = Provider<String>((ref) => ref.watch(livenessProvider.notifier).errorMessage);
final capturedImagesProvider = Provider<List<String>>((ref) => ref.watch(livenessProvider.notifier).capturedImages);
final currentFacesProvider = Provider<List<Face>>((ref) => ref.watch(livenessProvider.notifier).currentFaces);
final capturesTakenProvider = Provider<int>((ref) => ref.watch(livenessProvider.notifier).capturesTaken);
final capturesNeededProvider = Provider<int>((ref) => ref.watch(livenessProvider.notifier).capturesNeeded);

