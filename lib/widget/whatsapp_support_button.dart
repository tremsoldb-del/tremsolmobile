import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppSupportButton extends StatefulWidget {
  const WhatsAppSupportButton({super.key});

  @override
  State<WhatsAppSupportButton> createState() =>
      _WhatsAppSupportButtonState();
}

class _WhatsAppSupportButtonState extends State<WhatsAppSupportButton> {
  bool _isOpening = false;

  Future<void> _openWhatsApp() async {
    if (_isOpening) return;

    setState(() {
      _isOpening = true;
    });

    try {
      final document = await FirebaseFirestore.instance
          .collection('settings')
          .doc('doc7')
          .get();

      final data = document.data();

      if (!document.exists || data == null) {
        throw Exception('Support settings were not found.');
      }

      final rawPhoneNumber =
          (data['company_phone'] ?? '').toString().trim();

      // WhatsApp links require digits only:
      // +233241317756 becomes 233241317756.
      final phoneNumber =
          rawPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      if (phoneNumber.isEmpty) {
        throw Exception('The WhatsApp support number is empty.');
      }

      const supportMessage =
          'Hello Tremsol Support, I need assistance with the Tremsol app.';

      final whatsappUri = Uri.https(
        'wa.me',
        '/$phoneNumber',
        <String, String>{
          'text': supportMessage,
        },
      );

      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('WhatsApp could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open WhatsApp support. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Contact Tremsol support on WhatsApp',
      child: FloatingActionButton(
        heroTag: 'tremsolWhatsAppSupportButton',
        onPressed: _isOpening ? null : _openWhatsApp,
        tooltip: 'WhatsApp Support',
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        elevation: 7,
        shape: const CircleBorder(),
        child: _isOpening
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const FaIcon(
                FontAwesomeIcons.whatsapp,
                size: 31,
              ),
      ),
    );
  }
}