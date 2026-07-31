import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'jobdetailsscreen.dart';

class JobSearchPage extends StatefulWidget {
  const JobSearchPage({super.key});

  @override
  _JobSearchPageState createState() => _JobSearchPageState();
}

class _JobSearchPageState extends State<JobSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allResults = [];
  List<DocumentSnapshot> _filteredResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchJobs();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterResults();
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
    });

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('jobs')
        .orderBy('jobtitle')
        .get();

    setState(() {
      _allResults = snapshot.docs;
      _filteredResults = List.from(_allResults);
      _isLoading = false;
    });
  }

  void _filterResults() {
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredResults = List.from(_allResults);
      });
      return;
    }

    List<DocumentSnapshot> results = _allResults.where((document) {
      final jobTitle = document['jobtitle']?.toString().toLowerCase() ?? '';
      return jobTitle.contains(query);
    }).toList();

    setState(() {
      _filteredResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Jobs',
          style: TextStyle(
              //color: Colors.white,
              fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: "Search",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                )),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: _filteredResults.isEmpty
                  ? const Center(
                      child: Text("No results found."),
                    )
                  : ListView.builder(
                      itemCount: _filteredResults.length,
                      itemBuilder: (context, index) {
                        final job = _filteredResults[index];
                        return ListTile(
                          title: Text(job['jobtitle']),
                          subtitle: Text('${job['jobcompany'] ?? "N/A"}'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JobDetailsPage(
                                  jobId: job.id,
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
