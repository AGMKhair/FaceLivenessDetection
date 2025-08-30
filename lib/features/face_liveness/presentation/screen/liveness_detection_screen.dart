import 'package:camera/camera.dart';
import 'package:facelivenessdetection/core/utils/image.dart';
import 'package:facelivenessdetection/features/face_liveness/presentation/model/liveness_movement_enum.dart';
import 'package:facelivenessdetection/features/face_liveness/presentation/widgets/face_painter.dart';
import 'package:facelivenessdetection/features/face_liveness/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class LivenessDetectionScreen extends ConsumerStatefulWidget {
  final CameraDescription camera;

  const LivenessDetectionScreen({super.key, required this.camera});

  @override
  ConsumerState<LivenessDetectionScreen> createState() => _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends ConsumerState<LivenessDetectionScreen> {
  late CameraController _controller;
  late FaceDetector _faceDetector;
  late List<Face> _faces  = [];
  bool _isDetecting = false;
  bool _captured = false;
  bool blinkDetected = false;
  bool leftTurnDetected = false;
  bool rightTurnDetected = false;

  final allMovements = LivenessMovementEnum.values.toList();
  List<LivenessMovementEnum> challengeMovements = [];

  int currentIndex = 0;
  String currentMsg = "";
  String error = "";
  void onMovementDetected(LivenessMovementEnum detected) {
    if (!mounted) return;

    final expected = challengeMovements[currentIndex];
    if (detected == expected) {
      debugPrint("Correct movement: $detected");
      _capturePhoto();
      currentIndex++;

      if (currentIndex >= challengeMovements.length) {
        debugPrint("All movements completed!");
        setState(() => currentMsg = "All movements completed!");
        // Liveness verified
      } else {
        debugPrint("Next movement: ${challengeMovements[currentIndex]}");
        setState(() => currentMsg = "Next movement: ${challengeMovements[currentIndex].name}");
      }
    } else {
      debugPrint("Wrong movement: $detected, expected: $expected");
      ref.read(livenessProvider.notifier).errorMessage = "Wrong movement: $detected, expected: $expected";
      setState(() => error = "Wrong movement: ${detected.name}");    }
  }

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high, enableAudio: false);

    // _controller = CameraController(widget.camera, ResolutionPreset.medium, enableAudio: false);
    // _faceDetector = FaceDetector(
    //   options: FaceDetectorOptions(enableClassification: true),
    // );
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableContours: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate, // or fast
      ),
    );

    _initializeCamera();
  }


  Future<void> _initializeCamera() async {

    await _controller.initialize();
    await _controller.startImageStream(_processCameraImage);
    ref.read(livenessProvider.notifier).startDetection();
    allMovements.shuffle();
    challengeMovements = allMovements.take(7).toList();
    setState(() => currentMsg = "Correct movement: ${challengeMovements[0].name}");
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _captured) return;
    _isDetecting = true;

    try {


      final nv21bytes = convertYUV420ToNV21(image);


      final inputImage = InputImage.fromBytes(
        bytes: nv21bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(widget.camera.sensorOrientation) ?? InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      // final inputImage = InputImage.fromBytes(
      //   bytes: nv21bytes,
      //   metadata: InputImageMetadata(
      //     size: Size(image.width.toDouble(), image.height.toDouble()),
      //     rotation: InputImageRotationValue.fromRawValue(widget.camera.sensorOrientation) ?? InputImageRotation.rotation0deg,
      //     format: InputImageFormat.nv21,
      //     bytesPerRow: image.width,
      //   ),
      // );
      final faces = await _faceDetector.processImage(inputImage);
      setState(() {
        _faces = faces;
      });

      if (faces.isEmpty) {
        ref.read(livenessProvider.notifier).errorMessage = 'No face found.';
        setState(() => error = "No face found.");
        return;
      } else if (faces.length > 1) {
        ref.read(livenessProvider.notifier).errorMessage = 'Multiple faces detected. Please stay alone in frame.';
        setState(() => error = 'Multiple faces detected. Please stay alone in frame.');
        return;
      }
      else if (faces.isNotEmpty) {
        final face = faces.first;
        setState(() => error = "Face Processing.");
        // Example: blink detection
        if ((face.leftEyeOpenProbability ?? 1.0) < 0.3 &&
            (face.rightEyeOpenProbability ?? 1.0) < 0.3) {
          onMovementDetected(LivenessMovementEnum.blink);
        }

        // Head turn
        final eulerY = face.headEulerAngleY ?? 0.0;
        if (eulerY > 20) onMovementDetected(LivenessMovementEnum.turnRight);
        if (eulerY < -20) onMovementDetected(LivenessMovementEnum.turnLeft);

        // Head pitch
        final eulerX = face.headEulerAngleX ?? 0.0;
        if (eulerX > 15) onMovementDetected(LivenessMovementEnum.headDown);
        if (eulerX < -15) onMovementDetected(LivenessMovementEnum.headUp);

        // Mouth open/close
        for (final face in faces) {
          final mouthOpenProb = face.smilingProbability ?? 0.0;
          if (mouthOpenProb > 0.7) onMovementDetected(LivenessMovementEnum.mouthOpen);
          else if (mouthOpenProb < 0.3) onMovementDetected(LivenessMovementEnum.mouthClose);

        }

      }

    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      _isDetecting = false;
    }
  }




  Future<void> _capturePhoto() async {
    try {
      final file = await _controller.takePicture();
      saveCapturedImage(file);
    } catch (e) {
      debugPrint("Capture failed: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Liveness Detection',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        backgroundColor:  Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_controller),


          if(_controller.value.isInitialized)
          CustomPaint(
            painter: FacePainter(
              faces: _faces,
              imageSize: Size(_controller.value.previewSize!.width, _controller.value.previewSize!.height),
              rotation: widget.camera.sensorOrientation,
            ),
            child: Container(),
          ),

          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: challengeMovements.isNotEmpty
                            ? currentIndex / challengeMovements.length
                            : 0,
                        minHeight: 16,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        challengeMovements.length + 1,
                            (index) {
                          // Active / Inactive color
                          final isActive = index <= currentIndex;
                          return Text(
                            "$index",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.redAccent : Colors.black54,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error.isNotEmpty)
                    Text(
                      error,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    currentMsg,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
