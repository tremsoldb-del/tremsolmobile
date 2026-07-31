import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailTestPage extends StatefulWidget {
  const EmailTestPage({super.key});
  static const route = '/dev/email-test';
  @override
  State<EmailTestPage> createState() => _EmailTestPageState();
}

class _EmailTestPageState extends State<EmailTestPage> {
  final _formKey = GlobalKey<FormState>();
  final _orderNumberCtrl =
      TextEditingController(text: 'TEST-${DateTime.now().millisecondsSinceEpoch}');
  final _userNameCtrl = TextEditingController(text: 'Tester');
  final _recipientCtrl = TextEditingController(); // optional override

  bool _useCurrentUser = true;
  bool _sending = false;
  String? _currentUserEmail;

  // last error text for quick copy/debug
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (_currentUserEmail?.isNotEmpty == true) {
      _recipientCtrl.text = _currentUserEmail!;
    }
  }

  @override
  void dispose() {
    _orderNumberCtrl.dispose();
    _userNameCtrl.dispose();
    _recipientCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendTestEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _lastError = null;
    });

    try {
      // 1) Load SMTP + template settings from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('doc3')
          .get();

      if (!doc.exists) {
        return _fail('settings/doc3 not found. Create it with SMTP fields.');
      }
      final data = doc.data()!;

      // Required sender info
      final fromEmail = (data['email'] ?? '').toString().trim();         // e.g., support@tremsol.com
      final password  = (data['pass'] ?? '').toString();                 // mailbox password (keep in Firestore)
      if (fromEmail.isEmpty || password.isEmpty) {
        return _fail('Missing sender email or password in settings/doc3.');
      }

      // Optional branding/templates
      final appName   = (data['appname'] ?? 'App').toString();
      final subjectT  = (data['subject'] ?? 'Order Confirmation - #').toString();
      final bodyT     = (data['body'] ??
          'Hello {username},<br><br>'
          'This is a test email for order <b>{orderid}</b>.<br><br>'
          'Regards,<br>{appname} Team').toString();

      // SMTP config (Namecheap Private Email defaults)
      final smtpHost     = (data['smtp_host'] ?? 'mail.privateemail.com').toString();
      final smtpPortRaw  = data['smtp_port']; // can be null/int/string
      final smtpSSLRaw   = data['smtp_ssl'];  // can be null/bool
      final smtpUser     = (data['smtp_username'] ?? fromEmail).toString();

      // Recipient
      String recipient = '';
      if (_useCurrentUser) {
        recipient = FirebaseAuth.instance.currentUser?.email ?? '';
      } else {
        recipient = _recipientCtrl.text.trim();
      }
      if (recipient.isEmpty) {
        return _fail('Recipient is empty. Sign in a user or enter a custom email.');
      }

      // Build message (HTML body)
      final orderNumber = _orderNumberCtrl.text.trim();
      final userName    = _userNameCtrl.text.trim();
      final subject     = '$subjectT$orderNumber';
      final body        = bodyT
          .replaceAll('{username}', userName)
          .replaceAll('{orderid}', orderNumber)
          .replaceAll('{appname}', appName);

      final message = Message()
        ..from = Address(fromEmail, appName)
        ..recipients.add(recipient)
        ..subject = subject
        ..html = body;

      // 2) Build SMTP server with sensible defaults + fallback
      // Prefer STARTTLS on 587; if that fails with "connection reset", auto-try 465 SSL.
      final int? portFromDoc = _coerceInt(smtpPortRaw);
      final bool? sslFromDoc = _coerceBool(smtpSSLRaw);

      // Primary attempt: 587 STARTTLS (no ssl)
      final primary = SmtpServer(
        smtpHost,
        port: portFromDoc ?? 587,
        username: smtpUser,
        password: password,
        ssl: sslFromDoc ?? false,   // for 587 use false (STARTTLS)
      );

      try {
        final report = await send(message, primary);
        _ok('✅ Email sent to $recipient via ${primary.host}:${primary.port}');
        // ignore: avoid_print
        print('Send report (587/STARTTLS): $report');
        return;
      } catch (e) {
        // ignore: avoid_print
        print('Primary send failed (${primary.host}:${primary.port}): $e');
        // If the doc explicitly set a port/ssl and it failed, still try a known-good fallback
      }

      // Fallback attempt: 465 implicit SSL
      final fallback = SmtpServer(
        smtpHost,
        port: 465,
        username: smtpUser,
        password: password,
        ssl: true,
      );
      try {
        final report = await send(message, fallback);
        _ok('✅ Email sent to $recipient via ${fallback.host}:${fallback.port}');
        // ignore: avoid_print
        print('Send report (465/SSL): $report');
        return;
      } catch (e) {
        // ignore: avoid_print
        print('Fallback send failed (${fallback.host}:${fallback.port}): $e');
        return _fail('Send failed on both 587 (STARTTLS) and 465 (SSL). See console for details.');
      }
    } on MailerException catch (e) {
      _fail('Mailer error: ${e.message}');
      // ignore: avoid_print
      print('MailerException: $e\nProblems: ${e.problems}');
    } catch (e) {
      _fail('Error: $e');
      // ignore: avoid_print
      print('Error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int? _coerceInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  bool? _coerceBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().toLowerCase().trim();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return null;
    }

  void _ok(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _fail(String msg) {
    _lastError = msg;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Test (No Payment)'),
        backgroundColor: const Color(0xFF002A5C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Send a test email using SMTP settings in Firestore (settings/doc3). '
                'No orders/payments are created.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Send to current user (FirebaseAuth.currentUser.email)'),
                subtitle: Text(
                  _currentUserEmail?.isNotEmpty == true
                      ? _currentUserEmail!
                      : 'No signed-in user email found',
                ),
                value: _useCurrentUser,
                onChanged: (v) => setState(() => _useCurrentUser = v),
              ),
              if (!_useCurrentUser) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _recipientCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Custom recipient email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (!_useCurrentUser && (v == null || v.trim().isEmpty)) {
                      return 'Enter a recipient email or enable "current user".';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _orderNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Order number (for subject/body placeholders)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Order number is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'User name (for body placeholder)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'User name is required' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _sendTestEmail,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_sending ? 'Sending…' : 'Send Test Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF002A5C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_lastError != null)
                Text('Last error: $_lastError', style: small?.copyWith(color: Colors.red)),
              const SizedBox(height: 8),
              Text(
                'Expected Firestore fields (collection: settings / doc: doc3):\n'
                '• email (e.g., support@tremsol.com)\n'
                '• pass (mailbox password)\n'
                '• appname (e.g., Tremsol) [optional]\n'
                '• subject [optional]\n'
                '• body [optional, HTML allowed; uses {username}, {orderid}, {appname}]\n'
                '• smtp_host [default: mail.privateemail.com]\n'
                '• smtp_port [default: 587]\n'
                '• smtp_ssl [default: false for 587; true if you set port 465]\n'
                '• smtp_username [default: email]',
                style: small,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
