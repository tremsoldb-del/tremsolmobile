import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/shop/wishlist.page.dart';

import '../homescreen.dart';
import 'checkoutpage.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String? currencySymbol;
  double? exchangeRate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//added 22 01 2025 for PROMO CODE

 String? userId; // Global variable to store the Firebase UID
 

  @override
  void initState() {
    super.initState();

    _loadCurrencyData();

    initializeUserId();
    _loadWishlistCount();


//added 16 03 2025
 /* final FirebaseAuth auth = FirebaseAuth.instance;
    final User? currentUser = auth.currentUser;

    if (currentUser != null) {
      userId = currentUser.uid;
    } else {
      userId = '';
    }*/



  }



  Future<void> initializeUserId() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      userId = currentUser?.uid; // Assign the UID to the global variable
      if (userId != null) {
        print('User ID successfully retrieved: $userId');
      } else {
        print('No user is signed in.');
      }
    } catch (e) {
      print('Error retrieving user ID: $e');
    }
  }

  int wishlistCount = 0;
//added 05-01-2025
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


    //added 13-04-2025
  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return ''; // Handle empty string case

    return input
        .split(' ')
        .where((word) => word.isNotEmpty) // Ensure empty words are removed
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }


 void _toggleLikeStatus(BuildContext context, String productId, bool isLiked, Function updateUI) async {
  // Get the current user
  final User? currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You need to log in to update your wishlist.'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  final action = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isLiked ? 'Remove from Wishlist' : 'Add to Wishlist'),
      content: Text(isLiked
          ? 'Are you sure you want to remove this product from your wishlist?'
          : 'Do you want to add this product to your wishlist?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // Dismiss dialog
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true), // Confirm action
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  if (action == true) {
    final userId = currentUser.uid;

    try {
      if (isLiked) {
        await FirebaseFirestore.instance.collection('products').doc(productId).update({
          'likes': FieldValue.arrayRemove([userId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product removed from your wishlist.'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        await FirebaseFirestore.instance.collection('products').doc(productId).update({
          'likes': FieldValue.arrayUnion([userId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added to your wishlist.'),
            duration: Duration(seconds: 2),
          ),
        );
        updateUI(); // Hide like button instantly
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $error'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}


//added 9 12 2025
Future<List<String>> _getUnavailableProductIds(
    List<QueryDocumentSnapshot> cartDocs) async {
  final List<String> unavailable = [];

  for (final cartDoc in cartDocs) {
    final data = cartDoc.data() as Map<String, dynamic>;
    final String productId = data['productId'];

    final productSnap = await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .get();

    if (!productSnap.exists) {
      unavailable.add(productId);
      continue;
    }

    final productData = productSnap.data() as Map<String, dynamic>;
    final bool isPublished = productData['isPublish'] ?? true;

    if (!isPublished) {
      unavailable.add(productId);
    }
  }

  return unavailable;
}


Widget _buildCartItem(QueryDocumentSnapshot cartItem, BuildContext context) {
  final data = cartItem.data() as Map<String, dynamic>;
  final double originalPrice = (data['totalPrice'] ?? 0.0).toDouble();
  final double convertedPrice = _convertPrice(originalPrice);
  final int quantity = data['quantity'] ?? 1;
  final String productId = data['productId'];

  Color? color;
  if (data['selectedColor'] != null && data['selectedColor'].isNotEmpty) {
    color = Color(int.parse(data['selectedColor'].substring(1), radix: 16))
        .withOpacity(1.0);
  }

 return FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool productExists = snapshot.data!.exists;
    final productData = productExists
        ? (snapshot.data!.data() as Map<String, dynamic>)
        : <String, dynamic>{};

    final bool isPublished = productData['isPublish'] ?? true;
    final bool isUnavailable = !productExists || !isPublished;

    bool isLiked = productExists &&
        productData['likes'] != null &&
        (productData['likes'] as List<dynamic>).contains(userId);


      return StatefulBuilder(
  builder: (context, setState) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      child: Opacity(
        opacity: isUnavailable ? 0.5 : 1.0, // fade unavailable items
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    leading: 
                    CachedNetworkImage(
  imageUrl: data['productImage'],
   width: MediaQuery.of(context).size.width * 0.15,
                      height: MediaQuery.of(context).size.height * 0.08,
  fit: BoxFit.cover,
  placeholder: (context, url) => const SizedBox(
    width: 60,
    height: 60,
    child: Center(
      child: Icon(Icons.shopping_cart_outlined, size: 28, color: Colors.grey),
    ),
  ),
  errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 28),
),

                    
                 /*
                    Image.network(
                      data['productImage'],
                      fit: BoxFit.cover,
                      width: MediaQuery.of(context).size.width * 0.15,
                      height: MediaQuery.of(context).size.height * 0.08,
                    ),
*/
                    title: Text(
                      _capitalizeFirstLetter(data['productName']),
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
             subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    if (isUnavailable)
      const Text(
        'This product is no longer available',
        style: TextStyle(
          fontSize: 12,
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    if (!isUnavailable) // Only show description if still available
      Text(
        data['productDescription'] ?? '',
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    if (color != null)
      Row(
        children: [
          const Text('Color: ', style: TextStyle(fontSize: 12)),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    if (data['selectedSize'] != null && data['selectedSize'].isNotEmpty)
      Text('Size: ${data['selectedSize']}', style: const TextStyle(fontSize: 12)),
  ],
),

             trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (!isUnavailable && !isLiked) // only when available & not yet liked
      IconButton(
        icon: const Icon(Icons.favorite_border, color: Colors.black),
        onPressed: () {
          _toggleLikeStatus(context, productId, isLiked, () {
            setState(() => isLiked = true); // Hide button instantly
          });
        },
      ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey, size: 18),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Remove Item"),
                                  content: const Text("Are you sure you want to remove this item from the cart?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _deleteCartItem(cartItem.id);
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text("Remove"),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
               Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$currencySymbol ${NumberFormat("#,##0.00").format(convertedPrice)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (isUnavailable)
          const Text(
            'Unavailable',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    ),
    Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: isUnavailable
              ? null
              : () async {
                  final minQuantity = await _getProductMinQuantity(productId);
                  if (quantity > minQuantity && quantity > 1) {
                    _updateQuantity(cartItem.id, quantity - 1);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cannot decrease quantity below the minimum of $minQuantity'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
        ),
        Text(quantity.toString()),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: isUnavailable
              ? null
              : () {
                  _updateQuantity(cartItem.id, quantity + 1);
                },
        ),
      ],
    ),
  ],
),

                ],
              ),
            ),
     ) );
        },
      );
    },
  );
}



  //added 23 01 2025
  String? _appliedPromoCode; // Tracks the applied promo code
  double _discountAmount = 0.0; // Tracks the discount value
  bool _isPromoApplied =
      false; // Flag to track if promo code is successfully applied

  @override
  Widget build(BuildContext context) {
   
   
   final userId = FirebaseAuth.instance.currentUser?.uid;


    final promoCodeController = TextEditingController();


    //added 16 03 2025
//commented on 16 03 2025
if (userId == null) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Cart",
                style: TextStyle(color: Colors.white, fontSize: 18),
      ),
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      Navigator.pop(context);
    },
  ),
     backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
  ),
    backgroundColor: Colors.white,
    body: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
  Icon(
       Icons.remove_shopping_cart, // Cart cancel icon
    size: 80,
    color: Colors.grey,
  ),
  SizedBox(height: 16),
  /*const Text(
    'Sign in to continue',
    style: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
  ),*/
  SizedBox(height: 8),
  Text(
    'Please sign in or create an account to access your cart.',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 16,
      color: Colors.black,
    ),
  ),
 

]

      ),
    ),
  );
}


    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cartitems')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text(
                'Cart',
                style: TextStyle(color: Colors.white, fontSize: 18),
              );
            }

            final totalUniqueItems = snapshot.data?.docs.length ?? 0;

            return Text(
              'Cart ($totalUniqueItems)',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            );
          },
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WishlistPage(userId: userId),
                    ),
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox
                        .shrink(); // Show nothing while loading
                  }

                  if (snapshot.hasError) {
                    return const SizedBox.shrink(); // Handle error gracefully
                  }

                  final wishlistCount = snapshot.data?.docs.where((doc) {
                        final likes = List<String>.from(doc['likes'] ?? []);
                        return likes.contains(userId);
                      }).length ??
                      0;

                  return wishlistCount > 0
                      ? Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '$wishlistCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
            ],
          ),
          /* IconButton(
            icon: const Icon(
              Icons.favorite_border_outlined,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WishlistPage(userId: userId),
                ),
              );
            },
          ),*/
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
        ],
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: 
      
      userId.isEmpty
          ? const Center(child: Text('Please sign in to view this page')):
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cartitems')
            .where('userId', isEqualTo: userId)
            //  .orderBy('timestamp',
            //     descending: true) // Order by timestamp, most recent first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '0 items in the basket',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nothing to show here right now',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WishlistPage(
                                  userId: userId), // Use widget.userId
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF002A5C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Check Wishlist',
                          style: TextStyle(color: Color(0xFF002A5C)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const HomeScreen(), // Remove the `const` if unnecessary
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002A5C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Start Shopping',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          final cartItems = snapshot.data!.docs;
          final storeGroupedItems = _groupItemsByStore(cartItems);

          return ListView.builder(
            itemCount: storeGroupedItems.length,
            itemBuilder: (context, index) {
              final storeName = storeGroupedItems.keys.elementAt(index);
              final items = storeGroupedItems[storeName]!;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    //   child: Text(
                    //     storeName,
                    //     style: const TextStyle(
                    //         fontSize: 16, fontWeight: FontWeight.bold),
                    //   ),
                    // ),
                    // Modify the call to _buildCartItem to pass context
                    ...items
                        .map((cartItem) => _buildCartItem(cartItem, context)),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cartitems')
            .where('userId', isEqualTo: userId)
            .snapshots(),
      builder: (context, snapshot) {
  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
    return const SizedBox.shrink();
  }

  final cartDocs = snapshot.data!.docs;

  double totalAmount = 0.0;
  int totalUniqueItems = cartDocs.length;

  for (var doc in cartDocs) {
    final data = doc.data() as Map<String, dynamic>;
    totalAmount += (data['totalPrice'] ?? 0.0).toDouble();
  }

  double displayTotalAmount =
      _isPromoApplied ? totalAmount - _discountAmount : totalAmount;

  return FutureBuilder<List<String>>(
    future: _getUnavailableProductIds(cartDocs),
    builder: (context, unavailableSnapshot) {
      // If future not done yet, assume no unavailable items for UI purposes
      final bool hasUnavailable =
          (unavailableSnapshot.hasData && (unavailableSnapshot.data?.isNotEmpty ?? false));

      return SafeArea(
        child: Padding(
          padding: MediaQuery.of(context).viewInsets, // Adjust for keyboard
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Promo code section
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 4.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: promoCodeController,
                            decoration: InputDecoration(
                              hintText: 'Enter promo code',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 12.0,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ElevatedButton(
  onPressed: hasUnavailable
      ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please remove unavailable items before applying a promo code.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      : () async {
          String promoCode = promoCodeController.text.trim();
          bool isValid = await _validatePromoCode(promoCode, totalAmount);
          setState(() {
            if (isValid) {
              _appliedPromoCode = promoCode;
              _isPromoApplied = true;
            } else {
              _isPromoApplied = false;
              _discountAmount = 0.0;
              _appliedPromoCode = null;
            }
          });
        },
  child: const Text('Apply'),
),

                      ],
                    ),
                    const SizedBox(height: 8.0),
                    // Display amount saved
                    if (_isPromoApplied && _discountAmount > 0)
                      Text(
                        'You saved $currencySymbol ${_convertPrice(_discountAmount).toStringAsFixed(2)} using the promo code "$_appliedPromoCode".',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow
                            .ellipsis, // Prevents text from wrapping to the next line
                        maxLines:
                            1, // Ensures the text stays on a single line
                      ),
                  ],
                ),
              ),

              // Total and Checkout button on separate rows
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 4.0),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total: $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(displayTotalAmount))}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8.0),

                    if (hasUnavailable)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          'Some items in your cart are no longer available. Please remove them to continue to checkout.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton(
                        onPressed: hasUnavailable
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Some items in your cart are no longer available. Please remove them to continue to checkout.',
                                    ),
                                  ),
                                );
                              }
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CheckoutPage(
                                      tAmount: displayTotalAmount,
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasUnavailable
                              ? Colors.grey
                              : const Color(0xFFFFA500),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          hasUnavailable
                              ? 'Resolve unavailable items'
                              : 'Checkout ($totalUniqueItems)',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
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
  );
},

      ),
    );
  }

  Map<String, List<QueryDocumentSnapshot>> _groupItemsByStore(
      List<QueryDocumentSnapshot> items) {
    final Map<String, List<QueryDocumentSnapshot>> groupedItems = {};

    for (var item in items) {
      final data = item.data() as Map<String, dynamic>;
      final storeName = data['storeName'] ?? 'Unknown Store';

      if (!groupedItems.containsKey(storeName)) {
        groupedItems[storeName] = [];
      }

      groupedItems[storeName]!.add(item);
    }

    return groupedItems;
  }

  // Ensure currency data is loaded first before using it
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

// Function to apply the conversion
  double _convertPrice(double price) {
    if (exchangeRate != null) {
      return price * exchangeRate!;
    }
    return price; // Default price without conversion
  }

  Future<int> _getProductMinQuantity(String productId) async {
    final productRef =
        FirebaseFirestore.instance.collection('products').doc(productId);
    final productDoc = await productRef.get();
    if (productDoc.exists) {
      final data = productDoc.data() as Map<String, dynamic>;
      return data['productminquantity'] ?? 1;
    }
    return 1; // Default minimum quantity if not specified
  }

void _updateQuantity(String cartItemId, int newQuantity) async {
  try {
    final cartItemRef =
        FirebaseFirestore.instance.collection('cartitems').doc(cartItemId);
    final docSnapshot = await cartItemRef.get();
    final data = docSnapshot.data() as Map<String, dynamic>;

    final double unitPrice =
        (data['totalPrice'] / (data['quantity'] ?? 1)).toDouble();
    final double newTotalPrice = unitPrice * newQuantity;

    await cartItemRef.update({
      'quantity': newQuantity,
      'totalPrice': newTotalPrice,
    });

    _revalidatePromoAfterCartChange();
  } catch (e) {
    print('Error updating quantity: $e');
  }
}


 void _deleteCartItem(String cartItemId) async {
  try {
    await FirebaseFirestore.instance
        .collection('cartitems')
        .doc(cartItemId)
        .delete();

    _revalidatePromoAfterCartChange();
  } catch (e) {
    print('Error deleting cart item: $e');
  }
}


void _revalidatePromoAfterCartChange() async {
  if (!_isPromoApplied || _appliedPromoCode == null) return;

  final cartSnapshot = await FirebaseFirestore.instance
      .collection('cartitems')
      .where('userId', isEqualTo: userId)
      .get();

  double newTotal = 0.0;
  for (var doc in cartSnapshot.docs) {
    final data = doc.data();
    newTotal += (data['totalPrice'] ?? 0.0).toDouble();
  }

  final promoDoc = await FirebaseFirestore.instance
      .collection('promo_codes')
      .where('code', isEqualTo: _appliedPromoCode)
      .limit(1)
      .get();

  if (promoDoc.docs.isEmpty) return;

  final promoData = promoDoc.docs.first.data();
  final rawMinOrderValue = (promoData['minOrderValue'] as num).toDouble();
  final minOrderValue = _convertPrice(rawMinOrderValue);
  final discountType = promoData['discountType'] as String;
  final discountValue = (promoData['value'] as num).toDouble();

  // ❌ Invalidate promo if cart total is now below minimum
  if (newTotal < minOrderValue) {
    setState(() {
      _isPromoApplied = false;
      _appliedPromoCode = null;
      _discountAmount = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Promo code has been removed as your cart total is below $currencySymbol${minOrderValue.toStringAsFixed(2)}.'),
        backgroundColor: Colors.red,
      ),
    );

    // Remove promoCodeUsed field from cart items
    for (var doc in cartSnapshot.docs) {
      await doc.reference.update({'promoCodeUsed': FieldValue.delete()});
    }

    return;
  }

  // ✅ Recalculate discount
  final adjustedDiscount = discountType == 'percentage'
      ? newTotal * (discountValue / 100)
      : discountValue;

  // Avoid negative totals
  final safeDiscount = adjustedDiscount > newTotal ? newTotal : adjustedDiscount;

  setState(() {
    _discountAmount = safeDiscount;
  });
}


Future<bool> _validatePromoCode(String code, double totalAmount) async {
  try {
    final promoCodeDoc = await FirebaseFirestore.instance
        .collection('promo_codes')
        .where('code', isEqualTo: code)
        .where('isActive', isEqualTo: true)
        .get();

    if (promoCodeDoc.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid or inactive promo code'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final data = promoCodeDoc.docs.first.data();
    final expiryDate = (data['expiryDate'] as Timestamp).toDate();
    final rawMinOrderValue = (data['minOrderValue'] as num).toDouble();
    final minOrderValue = _convertPrice(rawMinOrderValue); // 👈 Converted
    final discountType = data['discountType'] as String;
    final discountValue = (data['value'] as num).toDouble();
    final currentUserUsage = data['usersUsed'][userId] ?? 0;
    final usagePerUser = data['usagePerUser'] as int;

    // ✅ Check if promo code already applied to the cart
    final cartSnapshot = await FirebaseFirestore.instance
        .collection('cartitems')
        .where('userId', isEqualTo: userId)
        .get();

    final alreadyUsedInCart = cartSnapshot.docs.any((doc) {
      final cartData = doc.data();
      return cartData['promoCodeUsed'] == code;
    });

    if (alreadyUsedInCart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You’ve already applied this promo code to your cart.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (DateTime.now().isAfter(expiryDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promo code has expired'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (totalAmount < minOrderValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Minimum order value is $currencySymbol${minOrderValue.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (currentUserUsage >= usagePerUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promo code usage limit reached'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // ✅ Calculate discount
    setState(() {
      _discountAmount = discountType == 'percentage'
          ? totalAmount * (discountValue / 100)
          : discountValue;
      _appliedPromoCode = code;
    });

    // ✅ Update each cart item with the promo code used
    for (var doc in cartSnapshot.docs) {
      await doc.reference.update({'promoCodeUsed': code});
    }

    // ✅ Update promo usage in Firestore
    _updatePromoCodeUsage(code);

    // ✅ Log usage in discounts collection
    await FirebaseFirestore.instance.collection('discounts').add({
      'userId': userId,
      'date': Timestamp.now(),
      'discountAmount': _discountAmount,
      'promoCode': code,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Promo Code applied successfully'),
        backgroundColor: Colors.green,
      ),
    );

    return true;
  } catch (e) {
    print('Error validating promo code: $e');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('An error occurred while validating the promo code'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
}


  void _updatePromoCodeUsage(String promoCode) async {
    final promoCodeRef = _firestore.collection('promo_codes').doc(promoCode);
    await promoCodeRef.update({
      'usersUsed.$userId': FieldValue.increment(1),
      'usageLimit': FieldValue.increment(-1),
    });
  }

  //added 23 01 2025
}
