import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/services/app_colors.dart';

import '../homescreen.dart';
import 'cartpage.dart';
import 'product_details_screen.dart';
import 'productsearch_deals.dart';

class TrendingDealsPage extends StatefulWidget {
  const TrendingDealsPage({super.key});

  @override
  State<TrendingDealsPage> createState() => _TrendingDealsPageState();
}

class _TrendingDealsPageState extends State<TrendingDealsPage> {
  String currencySymbol = "GHS";
  double exchangeRate = 1.0;

  @override
  void initState() {
    super.initState();
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


  double _convertPrice(double price) => price * exchangeRate;

  // NOTE: Prefer using products.ordersCount in real time (fast).
  // Keeping your helper for compatibility, but it’s O(N) over orders.
  Future<int> getOrderCount(String productId) async {
    final q = await FirebaseFirestore.instance.collection('ordersitems').get();
    int orderCount = 0;
    for (var doc in q.docs) {
      final items = (doc['items'] as List?) ?? const [];
      for (final it in items) {
        if (it is Map && (it['productId']?.toString() ?? '') == productId) {
          orderCount++;
          break;
        }
      }
    }
    return orderCount;
  }

  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return '';
    return input
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final settingsRef =
        FirebaseFirestore.instance.collection('settings').doc('homepage');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trending Deals', style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PrdSearchDealsPage(dealTag: 'Trending')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
            },
          ),
          FirebaseAuth.instance.currentUser == null
              ? const SizedBox()
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('cartitems')
                      .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final cartCount = snapshot.data?.docs.length ?? 0;
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const CartPage()));
                            },
                          ),
                          if (cartCount > 0)
                            Positioned(
                              right: 0,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text('$cartCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ],
        backgroundColor: AppColors().getColor('trending'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ---------- SETTINGS -> BUILD QUERY -> GRID ----------
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: settingsRef.snapshots(),
        builder: (context, settingsSnap) {
          final settings = settingsSnap.data?.data() ?? const {};
          final String trendingSort = (settings['trendingSort'] ?? 'mostOrdered').toString();
          final bool override = settings['trendingOverride'] == true;

          Query<Map<String, dynamic>> base =
              FirebaseFirestore.instance.collection('products')
                .where('producttag', arrayContainsAny: ['Trending', 'trending', 'TRENDING'])
                .where('isPublish', isEqualTo: true);

          Query<Map<String, dynamic>> query;
          if (override) {
            // Manual curated order: requires products.trendingRank (int)
            query = base.where('trendingRank', isGreaterThan: -1).orderBy('trendingRank').limit(100);
          } else {
            switch (trendingSort) {
              case 'mostViewed':
                query = base.orderBy('viewsCount', descending: true).limit(100);
                break;
              case 'priceAsc':
                query = base.orderBy('productsellingprice', descending: false).limit(100);
                break;
              case 'mostOrdered':
              default:
                query = base.orderBy('ordersCount', descending: true).limit(100);
                break;
            }
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load trending items.\n${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data!.docs;
              if (products.isEmpty) {
                return const Center(child: Text('No trending products yet.'));
              }

              final screenWidth = MediaQuery.of(context).size.width;
              const crossAxisCount = 2;
              final childAspectRatio = screenWidth / (screenWidth * 1.8);

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final m = product.data();

                    final String name = (m['productname'] ?? '').toString();
                    final String imageUrl = (m['image'] ?? '').toString();

                    final iniPrice = (m['productprice'] as num?)?.toDouble() ?? 0.0;
                    final tax = (m['tax'] as num?)?.toDouble() ?? 0.0;
                    final iniSellingPrice = iniPrice + tax;

                    final finSellingPrice = (m['productsellingprice'] as num?)?.toDouble() ?? 0.0;
                    final discRaw = (m['productdiscprice'] is String)
                        ? double.tryParse(m['productdiscprice'] ?? '0')
                        : (m['productdiscprice'] as num?)?.toDouble();
                    final discountedPrice = discRaw ?? 0.0;

                    final discountedPercentage = (iniSellingPrice > 0)
                        ? (((iniSellingPrice - finSellingPrice) / iniSellingPrice) * 100)
                        : 0.0;

                    final productState = (m['productstate'] ?? '').toString();
                    final double? rating = (m['rating'] is num)
                        ? (m['rating'] as num).toDouble()
                        : null;
                    final bool hasRating = rating != null && rating > 0;

                    final isLiked = ValueNotifier<bool>(
                      (m['likes'] != null && FirebaseAuth.instance.currentUser != null)
                          ? (m['likes'] as List).contains(FirebaseAuth.instance.currentUser!.uid)
                          : false,
                    );

                    Future<void> toggleLike() async {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) return;
                      final ref = FirebaseFirestore.instance.collection('products').doc(product.id);
                      await FirebaseFirestore.instance.runTransaction((tx) async {
                        final snap = await tx.get(ref);
                        final data = snap.data() ?? {};
                        final likes = (data['likes'] as List?)?.toList() ?? <dynamic>[];
                        if (likes.contains(currentUser.uid)) {
                          likes.remove(currentUser.uid);
                        } else {
                          likes.add(currentUser.uid);
                        }
                        tx.update(ref, {'likes': likes});
                      });
                      isLiked.value = !isLiked.value;
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: product.id)));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image + badges
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    height: MediaQuery.of(context).size.height * 0.19,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    fadeInDuration: const Duration(milliseconds: 120),
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey.shade100,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey.shade100,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                if (productState.isNotEmpty)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: Colors.red, width: 0.5),
                                      ),
                                      child: Text(
                                        productState.toUpperCase(),
                                        style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w900),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                if (discountedPercentage > 0 && discountedPercentage < 100)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                                      child: Text(
                                        '-${discountedPercentage.toStringAsFixed(0)}%',
                                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: ValueListenableBuilder<bool>(
                                    valueListenable: isLiked,
                                    builder: (context, value, child) {
                                      return GestureDetector(
                                        onTap: toggleLike,
                                        child: Opacity(
                                          opacity: 0.8,
                                          child: CircleAvatar(
                                            backgroundColor: const Color(0xFFFFEDEE),
                                            radius: 18,
                                            child: Icon(value ? Icons.favorite : Icons.favorite_border,
                                                color: Colors.red, size: 20),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // Info
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      _capitalizeFirstLetter(name),
                                      style: const TextStyle(fontSize: 13, color: Colors.black),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (discountedPercentage > 0 && discountedPercentage < 100)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(finSellingPrice))}',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(iniSellingPrice))}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(iniSellingPrice))}',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (hasRating)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating!.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: Colors.black45,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Not rated',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.black45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Orders count (fallback to expensive scan if no product.ordersCount)
                                  FutureBuilder<int>(
                                    future: m.containsKey('ordersCount')
                                        ? Future.value((m['ordersCount'] as num?)?.toInt() ?? 0)
                                        : getOrderCount(product.id),
                                    builder: (context, snap) {
                                      if (!snap.hasData) {
                                        return const Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.black54));
                                      }
                                      if ((snap.data ?? 0) == 0) return const SizedBox.shrink();
                                      return Text(
                                        '${snap.data} Orders',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please sign in or create an account to add product to cart'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }

                                    // Use selling price for cart
                                    final price = finSellingPrice;

                                    _placeOrder(
                                      {
                                        'id': product.id,
                                        'productname': name,
                                        'productsellingprice': price,
                                        'product_colors': m['product_colors'],
                                        'product_sizes': m['product_sizes'],
                                        'images': m['images'],
                                        'productdescription': m['productdescription'],
                                      },
                                      (m['productminquantity'] as num?)?.toInt() ?? 1,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors().getColor('trending'),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Add to Cart', style: TextStyle(color: Colors.white, fontSize: 14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ============ Add-to-cart (kept from your code, minor tidy) ============
  String? selectedColor;
  String? selectedSize;

  Future<void> _placeOrder(Map<String, dynamic> productData, int quantity) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showError("User not signed in");
      return;
    }

    final hasColors = (productData['product_colors'] is List) && (productData['product_colors'] as List).isNotEmpty;
    final hasSizes  = (productData['product_sizes'] is List) && (productData['product_sizes'] as List).isNotEmpty;

    if ((hasColors && selectedColor == null) || (hasSizes && selectedSize == null)) {
      String msg = "Please select ";
      if (hasColors && selectedColor == null && hasSizes && selectedSize == null) {
        msg += "a color and a size before adding to cart.";
      } else if (hasColors && selectedColor == null) {
        msg += "a color before adding to cart.";
      } else {
        msg += "a size before adding to cart.";
      }
      _showError(msg);
      return;
    }

    try {
      final cartQuery = await FirebaseFirestore.instance
          .collection('cartitems')
          .where('userId', isEqualTo: userId)
          .where('productId', isEqualTo: productData['id'])
          .where('selectedColor', isEqualTo: selectedColor ?? "")
          .where('selectedSize', isEqualTo: selectedSize ?? "")
          .get();

      if (cartQuery.docs.isNotEmpty) {
        final existing = cartQuery.docs.first;
        final existingQty = (existing['quantity'] as num).toInt();
        final newQty = existingQty + quantity;

        await existing.reference.update({
          'quantity': newQty,
          'totalPrice': (productData['productsellingprice'] ?? 0) * newQty,
        });

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Updated Cart'),
            content: Text('Quantity of ${productData['productname'] ?? "Product"} updated to $newQty.'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
      } else {
        await FirebaseFirestore.instance.collection('cartitems').add({
          'userId': userId,
          'productId': productData['id'],
          'productName': productData['productname'] ?? "Unknown Product",
          'productsellingprice': productData['productsellingprice'] ?? 0,
          'productprice': productData['productprice'] ?? 0,
          'tax': productData['tax'] ?? 0,
          'cost_per_item': productData['cost_per_item'] ?? 0,
          'productDescription': productData['productdescription'] ?? "",
          'quantity': quantity,
          'selectedColor': selectedColor ?? "",
          'selectedSize': selectedSize ?? "",
          'totalPrice': (productData['productsellingprice'] ?? 0) * quantity,
          'productImage': (productData['images'] is List && (productData['images'] as List).isNotEmpty)
              ? productData['images'].first
              : "",
          'timestamp': FieldValue.serverTimestamp(),
        });

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Added to Cart'),
            content: Text('Added $quantity of ${productData['productname'] ?? "Product"} to the cart.'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
      }
    } catch (_) {
      _showError("Failed to add to cart");
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}
