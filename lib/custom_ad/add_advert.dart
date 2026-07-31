import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateAdsCollectionPage extends StatelessWidget {
  const CreateAdsCollectionPage({super.key});

  // Function to create the ads collection with sample data
  Future<void> createAdsCollection() async {
    try {
      CollectionReference adsCollection =
          FirebaseFirestore.instance.collection('ads');

      // Sample ads data
      List<Map<String, dynamic>> sampleAds = [
        {
          'image': 'https://example.com/ad1.jpg',
          'redirect_url': '/product/123', // Replace with your app page route
          'priority': 1,
        },
        {
          'image': 'https://example.com/ad2.jpg',
          'redirect_url': '/product/456', // Replace with your app page route
          'priority': 2,
        },
        {
          'image': 'https://example.com/ad3.jpg',
          'redirect_url': 'https://external-link.com',
          'priority': 3,
        },
      ];

      // Adding sample ads to Firestore
      for (var ad in sampleAds) {
        await adsCollection.add(ad);
      }

      debugPrint('Ads collection created successfully with sample data.');
    } catch (e) {
      debugPrint('Error creating ads collection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Ads Collection'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await createAdsCollection();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Ads collection created successfully!')),
            );
          },
          child: const Text('Create Ads Collection'),
        ),
      ),
    );
  }
}
