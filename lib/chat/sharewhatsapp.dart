import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class ShareToWhatsAppPage extends StatefulWidget {
  const ShareToWhatsAppPage({super.key});

  @override
  _ShareToWhatsAppPageState createState() => _ShareToWhatsAppPageState();
}

class _ShareToWhatsAppPageState extends State<ShareToWhatsAppPage> {
  String imagePath = ""; // Initialize with an empty string

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      // Copy image from assets to a local directory
      final byteData = await rootBundle
          .load('assets/logo.jpg'); // Add your image to the assets folder
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/logo.jpg');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      setState(() {
        imagePath = file.path;
      });
    } catch (e) {
      // Handle image loading failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load image: $e')),
      );
    }
  }

  void _shareToWhatsApp() async {
    if (imagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image not loaded yet!')),
      );
      return;
    }

    try {
      await Share.shareFiles(
        [imagePath],
        text: 'Check out this image!',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Image to WhatsApp'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            imagePath.isNotEmpty
                ? Image.file(File(imagePath), width: 200, height: 200)
                : const CircularProgressIndicator(), // Show a loader until the image is ready
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _shareToWhatsApp,
              child: const Text('Share to WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}
