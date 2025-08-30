import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final int rotation;

  FacePainter({required this.faces, required this.imageSize, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.greenAccent;

    for (final face in faces) {
      // bounding box
      canvas.drawRect(
        Rect.fromLTRB(
          face.boundingBox.left,
          face.boundingBox.top,
          face.boundingBox.right,
          face.boundingBox.bottom,
        ),
        paint,
      );

      for (final landmarkType in FaceLandmarkType.values) {
        final landmark = face.landmarks[landmarkType];
        if (landmark != null) {
          canvas.drawCircle(
            Offset(landmark.position.x as double, landmark.position.y as double),
            3,
            Paint()..color = Colors.redAccent,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
