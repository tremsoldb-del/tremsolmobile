import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../homescreen.dart';
import 'cartpage.dart';
import 'product_details_screen.dart';

class WishlistPage extends StatefulWidget {
  final String userId; // Pass the current user's ID to this page

  const WishlistPage({super.key, required this.userId});

  @override
  _WishlistPageState createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? currencySymbol;
  double? exchangeRate;
  late final String userId;
  int wishlistCount = 0;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid; // Get current user UID
    _loadCurrencyData();
    _loadWishlistCount();
  }

  Future<void> _loadWishlistCount() async {
    try {
      final products =
          await FirebaseFirestore.instance.collection('products').get();

      setState(() {
        wishlistCount = products.docs.where((doc) {
          final likes = List<String>.from(doc['likes'] ?? []);
          return likes
              .contains(userId); // Check if user's UID is in the likes array
        }).length;
      });
    } catch (e) {
      print("Error loading wishlist count: $e");
    }
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


  double _convertPrice(dynamic price) {
    // Ensure the price is treated as a double
    final priceAsDouble = (price is int) ? price.toDouble() : price as double;
    return exchangeRate != null ? priceAsDouble * exchangeRate! : priceAsDouble;
  }

  //added 17-12-2024

  String? selectedColor;
  String? selectedSize;

  void _placeOrder(Map<String, dynamic> productData, int quantity) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showError("User not signed in");
      return;
    }

    // Check if the product has colors and sizes
    final hasColors = productData['product_colors'] != null &&
        (productData['product_colors'] as List).isNotEmpty;
    final hasSizes = productData['product_sizes'] != null &&
        (productData['product_sizes'] as List).isNotEmpty;

    // Determine the appropriate error message
    if ((hasColors && selectedColor == null) ||
        (hasSizes && selectedSize == null)) {
      String errorMessage = "Please select ";

      if (hasColors &&
          selectedColor == null &&
          hasSizes &&
          selectedSize == null) {
        errorMessage += "a color and a size before adding to cart.";
      } else if (hasColors && selectedColor == null) {
        errorMessage += "a color before adding to cart.";
      } else if (hasSizes && selectedSize == null) {
        errorMessage += "a size before adding to cart.";
      }

      _showError(errorMessage);
      return;
    }

    try {
      // Check if the product already exists in the cart for this user with selected options
      final cartQuerySnapshot = await FirebaseFirestore.instance
          .collection('cartitems')
          .where('userId', isEqualTo: userId)
          .where('productId', isEqualTo:productData['id'])
          .where('selectedColor', isEqualTo: selectedColor ?? "")
          .where('selectedSize', isEqualTo: selectedSize ?? "")
          .get();

      if (cartQuerySnapshot.docs.isNotEmpty) {
        // Product already exists, update quantity
        final existingCartItem = cartQuerySnapshot.docs.first;
        final existingQuantity = existingCartItem['quantity'] as int;

        await FirebaseFirestore.instance
            .collection('cartitems')
            .doc(existingCartItem.id)
            .update({
          'quantity': existingQuantity + quantity,
          'totalPrice': (productData['productsellingprice'] ?? 0) *
              (existingQuantity + quantity),
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Updated Cart'),
            content: Text(
                'Quantity of ${productData['productname'] ?? "Product"} updated to ${existingQuantity + quantity}.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Product does not exist, add as new entry
        await FirebaseFirestore.instance.collection('cartitems').add({
          'userId': userId,
          'productId': productData['id'],
          'productName': productData['productname'] ?? "Unknown Product",
          'productsellingprice': productData['productsellingprice'] ?? 0,

          // newly added lines
          'productprice': productData['productprice'] ?? 0,
          'tax': productData['tax'] ?? 0,
          'cost_per_item': productData['cost_per_item'] ?? 0,

          'productDescription': productData['productdescription'] ?? "",
          'quantity': quantity,
          'selectedColor': selectedColor ?? "",
          'selectedSize': selectedSize ?? "",
          'totalPrice': (productData['productsellingprice'] ?? 0) * quantity,
          'productImage': (productData['images'] != null &&
                  (productData['images'] as List).isNotEmpty)
              ? productData['images'].first
              : "", // Provide default or fallback for images
          'timestamp': FieldValue.serverTimestamp(),
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Added to Cart'),
            content: Text(
                'Added $quantity of ${productData['productname'] ?? "Product"} to the cart.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError("Failed to add to cart");
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('likes',
                  arrayContains: FirebaseAuth.instance.currentUser!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            int wishlistCount = 0;

            if (snapshot.hasData) {
              wishlistCount = snapshot.data!.docs.length;
            }

            return Text(
              'Wishlist ($wishlistCount)', // Dynamic title with count
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('cartitems')
                .where('userId',
                    isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              int cartCount = 0;

              if (snapshot.hasData) {
                cartCount = snapshot.data!.docs.length;
              }

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartPage(),
                          ),
                        );
                      },
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: 0,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$cartCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('likes', arrayContains: widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Your wishlist is empty.'));
          }

          final wishlistItems = snapshot.data!.docs;

        return GridView.builder(
  padding: const EdgeInsets.all(8.0),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 8.0,
    mainAxisSpacing: 8.0,
    childAspectRatio: 2 / 3,
  ),
  itemCount: wishlistItems.length,
  itemBuilder: (context, index) {
    final productDoc = wishlistItems[index];
    final productData = productDoc.data() as Map<String, dynamic>;
    final productId = productDoc.id;

    // ✅ Availability flags
    final bool isPublished = productData['isPublish'] ?? true;
    final bool isUnavailable = !isPublished;

    return Opacity(
      opacity: isUnavailable ? 0.5 : 1.0, // fade unavailable products
      child: Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // You can still allow viewing details (optional)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailsScreen(
                        productId: productId,
                      ),
                    ),
                  );
                },
                child: CachedNetworkImage(
                  imageUrl: (productData['image'] ?? '').toString(),
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
                    child: const Icon(Icons.broken_image_outlined, size: 42),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalizeFirstLetter(
                        productData['productname'] ?? 'No Name'),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(productData['productsellingprice']))}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isUnavailable)
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Text(
                        'This product is no longer available',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () {
                    _removeFromWishlist(productId);
                  },
                ),
                Flexible(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002A5C),
                    ),
                    onPressed: isUnavailable
                        ? null // 🔒 cannot add unavailable products to cart
                        : () {
                            _placeOrder(
                              {
                                'id': productId,
                                'productname': productData['productname'],
                                'productsellingprice':
                                    productData['productsellingprice'],
                                'product_colors':
                                    productData['product_colors'],
                                'product_sizes':
                                    productData['product_sizes'],
                                'images': productData['images'],
                                'productdescription':
                                    productData['productdescription'],
                                'productprice': productData['productprice'],
                                'tax': productData['tax'],
                                'cost_per_item':
                                    productData['cost_per_item'],
                              },
                              productData['productminquantity'] ?? 1,
                            );
                          },
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Add to Cart',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

        },
      ),
    );
  }

 void _removeFromWishlist(String productId) async {
  bool? confirmDelete = await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Remove from Wishlist"),
        content: const Text("Are you sure you want to remove this item from your wishlist?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false); // User cancels
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true); // User confirms
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );

  if (confirmDelete == true) {
    await FirebaseFirestore.instance.collection('products').doc(productId).update({
      'likes': FieldValue.arrayRemove([widget.userId]),
    });
  }
}

  //added
  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return ''; // Handle empty string case

    return input
        .split(' ')
        .where((word) => word.isNotEmpty) // Ensure empty words are removed
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _toggleLikeStatus(
      BuildContext context, String productId, bool isLiked) async {
    final action = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isLiked ? 'Remove from Wishlist' : 'Add to Wishlist'),
        content: Text(isLiked
            ? 'Are you sure you want to remove this product from your wishlist?'
            : 'Do you want to add this product to your wishlist?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false); // Dismiss the dialog
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true); // Confirm the action
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (action == true) {
      if (isLiked) {
        await _firestore.collection('products').doc(productId).update({
          'likes': FieldValue.arrayRemove([widget.userId]),
        });
      } else {
        await _firestore.collection('products').doc(productId).update({
          'likes': FieldValue.arrayUnion([widget.userId]),
        });
      }
    }
  }
}
