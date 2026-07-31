import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class GameSearchPage extends StatefulWidget {
  const GameSearchPage({super.key});

  @override
  _GameSearchPageState createState() => _GameSearchPageState();
}

class _GameSearchPageState extends State<GameSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allResults = [];
  List<DocumentSnapshot> _filteredResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchGames();
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

  Future<void> _fetchGames() async {
    setState(() {
      _isLoading = true;
    });

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('games')
        .orderBy('gametitle')
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
      String gameTitle = document['gametitle'].toString().toLowerCase();
      return gameTitle.contains(query);
    }).toList();

    setState(() {
      _filteredResults = results;
    });
  }

  Future<void> _openUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Games',
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
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: _filteredResults.isEmpty
                  ? const Center(
                      child: Text(
                        "No results found.",
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredResults.length,
                      itemBuilder: (context, index) {
                        final game = _filteredResults[index];
                        return ListTile(
                          title: Text(
                            game['gametitle'],
                          ),
                          subtitle: Text(
                            '${game['gamecompany'] ?? "N/A"}',
                          ),
                          onTap: () {
                            String gameUrl = game['gamelocation'];
                            if (gameUrl.isNotEmpty) {
                              launch(gameUrl);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('URL not available')),
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
