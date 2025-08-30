import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:facelivenessdetection/features/face_liveness/presentation/widgets/face_painter.dart';
import 'package:facelivenessdetection/features/face_liveness/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class LivenessScreen extends ConsumerStatefulWidget {
  const LivenessScreen({super.key});

  @override
  ConsumerState<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends ConsumerState<LivenessScreen> {
  StreamSubscription? _imageStreamSubscription;
  StreamController<CameraImage>? _streamController;
  bool _isStreaming = false;
  CameraController? controller;
  DateTime _lastFrameTime = DateTime.now();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initCamera();
    });
  }

  Future<void> _initCamera() async {
    ref.read(livenessProvider.notifier).startDetection();

    final cameras = await availableCameras();
    final front = cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
    );
    controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();
    if (!mounted) return;

    _streamController = StreamController<CameraImage>.broadcast();
    _startImageStream();

  }

  Future<void> _stopImageStream() async {
    if (!_isStreaming) return;
    _isStreaming = false;

    try {
      await controller?.stopImageStream();
    } catch (_) {}
  }


  void _startImageStream() {
    if (_isStreaming) return;
    _isStreaming = true;

    final detector = ref.watch(faceDetectorProvider);

    controller!.startImageStream((CameraImage image) async {
      final now = DateTime.now();
      if (now.difference(_lastFrameTime).inMilliseconds > 10) {
        _lastFrameTime = now;

        if (!mounted) return;
          final livenessState = ref.watch(livenessProvider);
        if (livenessState != LivenessState.detecting) return;

        final inputImage = _inputImageFromCameraImage(image, controller!.description);
        if (inputImage == null) return;

        try {
          final faces = await detector.processImage(inputImage);
          if (!mounted) return;
          ref.read(livenessProvider.notifier).processFaces(faces);
        } catch (e) {
          debugPrint("Error in face detection: $e");
        }
      }
    });
  }



  @override
  void dispose() {
    _stopImageStream();
    _streamController?.close();
    controller?.dispose();
    super.dispose();
  }

  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription camera) {
    final rotation =
    InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    if (Platform.isIOS) {
      final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.bgra8888;
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    if (Platform.isAndroid) {
      final nv21 = _convertYUV420toNV21(image);
      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    return null;
  }

  Uint8List _convertYUV420toNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final ySize = width * height;
    final uvSize = width * height ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    // Y plane
    for (int i = 0; i < height; i++) {
      nv21.setRange(
        i * width,
        i * width + width,
        image.planes[0].bytes,
        i * image.planes[0].bytesPerRow,
      );
    }

    // U+V plane
    int uvIndex = ySize;
    for (int j = 0; j < height ~/ 2; j++) {
      for (int i = 0; i < width ~/ 2; i++) {
        nv21[uvIndex++] = image.planes[2].bytes[j * image.planes[2].bytesPerRow + i * uvPixelStride]; // V
        nv21[uvIndex++] = image.planes[1].bytes[j * image.planes[1].bytesPerRow + i * uvPixelStride]; // U
      }
    }

    return nv21;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Liveness Detection')),
      body: Consumer(
        builder: (context, ref, child) {
          final cameraAsync = ref.watch(cameraControllerProvider);
          final livenessState = ref.watch(livenessProvider);
          final error = ref.watch(errorMessageProvider);
          final faces = ref.watch(currentFacesProvider);
          final capturesTaken = ref.watch(capturesTakenProvider);
          final capturesNeeded = ref.watch(capturesNeededProvider);

          return cameraAsync.when(
            data: (controller) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  // CustomPaint(
                  //   painter: FacePainter(
                  //     faces: faces,
                  //     imageSize: Size(
                  //       controller.value.previewSize?.height ?? 0,
                  //       controller.value.previewSize?.width ?? 0,
                  //     ),
                  //   ),
                  // ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (error.isNotEmpty)
                            Text(error,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 18)),
                          if (livenessState == LivenessState.detecting)
                            const Text('Blink eyes and turn head left/right',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18)),
                          if (livenessState == LivenessState.detecting)
                            Text('Captured: $capturesTaken / $capturesNeeded',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  // if (livenessState == LivenessState.success ||
                  //     livenessState == LivenessState.failure)
                  //   Center(
                  //     child: Text(
                  //       livenessState == LivenessState.success
                  //           ? 'Liveness Verified!'
                  //           : 'Verification Failed',
                  //       style: TextStyle(
                  //         color: livenessState == LivenessState.success
                  //             ? Colors.green
                  //             : Colors.red,
                  //         fontSize: 24,
                  //       ),
                  //     ),
                  //   ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
      ),
    );
  }
}