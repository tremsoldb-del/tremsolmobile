import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'jobdetailsscreen.dart';

class ViewAllJobs extends StatefulWidget {
  const ViewAllJobs({super.key});

  @override
  _ViewAllJobsState createState() => _ViewAllJobsState();
}

class _ViewAllJobsState extends State<ViewAllJobs> {
  String selectedCategory = 'All'; // Default to 'All' categories
  TextEditingController searchController = TextEditingController();
  List<String> jobCategories = ['All']; // Initialize with 'All' category

  @override
  void initState() {
    super.initState();
    _fetchJobCategories();
  }

  // Fetch job categories from the Firestore collection
  Future<void> _fetchJobCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('jobs').get();

    // Extract categories and avoid duplicates
    final categories = <String>{};
    for (var doc in snapshot.docs) {
      final job = doc.data();
      final category = job['jobcategory'];
      if (category != null) {
        categories.add(category);
      }
    }

    setState(() {
      jobCategories = [
        'All',
        ...categories
      ]; // Add 'All' as the first category
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "All Jobs",
          style: TextStyle(
            color: Colors.blue,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Category Dropdown
                DropdownButton<String>(
                  value: selectedCategory,
                  icon: const Icon(Icons.filter_list, color: Colors.blue),
                  elevation: 16,
                  style: const TextStyle(color: Colors.blue),
                  underline: Container(
                    height: 2,
                    color: Colors.blue,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedCategory = newValue!;
                    });
                  },
                  items: jobCategories
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 16),
                // Search TextField
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (query) {
                      setState(() {}); // Rebuild to update search results
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
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('jobcategory',
                      isEqualTo: selectedCategory == 'All'
                          ? null
                          : selectedCategory) // Filter by category
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No jobs available'));
                }

                // Filter and sort jobs
                final jobList = snapshot.data!.docs.where((doc) {
                  final job = doc.data() as Map<String, dynamic>;
                  return job['jobtitle']
                          ?.toLowerCase()
                          .contains(searchController.text.toLowerCase()) ??
                      false;
                }).toList();

                // Sort jobs: open jobs first
                jobList.sort((a, b) {
                  final jobA = a.data() as Map<String, dynamic>;
                  final jobB = b.data() as Map<String, dynamic>;
                  final isJobAOpen = !(jobA['vacancyclosingdate'] as Timestamp)
                      .toDate()
                      .isBefore(DateTime.now());
                  final isJobBOpen = !(jobB['vacancyclosingdate'] as Timestamp)
                      .toDate()
                      .isBefore(DateTime.now());

                  // Open jobs appear first
                  if (isJobAOpen && !isJobBOpen) return -1;
                  if (!isJobAOpen && isJobBOpen) return 1;
                  return 0;
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: jobList.length,
                  itemBuilder: (context, index) {
                    final job = jobList[index].data() as Map<String, dynamic>;
                    final jobId = jobList[index].id;
                    final isJobOpen = !(job['vacancyclosingdate'] as Timestamp)
                        .toDate()
                        .isBefore(DateTime.now());

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JobDetailsPage(jobId: jobId),
                          ),
                        );
                      },
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          side: const BorderSide(color: Colors.blue, width: 1),
                        ),
                        margin: const EdgeInsets.only(bottom: 16.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: NetworkImage(
                                  job['image'] ??
                                      'https://via.placeholder.com/150',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      job['jobtitle'] ?? 'No Title',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      job['jobcompany'] ?? 'No Company',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      job['joblocation'] ?? 'No Location',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Salary: ${job['jobsalary'] ?? 'Not specified'}",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isJobOpen ? 'Vacancy Open' : 'Closed',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isJobOpen
                                            ? Colors.green
                                            : Colors.red,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
