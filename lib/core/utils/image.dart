import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

Future<File> saveCapturedImage(XFile file) async {
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/LivenessImages');

  // Folder না থাকলে create করে দাও
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '_');
  final path = '${folder.path}/liveness_$timestamp.jpg';

  // Copy file to folder
  final savedFile = await File(file.path).copy(path);
  return savedFile;
}


Future<List<File>> getSavedImages() async {
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/LivenessImages');

  if (!await folder.exists()) return [];

  final files = folder.listSync().whereType<File>().toList();
  // Sort by newest first
  files.sort((a, b) => b.path.compareTo(a.path));
  return files;
}


Uint8List convertYUV420ToNV21(CameraImage image) {
  final int width = image.width;
  final int height = image.height;
  final int size = width * height * 3 ~/ 2;

  // allocate buffer
  final Uint8List nv21 = Uint8List(size);

  // Fill Y plane
  final Uint8List yPlane = image.planes[0].bytes;
  nv21.setRange(0, yPlane.length, yPlane);

  // UV planes (U & V interleaved)
  final Uint8List uPlane = image.planes[1].bytes;
  final Uint8List vPlane = image.planes[2].bytes;

  int uvIndex = width * height;
  for (int i = 0; i < vPlane.length; i++) {
    if (uvIndex + 1 < nv21.length) {
      nv21[uvIndex++] = vPlane[i];
      nv21[uvIndex++] = uPlane[i];
    }
  }

  return nv21;
}

// Uint8List convertYUV420ToNV21(CameraImage image) {
//   final int width = image.width;
//   final int height = image.height;
//   final int uvRowStride = image.planes[1].bytesPerRow;
//   final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
//
//   final yBuffer = image.planes[0].bytes;
//   final uBuffer = image.planes[1].bytes;
//   final vBuffer = image.planes[2].bytes;
//
//   final nv21 = Uint8List(width * height + 2 * (width * height ~/ 4));
//
//   // Copy Y
//   int index = 0;
//   for (int i = 0; i < yBuffer.length; i++) {
//     nv21[index++] = yBuffer[i];
//   }
//
//   // Copy UV
//   for (int j = 0; j < height ~/ 2; j++) {
//     for (int i = 0; i < width ~/ 2; i++) {
//       nv21[index++] = vBuffer[j * uvRowStride + i * uvPixelStride];
//       nv21[index++] = uBuffer[j * uvRowStride + i * uvPixelStride];
//     }
//   }
//   return nv21;
// }
