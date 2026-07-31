import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fashion_detail_page.dart';

class FashionSearchPage extends StatefulWidget {
  const FashionSearchPage({super.key});

  @override
  _FashionSearchPageState createState() => _FashionSearchPageState();
}

class _FashionSearchPageState extends State<FashionSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allResults = [];
  List<DocumentSnapshot> _filteredResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchFashions();
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

  Future<void> _fetchFashions() async {
    setState(() {
      _isLoading = true;
    });

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('fashions')
        .orderBy('fashiontitle')
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
      String fashionTitle = document['fashiontitle'].toString().toLowerCase();
      return fashionTitle.contains(query);
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
          'Search Fashions',
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
                      child: Text("No results found."),
                    )
                  : ListView.builder(
                      itemCount: _filteredResults.length,
                      itemBuilder: (context, index) {
                        final fashion = _filteredResults[index];
                        return ListTile(
                          title: Text(fashion['fashiontitle']),
                          subtitle: Text('${fashion['fashioncompany']}'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FashionDetailPage(
                                  fashionId: fashion.id,
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
