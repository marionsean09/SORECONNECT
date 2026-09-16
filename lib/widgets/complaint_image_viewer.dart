import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// ============================================================
// COMPLAINT IMAGE THUMBNAIL
// Tappable thumbnail (decoded from a base64 string stored in
// Firestore) that opens the image full-screen.
// ============================================================

class ComplaintImageThumbnail extends StatelessWidget {
  const ComplaintImageThumbnail({
    super.key,
    required this.imageBase64,
    this.height = 160,
  });

  final String imageBase64;
  final double height;

  void _openFullScreen(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(imageBytes: bytes),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;

    try {
      bytes = base64Decode(imageBase64);
    } catch (_) {
      bytes = null;
    }

    if (bytes == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
        ),
      );
    }

    final imageBytes = bytes;

    return GestureDetector(
      onTap: () => _openFullScreen(context, imageBytes),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          imageBytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: height,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// FULL SCREEN IMAGE VIEWER
// ============================================================

class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Complaint Photo'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.memory(
            imageBytes,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 60,
              );
            },
          ),
        ),
      ),
    );
  }
}
