import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdModalPage extends StatefulWidget {
  const AdModalPage({super.key});

  @override
  _AdModalPageState createState() => _AdModalPageState();
}

class _AdModalPageState extends State<AdModalPage> {
  Map<String, dynamic>? adData;

  @override
  void initState() {
    super.initState();
    _fetchAndShowAd();
  }

  // Fetch an ad from Firestore
  Future<void> _fetchAndShowAd() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('ads')
          .orderBy('priority')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          adData = snapshot.docs.first.data() as Map<String, dynamic>;
        });

        // Show the modal dialog
        _showAdModal();
      }
    } catch (e) {
      debugPrint('Error fetching ad: $e');
    }
  }

  void _showAdModal() {
    if (adData == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Stack(
            children: [
              // Ad content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (adData!['image'] != null)
                    Image.network(
                      adData!['image'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Special Offer!",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Handle redirection
                      if (adData!['redirect_url'] != null) {
                        Navigator.pushNamed(
                          context,
                          adData!['redirect_url'],
                        );
                      }
                    },
                    child: const Text('Learn More'),
                  ),
                ],
              ),
              // Close button
              Positioned(
                top: 8.0,
                right: 8.0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Modal Example'),
      ),
      body: const Center(
        child: Text('Content of the page'),
      ),
    );
  }
}
