import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection lensDirection;

  FacePainter({
    required this.faces,
    required this.imageSize,
    this.lensDirection = CameraLensDirection.front,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    for (var face in faces) {
      final left = translateX(face.boundingBox.left, size, imageSize);
      final top = translateY(face.boundingBox.top, size, imageSize);
      final right = translateX(face.boundingBox.right, size, imageSize);
      final bottom = translateY(face.boundingBox.bottom, size, imageSize);

      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);

      // Draw contours
      void drawContour(FaceContourType type) {
        final contour = face.contours[type];
        if (contour?.points != null) {
          for (var point in contour!.points) {
            canvas.drawCircle(Offset(translateX(point.x.toDouble(), size, imageSize),
                translateY(point.y.toDouble(), size, imageSize)), 1, paint);
          }
        }
      }

      drawContour(FaceContourType.face);
      drawContour(FaceContourType.leftEyebrowTop);
      drawContour(FaceContourType.leftEyebrowBottom);
      drawContour(FaceContourType.rightEyebrowTop);
      drawContour(FaceContourType.rightEyebrowBottom);
      drawContour(FaceContourType.leftEye);
      drawContour(FaceContourType.rightEye);
      drawContour(FaceContourType.upperLipTop);
      drawContour(FaceContourType.upperLipBottom);
      drawContour(FaceContourType.lowerLipTop);
      drawContour(FaceContourType.lowerLipBottom);
      drawContour(FaceContourType.noseBridge);
      drawContour(FaceContourType.noseBottom);
      drawContour(FaceContourType.leftCheek);
      drawContour(FaceContourType.rightCheek);
    }
  }

  double translateX(double x, Size canvasSize, Size imageSize) {
    return x * canvasSize.width / imageSize.width;
  }

  double translateY(double y, Size canvasSize, Size imageSize) {
    return y * canvasSize.height / imageSize.height;
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return faces != oldDelegate.faces;
  }
}