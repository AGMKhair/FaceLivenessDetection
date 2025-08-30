import 'dart:io';
import 'package:facelivenessdetection/core/utils/image.dart';
import 'package:flutter/material.dart';
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
        title: const Text(
          'Captured Images',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor:  Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 3,
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
            : GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 images per row
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: capturedImages.length,
          itemBuilder: (context, index) {
            final file = capturedImages[index];
            final dateTime = file.lastModifiedSync();
            final formattedDate =
            DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);

            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.black,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.file(file),
                        const SizedBox(height: 10),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15)),
                        child: Image.file(
                          file,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Image ${index + 1}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
