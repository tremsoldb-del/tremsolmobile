import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'video_player_screen.dart';

class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({super.key});

  @override
  _MovieSearchPageState createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allResults = [];
  List<DocumentSnapshot> _filteredResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchMovies();
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

  Future<void> _fetchMovies() async {
    setState(() {
      _isLoading = true;
    });

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('movies')
        //  .orderBy('movietitle')
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
      String movieTitle = document['moviestitle'].toString().toLowerCase();
      return movieTitle.contains(query);
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
          'Search Movies',
          style: TextStyle(
              // color: Colors.white,
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
                        final movie = _filteredResults[index];
                        return ListTile(
                          title: Text(movie['moviestitle']),
                         //commented 06 05 2025
                         // subtitle: Text(movie['moviestype'] ?? 'Unknown Type'),
                          subtitle: Text(
  movie['moviescat'] ?? 'Unknown Type',
  style: const TextStyle(fontSize: 12), // Change 14 to your preferred size
),

                         
                          onTap: () {
                            String videoUrl = movie['movieslocation'];
                            if (videoUrl.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      VideoPlayerScreen(videoUrl: videoUrl),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Video URL not available')),
                              );
                            }
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
