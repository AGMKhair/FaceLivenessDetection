import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:facelivenessdetection/features/face_liveness/presentation/widgets/face_painter.dart';
import 'package:facelivenessdetection/features/face_liveness/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';


class LivenessScreen extends ConsumerStatefulWidget {
  const LivenessScreen({super.key});

  @override
  ConsumerState<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends ConsumerState<LivenessScreen> {
  late StreamSubscription _imageStreamSubscription;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_hasStarted) {
        _hasStarted = true;
        final controller = await ref.read(cameraControllerProvider.future);
        ref.read(livenessProvider.notifier).startDetection();
        _startImageStream(ref, controller);
      }
    });
  }

  void _startImageStream(WidgetRef ref, CameraController controller) {
    final detector = ref.read(faceDetectorProvider);
    _imageStreamSubscription = controller.startImageStream((image) async {
      if (ref.read(livenessProvider) != LivenessState.detecting) return;

      final inputImage = _inputImageFromCameraImage(image, controller.description);
      if (inputImage == null) return;

      final faces = await detector.processImage(inputImage);
      ref.read(livenessProvider.notifier).processFaces(faces);
    }) as StreamSubscription;
  }

  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }


  @override
  void dispose() {
    _imageStreamSubscription.cancel();
    ref.read(livenessProvider.notifier).stopDetection();
    super.dispose();
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
                  CustomPaint(
                    painter: FacePainter(
                      faces: faces,
                      imageSize: Size(
                        controller.value.previewSize?.height ?? 0,
                        controller.value.previewSize?.width ?? 0,
                      ),
                    ),
                  ),
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
                  if (livenessState == LivenessState.success ||
                      livenessState == LivenessState.failure)
                    Center(
                      child: Text(
                        livenessState == LivenessState.success
                            ? 'Liveness Verified!'
                            : 'Verification Failed',
                        style: TextStyle(
                          color: livenessState == LivenessState.success
                              ? Colors.green
                              : Colors.red,
                          fontSize: 24,
                        ),
                      ),
                    ),
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