import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'job_category.dart';
import 'job_search.dart';
import 'job_seeall.dart';
import 'jobdetailsscreen.dart';

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});



String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return 'U';
  final first = parts.first.isNotEmpty ? parts.first[0] : '';
  final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
  final ini = (first + last).toUpperCase();
  return ini.isEmpty ? 'U' : ini;
}



  @override
  Widget build(BuildContext context) {
    // Get current user UID
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 1, 102, 185),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), // Back arrow
          onPressed: () {
            Navigator.of(context).pop(); // Go back to the previous page
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_list, color: Colors.white), // View All icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ViewAllJobs(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile and Greeting
            user != null
                ? // Replace your current StreamBuilder<DocumentSnapshot>(...) with this:
StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData || !snapshot.data!.exists) {
      return const Center(child: Text("User not found"));
    }

    final data = snapshot.data!.data() ?? <String, dynamic>{};

    // Safely read fields (try a few common variants)
    final photoUrl = (data['profilepic'] ??
            data['profilePic'] ??
            data['avatar'] ??
            data['photoURL'] ??
            '')
        .toString();

    final fullName = (data['fullname'] ?? data['fullName'] ?? '').toString();
    final username = (data['username'] ?? 'User').toString();
    final displayName = fullName.isNotEmpty ? fullName : username;

    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.white,
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty
              ? Text(
                  _initials(displayName),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          displayName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  },
)

                : Container(), // If user is not signed in
            const SizedBox(height: 20),
            // Header
            const Text(
              "Find a job that suits you",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            // Search bar
            TextField(
              readOnly: true, // Makes the TextField read-only
              onTap: () {
                // Navigate to JobSearchPage when tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JobSearchPage()),
                );
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                hintText: "Search job, title...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Job tags (dynamic from Firestore)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No job categories available"));
                }

                // Get distinct job categories from Firestore
                final jobCategories = snapshot.data!.docs
                    .map((doc) => doc['jobcategory'] as String)
                    .toSet()
                    .toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: jobCategories
                        .map((category) => JobTag(category))
                        .toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Recommended section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent jobs for you",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ViewAllJobs(),
                      ),
                    );
                  },
                  child: const Text(
                    "View all",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            // Job List populated from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jobs')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No jobs available"));
                  }

                  final jobs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount:
                        jobs.length > 10 ? 10 : jobs.length, // Limit to 10 jobs
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return JobTile(
                        jobId: job['id'],
                        company: job['jobcompany'],
                        title: job['jobtitle'],
                        timeAgo: _formatTimestamp(job['createdAt']),
                        rate: job['jobsalary'],
                        type: job[
                            'status'], // Assuming status represents job type
                        location: job['jobcompany'], // Updated field
                        imageUrl: job['image'],
                        viewCount: job['viewscount'].toString(),
                        commentCount: job['commentcount'].toString(),
                        jobcategory: job['jobcategory'].toString(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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

// JobTag Widget
class JobTag extends StatelessWidget {
  final String category;

  const JobTag(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobsByCategoryScreen(category: category),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category,
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// JobTile Widget
class JobTile extends StatelessWidget {
  final String jobId;
  final String company;
  final String title;
  final String timeAgo;
  final String rate;
  final String type;
  final String location;
  final String imageUrl;
  final String viewCount;
  final String commentCount;
  final String jobcategory;

  const JobTile({super.key, 
    required this.jobId,
    required this.company,
    required this.title,
    required this.timeAgo,
    required this.rate,
    required this.type,
    required this.location,
    required this.imageUrl,
    required this.viewCount,
    required this.commentCount,
    required this.jobcategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to Job Details Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailsPage(jobId: jobId),
            ),
          );
        },
        child: Row(
          children: [
           CircleAvatar(
  radius: 25,
  backgroundColor: Colors.grey.shade200,
  child: ClipOval(
    child: CachedNetworkImage(
      imageUrl: imageUrl,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: Icon(
          Icons.work, // Fashion-appropriate placeholder
          color: Colors.grey,
          size: 24,
        ),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Icon(
          Icons.error,
          color: Colors.red,
          size: 24,
        ),
      ),
    ),
  ),
),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$timeAgo | $rate | $type | $location",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.visibility, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(viewCount),
                      const SizedBox(width: 10),
                      const Icon(Icons.comment, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(commentCount),
                    ],
                  )
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}