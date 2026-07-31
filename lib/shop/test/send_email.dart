import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailSender extends StatelessWidget {
  const EmailSender({super.key});

  Future<void> sendEmailFromFirestore() async {
    try {
      // 🔐 Step 1: Get SMTP email & password from Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('doc3')
          .get();

      if (!docSnapshot.exists) {
        print("Settings document not found.");
        return;
      }

      final data = docSnapshot.data()!;
      final String email = data['email'];
      final String password = data['pass'];

      // 📬 Step 2: Set up SMTP server
      final smtpServer = SmtpServer(
  'smtp.gmail.com',
  port: 465,
  username: email,
  password: password,
  ssl: true, // <- Use SSL
);


      // 📧 Step 3: Create email message
      final message = Message()
        ..from = Address(email, 'Tremsol')
        ..recipients.add('eganeboe@gmail.com')
        ..subject = 'Order Request'
        ..text = 'Hello, I would like to place an order.';

      // 🚀 Step 4: Send the email
      final sendReport = await send(message, smtpServer);
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      print('Failed to send email: $e');
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Email')),
      body: Center(
        child: ElevatedButton(
          onPressed: sendEmailFromFirestore,
          child: const Text('Send Email'),
        ),
      ),
    );
  }
}
