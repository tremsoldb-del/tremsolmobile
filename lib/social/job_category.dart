import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'jobs_screen.dart';

class JobsByCategoryScreen extends StatelessWidget {
  final String category;

  const JobsByCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: Text("$category Jobs")),
      appBar: AppBar(
        title: Text(
          "$category Jobs",
          style: const TextStyle(fontSize: 18),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('jobcategory', isEqualTo: category)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("No jobs available in this category"));
          }

          final jobs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return JobTile(
                jobId: job['id'],
                company: job['jobcompany'],
                title: job['jobtitle'],
                timeAgo: _formatTimestamp(job['createdAt']),
                rate: job['jobsalary'],
                type: job['status'],
                location: job['jobcompany'],
                imageUrl: job['image'],
                viewCount: job['viewscount'].toString(),
                commentCount: job['commentcount'].toString(),
                jobcategory: job['jobcategory'].toString(),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inMinutes} minutes ago';
    }
  }
}
