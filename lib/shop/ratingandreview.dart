import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReviewsPage extends StatelessWidget {
  final String productId;
  final bool canPostReview;

  const ReviewsPage({
    super.key,
    required this.productId,
    this.canPostReview = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ratings & Reviews',
          style: TextStyle(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ratingreview')
                    .where('productId', isEqualTo: productId)
                   // .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
        
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No reviews available.'));
                  }
        
                  final reviews = snapshot.data!.docs;
        
                  return ListView.builder(
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final reviewData =
                          reviews[index].data() as Map<String, dynamic>;
                      final userId = reviewData['userId'] ?? '';
        
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .get(),
                        builder: (context, userSnapshot) {
                          String reviewerName = 'Anonymous';
        
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data()
                                as Map<String, dynamic>;
                            reviewerName = userData['username'] ??
                                userData['fullname'] ??
                                'Anonymous';
                          }
        
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Card(
                              child: ListTile(
                                title: Text(
                                  reviewerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: List.generate(5, (i) {
                                        final ratingVal =
                                            (reviewData['rating'] ?? 0).round();
                                        return Icon(
                                          i < ratingVal
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.orange,
                                          size: 20,
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      reviewData['review'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
        
            if (canPostReview)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    _showReviewDialog(context, currentUser);
                  },
                  child: const Text('Add Your Review'),
                ),
              )
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, User? currentUser) {
    final TextEditingController reviewController = TextEditingController();
    double rating = 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Your Review',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rate the product:',
                        style: TextStyle(fontSize: 16)),
                    Slider(
                      value: rating,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: rating.toString(),
                      onChanged: (value) {
                        setState(() {
                          rating = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Write your review:',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reviewController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Share your experience...',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String review = reviewController.text.trim();

                if (rating == 0 || review.isEmpty) {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please provide both a rating and review.'),
                        backgroundColor: Colors.black,
                      ),
                    );
                  });
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('ratingreview')
                      .add({
                    'productId': productId,
                    'userId': currentUser?.uid ?? '',
                    'rating': rating,
                    'review': review,
                    'timestamp': Timestamp.now(),
                  });

                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Review added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  });
                } catch (e) {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving review: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}
