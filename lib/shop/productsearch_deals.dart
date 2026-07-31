import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_details_screen.dart';

class PrdSearchDealsPage extends StatefulWidget {
  final String dealTag;

  const PrdSearchDealsPage({super.key, required this.dealTag});

  @override
  _PrdSearchDealsPageState createState() => _PrdSearchDealsPageState();
}

class _PrdSearchDealsPageState extends State<PrdSearchDealsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allResults = [];
  List<DocumentSnapshot> _filteredResults = [];
  bool _isLoading = false;
  bool _showFinalResults = false;

  double exchangeRate = 1.0;
  String currencySymbol = "GHS";

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _loadCurrencyData();
  }

 bool _currencyLoaded = false;

Future<void> _loadCurrencyData() async {
  final prefs = await SharedPreferences.getInstance();

  final base = prefs.getString('baseCurrency') ?? 'GHS';
  final selected = prefs.getString('selectedCurrency') ?? base;
  final rate = prefs.getDouble('conversionRate') ?? 1.0;

  setState(() {
    currencySymbol = selected;  // 👈 show user’s chosen currency code
    exchangeRate = rate;        // 👈 base → selected
    _currencyLoaded = true;
  });
}


  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return '';
    return input
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);

    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('producttag', arrayContainsAny: [widget.dealTag])
        .where('isPublish', isEqualTo: true)
        .orderBy('productname')
        .get();

    setState(() {
      _allResults = snapshot.docs;
      _filteredResults = List.from(_allResults);
      _isLoading = false;
    });
  }

  void _filterResults() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredResults = query.isEmpty
          ? []
          : _allResults.where((doc) {
              final name = doc['productname'].toString().toLowerCase();
              return name.contains(query);
            }).toList();
    });
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(_capitalizeFirstLetter(text));
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final start = lowerText.indexOf(lowerQuery);
    if (start == -1) return Text(_capitalizeFirstLetter(text));
    final end = start + query.length;

    return RichText(
      text: TextSpan(
        text: _capitalizeFirstLetter(text.substring(0, start)),
        style: const TextStyle(color: Colors.black),
        children: [
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: _capitalizeFirstLetter(text.substring(end)),
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  void _onSubmitSearch(String value) {
    _filterResults();
    setState(() {
      _showFinalResults = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search ${widget.dealTag} Deals', style: const TextStyle(fontSize: 18)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "What are you looking for?",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (val) {
                _filterResults();
                setState(() {
                  _showFinalResults = false;
                });
              },
              onSubmitted: _onSubmitSearch,
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_searchController.text.isEmpty && !_showFinalResults)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      "Start typing and press Enter to search",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
       else if (!_showFinalResults)
  Expanded(
    child: ListView.builder(
      itemCount: _filteredResults.length,
      itemBuilder: (context, index) {
        final product = _filteredResults[index];
        final name = product['productname'] ?? '';
        return ListTile(
          leading: const Icon(Icons.label_important_outline),
          title: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
            child: _buildHighlightedText(name, _searchController.text),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailsScreen(productId: product.id),
              ),
            );
          },
        );
      },
    ),
  )

          else if (_filteredResults.isEmpty)
            const Expanded(child: Center(child: Text("No results found.")))
          else
            Expanded(
              child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                padding: const EdgeInsets.all(10),
                itemCount: _filteredResults.length,
                itemBuilder: (context, index) {
                  final product = _filteredResults[index];
                  final name = product['productname'] ?? '';
                  final rawPrice = product['productsellingprice'] ?? 0.0;
                  final imageUrl = product['image'] ?? '';
                  final displayPrice = (rawPrice * exchangeRate).toStringAsFixed(2);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailsScreen(productId: product.id),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 4,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 120),
                              placeholder: (context, url) => Container(
                                height: 180,
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 180,
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, size: 60),
                              ),
                            )
                          : const Icon(Icons.image_not_supported, size: 100),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHighlightedText(name, _searchController.text),
                                const SizedBox(height: 6),
                                Text(
                                  "$currencySymbol $displayPrice",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}