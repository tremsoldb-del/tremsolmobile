import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdsDebugPage extends StatefulWidget {
  const AdsDebugPage({super.key});

  @override
  _AdsDebugPageState createState() => _AdsDebugPageState();
}

class _AdsDebugPageState extends State<AdsDebugPage> {
  List<Map<String, dynamic>> adsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    try {
      print('🔍 Fetching ads collection...');
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('ads')
          .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ No documents found in ads collection.');
      } else {
        print('✅ ${snapshot.docs.length} ads found:');
        for (var doc in snapshot.docs) {
          print('📝 ${doc.id}: ${doc.data()}');
        }
        setState(() {
          adsList = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (e) {
      print('❌ Error fetching ads: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ads Debug Page')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : adsList.isEmpty
              ? const Center(child: Text('No ads found in the collection.'))
              : ListView.builder(
                  itemCount: adsList.length,
                  itemBuilder: (context, index) {
                    final ad = adsList[index];
                    return Card(
                      margin: const EdgeInsets.all(12),
                      child: ListTile(
                        title: Text(ad['image'] ?? 'No image URL'),
                        subtitle: Text('Priority: ${ad['priority'] ?? 'N/A'}'),
                      ),
                    );
                  },
                ),
    );
  }
}
