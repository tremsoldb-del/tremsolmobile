import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../auth/signin_screen.dart';
import 'job_comment.dart';

class JobDetailsPage extends StatefulWidget {
  final String jobId;

  const JobDetailsPage({super.key, required this.jobId});

  @override
  _JobDetailsPageState createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  bool isLiked = false;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    checkIfLiked();
    checkLoginStatus();
    incrementViewCount();
  }

  void checkIfLiked() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return; // If not signed in, skip checking likes

    DocumentSnapshot jobItem = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .get();

    List likes = jobItem['likes'] ?? [];
    if (likes.contains(userId)) {
      setState(() {
        isLiked = true;
      });
    }
  }

  void checkLoginStatus() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      isLoggedIn = user != null; // Update status based on login state
    });
  }

  void toggleLike() async {
    if (!isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const SignInScreen()), // Navigate to login page
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final jobRef =
        FirebaseFirestore.instance.collection('jobs').doc(widget.jobId);

    if (isLiked) {
      await jobRef.update({
        'likes': FieldValue.arrayRemove([userId])
      });
    } else {
      await jobRef.update({
        'likes': FieldValue.arrayUnion([userId])
      });
    }

    setState(() {
      isLiked = !isLiked;
    });
  }

  void navigateToComments() {
    if (!isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const SignInScreen()), // Navigate to login page
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobCommentPage(widget.jobId),
      ),
    );
  }

  void incrementViewCount() async {
    final jobRef =
        FirebaseFirestore.instance.collection('jobs').doc(widget.jobId);
    await jobRef.update({
      'viewscount': FieldValue.increment(1),
    });
  }

  void shareJobDetails(String jobTitle, String jobLocation, String jobSalary) {
    final shareText = '''
🚀 Discover Amazing Opportunities!
  
💼 Job Title: $jobTitle
📍 Location: $jobLocation
💰 Salary: $jobSalary

✨ Don't miss out! Download our app to explore more exciting jobs and take the next step in your career. 🌟
    ''';

    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Details',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Job not found"));
          }

          var job = snapshot.data!;
          String jobTitle = job['jobtitle'];
          String jobLocation = job['joblocation'];
          String jobSalary = job['jobsalary'];
          String jobCompany = job['jobcompany'] ?? 'Unknown Company';
          int viewCount = job['viewscount'] ?? 0;

          DateTime? closingDate;
          String formattedClosingDate = 'Not specified';

          if (job['vacancyclosingdate'] != null) {
            final timestamp = job['vacancyclosingdate'] as Timestamp;
            closingDate = timestamp.toDate();
            formattedClosingDate = DateFormat.yMMMMd().format(closingDate);
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: CachedNetworkImage(
                        imageUrl: job['image'] ?? '',
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.35,
                        fit: BoxFit.contain, // Preserves logo proportions
                        placeholder: (context, url) => Container(
                          height: MediaQuery.of(context).size.height * 0.25,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: MediaQuery.of(context).size.height * 0.25,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.business, // Appropriate for company logos
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      jobTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      jobCompany,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          jobLocation,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.visibility, color: Colors.grey, size: 18),
                            const SizedBox(width: 4),
                            Text('$viewCount Views',
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${job['jobsalary']}/Month',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.red, // More attention-grabbing than grey
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Closes: $formattedClosingDate',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black, // Stronger than grey
                          ),
                        ),
                      ],
                    ),
              
                    const SizedBox(height: 16),
              
                    //added 25 06 2025
                    ExpandableDescription(
                      description:
                          job['jobdescription'] ?? 'No description available',
                    ),
              
                    /*  Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          job['jobdescription'] ?? 'No description available',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),*/
              
                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          //amended 10 04 2025
                          IconButton(
                            icon: const Icon(Icons.comment),
                            onPressed: () {
                              var firebaseUser = FirebaseAuth.instance.currentUser;
                              if (firebaseUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please sign in or create an account to view or post comments'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return; // Prevent navigation
                              }
              
                              // If user is signed in, navigate
                              navigateToComments();
                            },
                          ),
              
                          /*
                          IconButton(
                            icon: FaIcon(
                              FontAwesomeIcons.shareFromSquare,
                              // color: Colors.white,
                              //size: 18, // Set icon size to 16
                            ),
                            onPressed: () =>
                                shareJobDetails(jobTitle, jobLocation, jobSalary),
                          ),*/
                          //amended 10 04 2025
                          IconButton(
                            icon: Icon(
                              isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt,
                              color: isLiked ? Colors.red : Colors.black,
                              size: 28,
                            ),
                            onPressed: () {
                              var firebaseUser = FirebaseAuth.instance.currentUser;
                              if (firebaseUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please sign in or create an account to like this job'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return; // Prevent like toggle if not signed in
                              }
              
                              toggleLike(); // Proceed if signed in
                            },
                          ),
                        ],
                      ),
                    ),
                    /* ElevatedButton(
                      onPressed: () {
                        // Implement job application logic here
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),*/
              
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      onPressed: () {
                        shareJobDetails(jobTitle, jobLocation, jobSalary);
                      },
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Center the text and icon
                        children: [
                          IconButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.shareFromSquare,
                              color: Colors.white,
                              size: 20, // Set icon size to 16
                            ),
                            onPressed: () {},
                          ),
              
                          const SizedBox(width: 8), // Space between icon and text
                          const Text(
                            'Share Style',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ExpandableDescription extends StatefulWidget {
  final String description;

  const ExpandableDescription({super.key, required this.description});

  @override
  _ExpandableDescriptionState createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _isExpanded = false;
  final int _maxLinesCollapsed = 3;

  @override
  Widget build(BuildContext context) {
    final hasOverflow =
        widget.description.split('\n').length > _maxLinesCollapsed ||
        widget.description.length > 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          firstChild: Text(
            widget.description,
            maxLines: _maxLinesCollapsed,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          secondChild: Text(
            widget.description,
            style: const TextStyle(fontSize: 14),
          ),
          crossFadeState:
              _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        ),
        if (hasOverflow)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.blue,
              size: 18,
            ),
            label: Text(
              _isExpanded ? 'Less' : 'More',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
