import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

class SchemaScreen extends StatefulWidget {
  const SchemaScreen({super.key});

  @override
  _SchemaScreenState createState() => _SchemaScreenState();
}

class _SchemaScreenState extends State<SchemaScreen> {
  final TextEditingController _collectionController = TextEditingController();
  String _output = "";
  final Map<String, Set<String>> _schema = {};

  void getSchema(String collectionName) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      // Fetch the first few documents from the collection
      QuerySnapshot snapshot =
          await firestore.collection(collectionName).limit(10).get();

      // Clear previous schema
      _schema.clear();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        data.forEach((key, value) {
          String type = value.runtimeType.toString();
          _schema.putIfAbsent(key, () => {}).add(type);
        });
      }

      // Format the inferred schema for display
      String formattedSchema = _schema.entries
          .map((entry) => "${entry.key}: ${entry.value.join(", ")}")
          .join("\n");

      setState(() {
        _output =
            "Schema for collection '$collectionName':\n\n$formattedSchema";
      });
    } catch (e) {
      setState(() {
        _output = "Error fetching schema: $e";
      });
    }
  }

  Future<void> exportToCSVAndSendEmail() async {
    if (_schema.isEmpty) {
      setState(() {
        _output = "No schema to export. Please fetch a schema first.";
      });
      return;
    }

    // Convert schema to a list of rows for CSV
    List<List<String>> rows = [
      ["Field", "Type"]
    ];
    _schema.forEach((field, types) {
      rows.add([field, types.join(", ")]);
    });

    String csvData = const ListToCsvConverter().convert(rows);

    try {
      // Save the CSV file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/schema.csv";
      final file = File(filePath);
      await file.writeAsString(csvData);

      setState(() {
        _output = "CSV file exported successfully at $filePath";
      });

      try {
        // Attempt to send email
        final Email email = Email(
          body: 'Please find the exported schema CSV attached.',
          subject: 'Exported Schema',
          recipients: [
            'ecdshelp@gmail.com'
          ], // Replace with the recipient's email
          attachmentPaths: [filePath],
          isHTML: false,
        );

        await FlutterEmailSender.send(email);
        setState(() {
          _output = "Email sent successfully!";
        });
      } catch (e) {
        // If email sending fails, fallback to sharing
        setState(() {
          _output = "Email client not available. Offering share options.";
        });
        Share.shareFiles([filePath], text: 'Exported Schema CSV');
      }
    } catch (e) {
      setState(() {
        _output = "Error exporting to CSV: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firestore Schema Viewer"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _collectionController,
              decoration: const InputDecoration(
                labelText: "Collection Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                String collectionName = _collectionController.text.trim();
                if (collectionName.isNotEmpty) {
                  getSchema(collectionName);
                } else {
                  setState(() {
                    _output = "Please enter a collection name.";
                  });
                }
              },
              child: const Text("Get Schema"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: exportToCSVAndSendEmail,
              child: const Text("Export to CSV"),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _output,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
