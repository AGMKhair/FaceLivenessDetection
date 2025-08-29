import 'dart:io';

import 'package:facelivenessdetection/core/utils/image.dart';
import 'package:facelivenessdetection/features/face_liveness/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';


class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  List<File> capturedImages = [];

  @override
  void initState() {
    super.initState();
    _loadSavedImages();
  }

  Future<void> _loadSavedImages() async {
    final images = await getSavedImages();
    if (!mounted) return;
    setState(() {
      capturedImages = images;
    });
  }

  @override
  Widget build(BuildContext context) {
   return Scaffold(
      appBar: AppBar(
        title: const Text('Captured Images'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: capturedImages.isEmpty
            ? const Center(
          child: Text(
            'No images captured yet.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: capturedImages.length,
          itemBuilder: (context, index) {
            final imagePath = capturedImages[index];
            final file = File(imagePath.path);
            final dateTime = file.lastModifiedSync();
            final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    file,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                ),
                title: Text(
                  'Image ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(formattedDate),
                onTap: () {
                  // Optional: Navigate to a full-screen image view
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.file(file),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
