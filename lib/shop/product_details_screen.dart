import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cartpage.dart';
import 'ratingandreview.dart';
import 'custom_videowidget.dart';
import 'wishlist.page.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  _ProductDetailsScreenState createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int quantity = 1;
  int? productMinQuantity;
  String? selectedColor;
  String? selectedSize;
  bool isBulkProduct = false;

  //uncommented 10 02 2025
  bool isLiked = false; // Initial state for "Liked" status
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? currencySymbol;
  double? exchangeRate;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
      _similarProductsFuture;

  late ValueNotifier<bool> isLikedNotifier;
//added 22-12-2024
//commented 10 02 2024
  // late bool isLiked;

  @override
  void initState() {
    super.initState();
    _fetchLikeStatus();
    _loadCurrencyData();
    //   getcurrentuseruid();
    isLikedNotifier = ValueNotifier(false);

    _fetchInitialLikeStatus();
    //added 29 09 2025
    _bumpViewOnce(); // <-- add this line
  }

//added 21 03 2025
  @override
  void dispose() {
    isLikedNotifier.dispose();
    super.dispose();
  }



  // Add near the top of the State class:
  //30 09 2025
static final Set<String> _seenProducts = <String>{};

Future<void> _bumpViewOnce() async {
  // Only bump once per app session per productId
  if (_seenProducts.contains(widget.productId)) return;
  _seenProducts.add(widget.productId);

  try {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .update({'viewsCount': FieldValue.increment(1)});
  } catch (_) {
    // optional: log or ignore
  }
}

//added on 21 03 2025

  void _fetchInitialLikeStatus() async {
    var firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      DocumentSnapshot document =
          await productscollection.doc(widget.productId).get();
      List likes = List.from(document['likes'] ?? []);
      isLikedNotifier.value = likes.contains(firebaseUser.uid);
    }
  }

  // getcurrentuseruid() async {
  //   var firebaseuser = await FirebaseAuth.instance.currentUser;
  //   setState(() {
  //     uid = firebaseuser!.uid;

  //     //addtoquantity();
  //   });
  // }

  final CollectionReference productscollection =
      FirebaseFirestore.instance.collection('products');

  void likePost() async {
    var firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    DocumentSnapshot document =
        await productscollection.doc(widget.productId).get();
    List likes = List.from(document['likes'] ?? []);

    if (likes.contains(firebaseUser.uid)) {
      await productscollection.doc(widget.productId).update({
        'likes': FieldValue.arrayRemove([firebaseUser.uid])
      });
      isLikedNotifier.value = false; // Update ValueNotifier
    } else {
      await productscollection.doc(widget.productId).update({
        'likes': FieldValue.arrayUnion([firebaseUser.uid])
      });
      isLikedNotifier.value = true; // Update ValueNotifier
    }
  }

//==============

//added 08-12-2024
  // Function to load currency data
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


  double _convertPrice(double price) {
    if (exchangeRate != null) {
      return price * exchangeRate!;
    }
    return price; // Default price without conversion
  }

  // Fetch the initial "Like" status from Firestore
  void _fetchLikeStatus() async {
    if (currentUser != null) {
      final likeDoc = await _firestore
          .collection('likes')
          .doc('${currentUser!.uid}_${widget.productId}')
          .get();

      setState(() {
        isLiked = likeDoc.exists; // Only set to true if the document exists
      });
    }
  }

  //added 15-12-2024
  void toggleLikeStatus(String productId) async {
    if (isLiked) {
      // Unlike: Remove the user's UID from the "likes" array
      await _firestore.collection('products').doc(productId).update({
        'likes': FieldValue.arrayRemove([currentUser!.uid]),
      });
    } else {
      // Like: Add the user's UID to the "likes" array
      await _firestore.collection('products').doc(productId).update({
        'likes': FieldValue.arrayUnion([currentUser!.uid]),
      });
    }

    // Update the local state
    setState(() {
      isLiked = !isLiked;
    });
  }

Future<void> _makeCall() async {
  try {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('settings')
        .doc('doc7')
        .get();

    String? phoneNumber = snapshot['company_phone'];

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      debugPrint('Phone number fetched: $phoneNumber');
      
      Uri phoneUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );

      bool canLaunchUri = await canLaunchUrl(phoneUri);
      debugPrint('Can launch: $canLaunchUri');

      if (await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      )) {
        debugPrint('Dialer opened successfully.');
      } else {
        debugPrint('Failed to open the dialer.');
      }
    } else {
      debugPrint('Phone number not found or empty.');
    }
  } catch (e) {
    debugPrint('Error occurred: $e');
  }
}



  //added 22-12-2024
  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return ''; // Handle empty string case

    return input
        .split(' ')
        .where((word) => word.isNotEmpty) // Ensure empty words are removed
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
            color: Colors.white), // Sets the back arrow color to white
        backgroundColor: const Color(0xFF002A5C), // Navy blue from logo
        title: const Text('Details',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.favorite_border_outlined,
            ),
          onPressed: () {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in or create an account to view your wishlist.'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WishlistPage(userId: currentUser.uid),
    ),
  );
},

          ),
          const SizedBox(width: 20,),
          StreamBuilder<QuerySnapshot>(
                    stream: currentUser != null // Check if user is signed in
                        ? _firestore
                            .collection('cartitems')
                            .where('userId', isEqualTo: currentUser.uid)
                            .snapshots()
                        : null, // If no user, don't create a Firestore stream
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(); // Show a loading spinner while waiting
                      }

                      int cartCount =
                          snapshot.hasData ? snapshot.data!.docs.length : 0;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const CartPage()),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right:20.0),
                              child: Icon(Icons.shopping_cart_outlined,
                                  color: Colors.white, size: 25),
                            ),
                          ),
                          if (cartCount > 0)
                            Positioned(
                              //right: -1,
                              left:15,
                              top: -7,
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(2.0),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '$cartCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  )
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Product not found'));
          }

          final productData = snapshot.data!.data() as Map<String, dynamic>;

          //commented 10 03 2025
          productMinQuantity = productData['productminquantity'] ?? 1;

          //added 10 03 2025
          //productMinQuantity =
          // (productData['productminquantity'] as num?)?.toInt() ?? 1;

          //commented 10 03 2025
          //isBulkProduct = productData['producttag'] == 'Bulk';
          //quantity = isBulkProduct ? productMinQuantity! : 1;

          //added 10 03 2025
          // Ensure producttag is a list and check if it contains 'Bulk'
          List<String> productTags =
              (productData['producttag'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];

          isBulkProduct = productTags.contains('Bulk');
          quantity = isBulkProduct ? (productMinQuantity ?? 1) : 1;

          //added 08-12-2024
          double productsellingprice = _convertPrice(
            (productData['productsellingprice'] as num?)?.toDouble() ?? 0,
          );

          double productdisprice = _convertPrice(
            (productData['productdiscprice'] as num?)?.toDouble() ?? 0,
          );

          double productprice = _convertPrice(
            (productData['productprice'] as num?)?.toDouble() ?? 0,
          );
          double producttax = _convertPrice(
            (productData['tax'] as num?)?.toDouble() ?? 0,
          );

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product media (video and images)
                  //commented 2 03 2025
                  // _buildProductMedia(
                  //     productData['video_url'], productData['images']),

                  ProductMediaWidget(
                      videoUrl: productData['video_url'],
                      images: productData['images']),
                  const SizedBox(height: 5),
                  Text(
                    _capitalizeFirstLetter(
                        productData['productname'] ?? 'No Name'),
                    style: const TextStyle(
                      fontSize: 18,
                      //fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment
                        .spaceBetween, // Space between elements
                    children: [
                 Text(
  '$currencySymbol ${(productdisprice > 0) 
    ? NumberFormat("#,##0.00").format(productsellingprice) 
    : NumberFormat("#,##0.00").format(productprice + producttax)}',
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  ),
),

                      Container(
                          padding: const EdgeInsets.all(
                              8), // Adjust padding for size
                          decoration: const BoxDecoration(
                            color:
                                Color(0xFFFFEDEE), // Light red background
                            shape: BoxShape.circle, // Circular shape
                          ),
                          child:

//added 21 03 2025
                      ValueListenableBuilder<bool>(
  valueListenable: isLikedNotifier ?? ValueNotifier(false), // Provide fallback value
  builder: (context, isLiked, child) {
    return IconButton(
      icon: Icon(
        isLiked ? Icons.favorite : Icons.favorite_border,
        color: isLiked ? Colors.red : Colors.grey,
      ),
      onPressed: () {
        var firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in or create an account to add product to wishlist'),
              duration: Duration(seconds: 2),
            ),
          );
          return; // Stop execution if user is null
        }
        likePost(); // Call likePost function if user is signed in
      },
    );
  },
),

//==========================
                          /*  GestureDetector(
                            onTap: () => toggleLikeStatus(widget.productId),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                    0xFFFFEDEE), // Light red background
                                shape: BoxShape.circle, // Circular shape
                              ),
                              child: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.grey,
                                size: 24,
                              ),
                            ),
                          )*/

                          ),
                    ],
                  ),

const SizedBox(height: 5),

// ✅ Expected Delivery Period
if (productData['delivery_days'] != null)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        children: [
          const TextSpan(
            text: 'Expected Delivery: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text:
                'Within ${(double.parse(productData['delivery_days'].toString()) * 24).round()} hours',
          ),
        ],
      ),
    ),
  ),




                  const SizedBox(height: 5),



                  ProductDescriptionWidget(
                      description: _capitalizeFirstLetter(
                          productData['productdescription'])),
                  // _buildProductDescription(),
                  const SizedBox(height: 10),
                  _buildProductColors(productData['product_colors']),
                  const SizedBox(height: 10),
                  _buildProductSizes(productData['product_sizes']),
                  const SizedBox(height: 10),
           Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // Rating and purchase check
    FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('ratingreview')
          .where('productId', isEqualTo: widget.productId)
          .get(),
      builder: (context, ratingSnapshot) {
        if (ratingSnapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final hasRatings = ratingSnapshot.hasData &&
            ratingSnapshot.data!.docs.isNotEmpty;

        final reviews = hasRatings ? ratingSnapshot.data!.docs : [];
        final totalRatings = reviews.length;
        final sumRatings = reviews.fold<double>(
          0.0,
          (sum, doc) =>
              sum + (doc.data() as Map<String, dynamic>)['rating'],
        );
        final averageRating =
            totalRatings > 0 ? sumRatings / totalRatings : 0.0;

        final ratingContent = Row(
          children: [
            Row(
              children: List.generate(1, (index) {
                return Icon(
                  Icons.star,
                  color: index < averageRating
                      ? Colors.orange
                      : Colors.grey,
                  size: 24,
                );
              }),
            ),
            const SizedBox(width: 5),
            Text(
              hasRatings
                  ? '(${averageRating.toStringAsFixed(1)}, $totalRatings ratings)'
                  : '(No ratings yet)',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        );

        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          // Not logged in: show non-clickable rating
          return ratingContent;
        }

        // Step 2: Check if current user ordered & it was delivered
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('ordersitems')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'Delivered')
              .get(),
          builder: (context, orderSnapshot) {
            bool hasOrderedAndDelivered = false;

            if (orderSnapshot.hasData) {
              for (var doc in orderSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final items = data['items'] as List<dynamic>;
                for (var item in items) {
                  if (item is Map &&
                      item['productId'] == widget.productId) {
                    hasOrderedAndDelivered = true;
                    break;
                  }
                }
                if (hasOrderedAndDelivered) break;
              }
            }

           return GestureDetector(
  onTap: () {
  Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ReviewsPage(
      productId: widget.productId,
      canPostReview: hasOrderedAndDelivered,
    ),
  ),
);
  },
  child: ratingContent,
);

          },
        );
      },
    ),

    const SizedBox(width: 10),

    // Quantity selector
    Expanded(
      flex: 1,
      child: _buildQuantitySelector(),
    ),
  ],
),

                  const SizedBox(height: 26),
                  _buildSimilarProducts(productData),
                  const SizedBox(height: 20),

                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const SizedBox
                .shrink(); // Hide the button until data is ready
          }

          final productData = snapshot.data!.data() as Map<String, dynamic>;

          return SafeArea(
            child: Container(
              color: Colors.white, // Background color of the button bar
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Home button with outline
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color.fromARGB(255, 250, 133, 43),
                          width: 1),
                      borderRadius: BorderRadius.circular(10), // Rounded corners
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context); // Perform the back arrow function
                      },
                      icon: const Icon(Icons.home,
                          color: Color.fromARGB(255, 250, 133, 43)),
                      tooltip: 'Back',
                    ),
                  ),
            
                  // Call to Order button with outline
                  Container(
                    margin: const EdgeInsets.only(
                        left: 10), // Spacing between buttons
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color.fromARGB(255, 250, 133, 43),
                          width: 1),
                      borderRadius: BorderRadius.circular(10), // Rounded corners
                    ),
                    child: IconButton(
                      onPressed: () {
                        _makeCall(); // Call function logic
                      },
                      icon: const Icon(
                        Icons.call,
                        color: Color.fromARGB(255, 250, 133, 43),
                      ),
                      tooltip: 'Call to Order',
                    ),
                  ),
            
                  // Spacer to push "Add to Cart" to occupy the remaining space
                  const SizedBox(
                      width: 10), // Optional: spacing before the button
            
                  // Add to Cart button with increased height
               Expanded(
              child: SizedBox(
                height: 50, // Adjust height as needed
                child: ElevatedButton.icon(
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
                    _placeOrder(productData, quantity); // Proceed if user is signed in
                  },
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  label: const Text(
                    "Add To Cart",
                    style: TextStyle(
            fontSize: 18,
            color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 250, 133, 43),
                    shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
                    ),
                  ),
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
  }

  // Widget _buildProductMedia(String? videoUrl, List<dynamic>? images) {
  //   double screenHeight = MediaQuery.of(context).size.height;
  //   PageController _pageController = PageController();
  //   int totalItems = (videoUrl != null && videoUrl.isNotEmpty ? 1 : 0) +
  //       (images?.length ?? 0);
  //   int _currentPage = 0;

  //   if (totalItems == 0) {
  //     return Container(
  //       height: screenHeight * 0.25, // 25% of screen height
  //       color: Colors.grey[200],
  //       child: const Center(child: Text('No media available')),
  //     );
  //   }

  //   return SizedBox(
  //     height: screenHeight * 0.4, // 40% of screen height
  //     child: Stack(
  //       children: [
  //         PageView.builder(
  //           controller: _pageController,
  //           itemCount: totalItems,
  //           onPageChanged: (index) {
  //             _currentPage = index;
  //           },
  //           itemBuilder: (context, index) {
  //             if (index == 0 && videoUrl != null && videoUrl.isNotEmpty) {
  //               return SizedBox(
  //                 height: screenHeight * 0.4, // Match parent height
  //                 child: VideoWidget(videoUrl: videoUrl),
  //               );
  //             } else {
  //               final imageIndex =
  //                   index - (videoUrl != null && videoUrl.isNotEmpty ? 1 : 0);
  //               return Container(
  //                 margin: const EdgeInsets.all(2),
  //                 decoration: BoxDecoration(
  //                   borderRadius: BorderRadius.circular(8),
  //                   image: DecorationImage(
  //                     image: NetworkImage(images![imageIndex]),
  //                     fit: BoxFit.contain,
  //                   ),
  //                 ),
  //               );
  //             }
  //           },
  //         ),

  //         // Overlay for "Item X/Y"
  //         Positioned(
  //           top: 10,
  //           right: 10,
  //           child: Container(
  //             padding: const EdgeInsets.all(6),
  //             decoration: BoxDecoration(
  //               color: Colors.black.withOpacity(0.7),
  //               borderRadius: BorderRadius.circular(5),
  //             ),
  //             child: StatefulBuilder(
  //               builder: (context, setState) {
  //                 return Text(
  //                   'Item ${_currentPage + 1}/$totalItems',
  //                   style: const TextStyle(fontSize: 16, color: Colors.white),
  //                 );
  //               },
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }


  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchSimilarProducts(
    Map<String, dynamic> currentProduct,
  ) async {
    final String subcategoryId =
        (currentProduct['productsubcat'] ?? '').toString().trim();
    final String categoryId =
        (currentProduct['productcategory'] ?? '').toString().trim();

    if (subcategoryId.isEmpty && categoryId.isEmpty) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }

    final CollectionReference<Map<String, dynamic>> products =
        _firestore.collection('products');

    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
        uniqueProducts =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    Future<void> addProductsFromQuery(
      Query<Map<String, dynamic>> query,
    ) async {
      final QuerySnapshot<Map<String, dynamic>> result =
          await query.limit(20).get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in result.docs) {
        if (document.id == widget.productId) {
          continue;
        }

        uniqueProducts.putIfAbsent(
          document.id,
          () => document,
        );

        if (uniqueProducts.length >= 8) {
          break;
        }
      }
    }

    // First use the more specific subcategory match.
    if (subcategoryId.isNotEmpty) {
      try {
        await addProductsFromQuery(
          products
              .where(
                'productsubcat',
                isEqualTo: subcategoryId,
              )
              .where(
                'isPublish',
                isEqualTo: true,
              ),
        );
      } catch (error) {
        debugPrint(
          'Unable to load products from the same subcategory: $error',
        );
      }
    }

    // Fill the remaining spaces with products from the same category.
    if (uniqueProducts.length < 8 && categoryId.isNotEmpty) {
      try {
        await addProductsFromQuery(
          products
              .where(
                'productcategory',
                isEqualTo: categoryId,
              )
              .where(
                'isPublish',
                isEqualTo: true,
              ),
        );
      } catch (error) {
        debugPrint(
          'Unable to load products from the same category: $error',
        );
      }
    }

    return uniqueProducts.values.take(8).toList();
  }

  Widget _buildSimilarProducts(
    Map<String, dynamic> currentProduct,
  ) {
    _similarProductsFuture ??=
        _fetchSimilarProducts(currentProduct);

    return FutureBuilder<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _similarProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Similar Products',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002A5C),
                ),
              ),
              SizedBox(height: 18),
              Center(
                child: CircularProgressIndicator(),
              ),
              SizedBox(height: 18),
            ],
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            'Error displaying similar products: ${snapshot.error}',
          );
          return const SizedBox.shrink();
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>>
            similarProducts =
            snapshot.data ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (similarProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Similar Products',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002A5C),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: similarProducts.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (context, index) {
                final QueryDocumentSnapshot<Map<String, dynamic>>
                    document = similarProducts[index];
                final Map<String, dynamic> product = document.data();

                final String productName =
                    (product['productname'] ?? 'Unnamed Product')
                        .toString();

                String imageUrl =
                    (product['image'] ?? '').toString().trim();

                final dynamic images = product['images'];
                if (imageUrl.isEmpty &&
                    images is List &&
                    images.isNotEmpty) {
                  imageUrl = images.first.toString().trim();
                }

                final double sellingPrice =
                    _asDouble(product['productsellingprice']);
                final double discountPrice =
                    _asDouble(product['productdiscprice']);
                final double regularPrice =
                    _asDouble(product['productprice']);
                final double tax = _asDouble(product['tax']);

                final double baseDisplayPrice =
                    discountPrice > 0 && sellingPrice > 0
                        ? sellingPrice
                        : (regularPrice + tax) > 0
                            ? regularPrice + tax
                            : sellingPrice;

                final double convertedPrice =
                    _convertPrice(baseDisplayPrice);

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailsScreen(
                            productId: document.id,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: imageUrl.isEmpty
                                ? Container(
                                    color: Colors.grey.shade100,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey,
                                      size: 35,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) {
                                      return Container(
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                    errorWidget: (context, url, error) {
                                      return Container(
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey,
                                          size: 35,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                9,
                                10,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _capitalizeFirstLetter(productName),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.25,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${currencySymbol ?? 'GHS'} '
                                    '${NumberFormat("#,##0.00").format(convertedPrice)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF4E00),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

//commented 10 03 2025
  Widget _buildQuantitySelector() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            //  const Text('Quantity:', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                // Decrease button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isBulkProduct && quantity > productMinQuantity!) {
                        quantity--;
                      } else if (!isBulkProduct && quantity > 1) {
                        quantity--;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isBulkProduct
                                  ? 'Cannot decrease quantity below the minimum of $productMinQuantity for bulk products.'
                                  : 'Cannot decrease quantity below 1.',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, // Light grey background
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.remove, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12), // Spacing between buttons and text

                // Quantity display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade100, // Light background for quantity
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quantity.toString(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),

                // Increase button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      quantity++;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, // Light grey background
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.add, color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /* Widget _buildQuantitySelector() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Decrease button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isBulkProduct && quantity > productMinQuantity) {
                        quantity--;
                      } else if (!isBulkProduct && quantity > 1) {
                        quantity--;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isBulkProduct
                                  ? 'Cannot decrease quantity below the minimum of $productMinQuantity for bulk products.'
                                  : 'Cannot decrease quantity below 1.',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, // Light grey background
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.remove, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),

                // Quantity display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade100, // Light background for quantity
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quantity.toString(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),

                // Increase button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      quantity++; // No upper limit applied here
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, // Light grey background
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.add, color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }*/

  Widget _buildProductImages(List<dynamic>? images) {
    if (images == null || images.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(child: Text('No images available')),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Container(
            width: 200,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: CachedNetworkImage(
              imageUrl: images[index].toString(),
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
          );
        },
      ),
    );
  }

  Widget _buildProductDescription(String? description) {
    if (description == null || description.isEmpty) {
      return const Text('No description available');
    }

    return Text(
      description,
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildProductColors(List<dynamic>? colors) {
    if (colors == null || colors.isEmpty) {
      return const SizedBox.shrink();
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return Row(
          children: [
            const Text('Colors: ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 5.0,
              children: colors.map((color) {
                // Convert the color code to a Color object
                Color parsedColor = _parseColor(color);

                return ChoiceChip(
                  label: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: parsedColor,
                    ),
                  ),
                  selected: selectedColor == color,
                  onSelected: (isSelected) {
                    setState(() {
                      selectedColor = isSelected ? color.toString() : null;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

// Method to parse the color code
  Color _parseColor(String colorCode) {
    // Remove the leading '#' if it exists and parse as a hex color
    if (colorCode.startsWith('#')) {
      colorCode = colorCode.substring(1);
    }

    // Check if the color code is 6 characters long and parse
    if (colorCode.length == 6) {
      return Color(int.parse('0xFF$colorCode'));
    } else {
      // Return a default color if the code is invalid
      return Colors.black;
    }
  }

  Widget _buildProductSizes(List<dynamic>? sizes) {
    if (sizes == null || sizes.isEmpty) {
      return const SizedBox.shrink();
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return Row(
          children: [
            const Text('Sizes: ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 5.0,
              children: sizes.map((size) {
                return ChoiceChip(
                  label: Text(size.toString()),
                  selected: selectedSize == size,
                  onSelected: (isSelected) {
                    setState(() {
                      selectedSize = isSelected ? size.toString() : null;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

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
          .where('productId', isEqualTo: widget.productId)
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
          'productId': widget.productId,
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
       // title: const Text('Error'),
         title: const Text(
        'Oops!',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
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




}

class ProductDescriptionWidget extends StatefulWidget {
  final String? description;

  const ProductDescriptionWidget({super.key, this.description});

  @override
  _ProductDescriptionWidgetState createState() =>
      _ProductDescriptionWidgetState();
}

class _ProductDescriptionWidgetState extends State<ProductDescriptionWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.description == null || widget.description!.isEmpty) {
      return const Text('No description available');
    }

    // Determine how much text to show based on expansion state
    final textToShow = _isExpanded
        ? widget.description
        : (widget.description!.length > 100
            ? '${widget.description!.substring(0, 100)}...'
            : widget.description);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textToShow!,
          style: const TextStyle(fontSize: 16),
        ),
        if (widget.description!.length >
            100) // Show the "Show More" button only if the text is long
          TextButton(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? 'Show Less' : 'Show More',
              style: const TextStyle(
                  fontSize: 14, color: Color.fromARGB(255, 0, 60, 109)),
            ),
          ),
      ],
    );
  }
}

class ProductMediaWidget extends StatefulWidget {
  final String? videoUrl;
  final List<dynamic>? images;

  const ProductMediaWidget({super.key, this.videoUrl, this.images});

  @override
  _ProductMediaWidgetState createState() => _ProductMediaWidgetState();
}

class _ProductMediaWidgetState extends State<ProductMediaWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  int totalItems = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    totalItems =
        (widget.videoUrl != null && widget.videoUrl!.isNotEmpty ? 1 : 0) +
        (widget.images?.length ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    if (totalItems == 0) {
      return Container(
        height: screenHeight * 0.53,
        color: Colors.grey[200],
        child: const Center(child: Text('No media available')),
      );
    }

    return SizedBox(
      height: screenHeight * 0.53,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: totalItems,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              if (index == 0 &&
                  widget.videoUrl != null &&
                  widget.videoUrl!.isNotEmpty) {
                return SizedBox(
                  height: screenHeight * 0.53,
                  child: VideoWidget(
                    videoUrl: widget.videoUrl!,
                    posterUrl: (widget.images != null && widget.images!.isNotEmpty)
                        ? widget.images!.first.toString()
                        : null,
                  ),
                );
              } else {
                final imageIndex = index -
                    (widget.videoUrl != null && widget.videoUrl!.isNotEmpty ? 1 : 0);
                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(
                        widget.images![imageIndex],
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }
            },
          ),

          // Overlay for "Item X/Y"
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Item ${_currentPage + 1}/$totalItems',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
