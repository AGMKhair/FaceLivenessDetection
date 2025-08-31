import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:facelivenessdetection/core/constants/string_constants.dart';
import 'package:facelivenessdetection/core/utils/image.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lottie/lottie.dart';

class FaceSetupScreen extends StatefulWidget {
  final CameraDescription camera;
  const FaceSetupScreen({super.key, required this.camera});

  @override
  State<FaceSetupScreen> createState() => _FaceSetupScreenState();
}

class _FaceSetupScreenState extends State<FaceSetupScreen> {
  late CameraController _controller;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  double _progress = 0.0;
  bool outOfFrame = false;
  bool leftTurnDetected = false;
  bool rightTurnDetected = false;
  bool blinkDetected = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high, enableAudio: false);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableContours: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _controller.initialize();
    await _controller.startImageStream(_processCameraImage);
    setState(() {});
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
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

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        final face = faces.first;
        final screenCenter = MediaQuery.of(context).size.center(Offset.zero);
        final circleRadius = MediaQuery.of(context).size.width * 0.5;

        // Face center point
        final faceCenter = Offset(
          face.boundingBox.center.dx,
          face.boundingBox.center.dy,
        );

        final distance = (faceCenter - screenCenter).distance;
        final threshold1 = 280;
        final threshold2 = 180;

        if (distance < threshold1 && distance > threshold2) {
          print(_progress);
          if(_progress == .30 && !leftTurnDetected)
            {

              final eulerY = face.headEulerAngleY ?? 0.0;
              if (eulerY > 20)  {
                leftTurnDetected = true;
                _capturePhoto();
              }

            }else if(_progress == .60 && !rightTurnDetected) {
            final eulerY = face.headEulerAngleY ?? 0.0;
            if (eulerY < -20) {rightTurnDetected = true;
            _capturePhoto();
            }
            }else if(_progress == .80 && !blinkDetected) {
            if ((face.leftEyeOpenProbability ?? 1.0) < 0.3 &&
                (face.rightEyeOpenProbability ?? 1.0) < 0.3) {
              blinkDetected = true;
              _capturePhoto();
            }

          }else {
            _increaseProgress();
          }
        } else {
          _resetProgress();
        }
      } else {
        _resetProgress();
      }
    } catch (e) {
      debugPrint("Face detect error: $e");
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

  void _increaseProgress() {

      setState(() {
        if (_progress < 1.0) {
          _progress += 0.05;
          setState(() => errorMessage = StringConstants.FACE_PROCESSSING );
        } else {
          setState(() => errorMessage = StringConstants.FACE_REGISTRATION_COMPLETE);
        }
    });
  }

  void _resetProgress() {
    setState(() =>  errorMessage = "Please stay in the circle");
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  bool get _shouldBlur {
    return _progress == .3 || _progress == .6 || _progress == .80;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          /// Camera Preview
          ClipOval(
            child: SizedBox(
              width: 280,
              height: 280,
              child: _controller.value.isInitialized
                  ? CameraPreview(_controller)
                  : const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),

          if (_shouldBlur)
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 280,
                  height: 280,
                  color: Colors.black.withOpacity(0.3), // dim effect
                ),
              ),
            ),

          // Circular Progress Indicator
          ClipOval(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade800,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ),

          // White Circle Border
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54, width: 2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Show animation/image on progress
          if (_progress == .3)
            ClipOval(
              child: Image.asset(
                "assets/animations/arrow_left.gif",
                width: 100,
                height: 100,
              ),
            ),
          if (_progress == .6)
            ClipOval(
              child: Lottie.asset(
                "assets/animations/arrow_right.json",
                width: 100,
                height: 100,
                repeat: true,
              ),
            ),
          if (_progress == .80)
            ClipOval(
              child: Lottie.asset(
                "assets/animations/blink.json",
                width: 120,
                height: 120,
                repeat: true,
              ),
            ),

          Positioned(
            bottom: 120,
            child: Text(
              "${(_progress * 100).round()}%",
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          Positioned(
            bottom: 60,
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
