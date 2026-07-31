import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class SharePage extends StatelessWidget {
  const SharePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Example'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.share),
          label: const Text('Share Content'),
          onPressed: () {
            _shareContent();
          },
        ),
      ),
    );
  }

  void _shareContent() {
    Share.share(
      'Check out this amazing Flutter app!',
      subject: 'Amazing Flutter App',
    );
  }
}
