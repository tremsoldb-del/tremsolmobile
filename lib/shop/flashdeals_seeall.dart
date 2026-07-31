import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

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

class FlashDealsPage extends StatefulWidget {
  const FlashDealsPage({super.key});

  @override
  State<FlashDealsPage> createState() => _FlashDealsPageState();
}

class _FlashDealsPageState extends State<FlashDealsPage> {
  String currencySymbol = "GHS";
  double exchangeRate = 1.0;
  //late Timer _timer;
  final Duration _timeRemaining = const Duration(hours: 1); // Initial countdown time

  @override
  void initState() {
    super.initState();
    _loadCurrencyData();
    // _startTimer();
  }

  /*@override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > const Duration(seconds: 1)) {
          _timeRemaining -= const Duration(seconds: 1);
        } else {
          _timeRemaining = const Duration(hours: 1); // Restart countdown
        }
      });
    });
  }

  String _formatTimeRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  */

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

  //added
   String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return ''; // Handle empty string case

    return input
        .split(' ')
        .where((word) => word.isNotEmpty) // Ensure empty words are removed
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }


  double _convertPrice(double price) {
    return price * exchangeRate;
  }

  //modified 25-12-24
  Future<int> getOrderCount(String productId) async {
    // Query Firestore to get the documents from the 'ordersitems' collection
    final querySnapshot = await FirebaseFirestore.instance
        .collection('ordersitems')
        .get(); // Get all documents (this will be filtered later)

    int orderCount = 0;

    // Loop through each document in the query result
    for (var doc in querySnapshot.docs) {
      // Access the 'items' array in the document
      var items = doc['items'];

      // Check if the 'items' array contains any map with the 'productId' matching the passed value
      for (var item in items) {
        if (item is Map && item['productId'] == productId) {
          orderCount++; // Increment order count if the 'productId' is found in the map
          break; // Exit the loop once we find a matching productId
        }
      }
    }

    // Return the number of orders that contain the specified productId
    return orderCount;
  }

//added 17-12-2024
//added 15-12-24
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flash Deals',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),

            /* Text(
              'Ends in: ${_formatTimeRemaining(_timeRemaining)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),*/
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrdSearchDealsPage(dealTag: 'Flash'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.home,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
             FirebaseAuth.instance.currentUser == null
    ? const SizedBox() // Hide cart icon if user is not signed in
    :StreamBuilder<QuerySnapshot>(
    
    stream:FirebaseFirestore.instance
        .collection('cartitems')
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
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
        backgroundColor: AppColors().getColor('flash'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildProductGrid(),
    );
  }

  Widget _buildProductGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('producttag', arrayContainsAny: ['Flash', 'flash', 'FLASH'])
          .where('isPublish', isEqualTo: true)
          .orderBy('createdAt', descending: true) // Order by latest first
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!.docs;

        final screenWidth = MediaQuery.of(context).size.width;
        const int crossAxisCount = 2; // Number of columns in the grid
        final double childAspectRatio = screenWidth / (screenWidth * 1.8);

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
              final name = product['productname'];
              final imageUrl = product['image'] ?? '';

//commented 11 03 2025

/*
//added 05 02 2025
              final price =
                  double.tryParse(product['productsellingprice'].toString()) ?? 0.0;

//commented 05 02 2025
              // final price = product['productsellingprice']?.toDouble() ?? 0.0;

              final discountedPrice = (product['productdiscprice'] is String
                      ? double.tryParse(product['productdiscprice'] ?? '0')
                      : (product['productdiscprice'] as num?)?.toDouble()) ??
                  0.0;
              final discountedPercentage =
                  ((price - discountedPrice) / price) * 100;
*/



//added 11 03 2025
 final iniPrice =
                        product['productprice']?.toDouble() ?? 0.0;

                    final price =
                        product['productsellingprice']?.toDouble() ?? 0.0;
                    
                    final discountedPrice =
                        (product['productdiscprice'] is String
                                ? double.tryParse(
                                    product['productdiscprice'] ?? '0')
                                : (product['productdiscprice'] as num?)
                                    ?.toDouble()) ??
                            0.0;

                    /*final discountedPercentage =
                        ((price - discountedPrice) / price) * 100;*/

                    final productPrice =
                        product['productprice']?.toDouble() ?? 0.0;
                    final tax = product['tax']?.toDouble() ?? 0.0;
                    //final ini_sellingPrice = ini_price + tax;
                    final iniSellingprice = productPrice + tax;
                    final finSellingprice =
                        product['productsellingprice']?.toDouble() ?? 0.0;

                    final discountedPercentage =
                        (((iniSellingprice - finSellingprice) /
                                (iniSellingprice)) *
                            100);



//added 11 03 2025


              final productState = product['productstate'];
              final double? rating = product['rating'] is num
                  ? (product['rating'] as num).toDouble()
                  : double.tryParse(product['rating']?.toString() ?? '');
              final bool hasRating = rating != null && rating > 0;
           //added 17 03 2025
              final ValueNotifier<bool> isLiked = ValueNotifier(
  (product['likes'] != null && FirebaseAuth.instance.currentUser != null)
      ? product['likes'].contains(FirebaseAuth.instance.currentUser!.uid)
      : false,
);
              Future<void> toggleLike() async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  final productRef = FirebaseFirestore.instance
                      .collection('products')
                      .doc(product.id);

                  await FirebaseFirestore.instance
                      .runTransaction((transaction) async {
                    DocumentSnapshot snapshot =
                        await transaction.get(productRef);
                    List<dynamic> likes = snapshot['likes'] ?? [];

                    if (likes.contains(currentUser.uid)) {
                      likes.remove(currentUser.uid);
                    } else {
                      likes.add(currentUser.uid);
                    }

                    transaction.update(productRef, {'likes': likes});
                  });

                  isLiked.value = !isLiked.value;
                }
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailsScreen(productId: product.id),
                    ),
                  );
                },
                child:Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withOpacity(0.2),
        blurRadius: 5,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // IMAGE + BADGES
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
          // Position productState, discount badge, and like button as before...
          // Top-left: Product state
                              if (productState != null &&
                                  productState.isNotEmpty)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal:
                                          6, // Reduced padding to make it thinner
                                      vertical:
                                          2, // Reduced padding to make it smaller
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      // Adjusted radius to suit the new size
                                      border: Border.all(
                                          color: Colors.red,
                                          width: 0.5), // Added a red border
                                    ),
                                    child: Text(
                                      productState
                                          .toUpperCase(), // Converts text to uppercase
                                      style: const TextStyle(
                                        fontSize:
                                            9, // Slightly reduced font size for a better fit
                                        color: Colors.red,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              // Top-right: Discount percentage
                              if (discountedPercentage > 0 &&
                                  discountedPercentage < 100)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '-${discountedPercentage.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              // Bottom-right: Like icon
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
                                          backgroundColor:
                                              const Color(0xFFFFEDEE),
                                          radius: 18,
                                          child: Icon(
                                            value
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color:
                                                value ? Colors.red : Colors.red,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
        ],
      ),
      // PRODUCT INFO
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // name, price, discount, rating, order count widgets here
            // same logic you have, just inside this consistent padding
                       Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    _capitalizeFirstLetter(name),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (discountedPercentage > 0 &&
                                    discountedPercentage < 100)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                         '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(finSellingprice))}',
                                       // '$currencySymbol ${_convertPrice(fin_sellingPrice).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                          '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(iniSellingprice))}',
                                       // '$currencySymbol ${_convertPrice(ini_sellingPrice).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                     '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(iniSellingprice))}',
                                    //'$currencySymbol ${_convertPrice(ini_sellingPrice).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: hasRating
                                          ? Colors.amber
                                          : Colors.black45,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasRating
                                          ? rating!.toStringAsFixed(1)
                                          : 'Not rated',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                FutureBuilder<int>(
                                  future: getOrderCount(product.id),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Text(
                                        'Loading...',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54),
                                      );
                                    }

                                    if (snapshot.data == 0) {
                                      return Container(); // Display nothing
                                    }

                                    return Text(
                                      '${snapshot.data ?? 0} Orders',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    );
                                  },
                                ),
          ],
        ),
      ),
      const Spacer(), // pushes button to bottom of the column
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: SizedBox(
           width: double.infinity, // makes the button stretch fully within the padding
          child: ElevatedButton(
             onPressed: () {
              var firebaseUser = FirebaseAuth.instance.currentUser;
              if (firebaseUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in or create an account to add product to cart'),
            duration: Duration(seconds: 2),
          ),
                );
                return; // Stop execution if user is null
              }
              
              _placeOrder(
                {
          'id': product.id,
          'productname': name,
          'productsellingprice': price,
          'product_colors': product['product_colors'],
          'product_sizes': product['product_sizes'],
          'images': product['images'],
          'productdescription': product['productdescription'],
                },
                product['productminquantity'], // Default quantity
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors().getColor('flash'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add to Cart',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      )
    ],
  ),
)

              );
            },
          ),
        );
      },
    );
  }
}
