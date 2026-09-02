import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs; // Use alias
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/auth/auth_gate.dart';
import 'package:tremsolapp/services/app_colors.dart';
import 'package:tremsolapp/shop/productsearch_page.dart';


import '../auxilliary/in-app-firestore/fbnotification_model.dart';
import '../auxilliary/in-app-firestore/fbnotification_screen.dart';


import 'cartpage.dart';
import 'flashdeals_seeall.dart';
import 'profile_screen.dart';
import 'specialproducts_screen.dart';
import 'bulkbuypage_seeall.dart';
import 'mediaslider.dart';
import 'subcategory_screen.dart';
import 'product_details_screen.dart'; // Make sure to create this screen separately
import 'dart:async';

import 'trendingpage_seeall.dart';
import 'weeklypage_seeall.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../common/timed_builders.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';


class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _reloadToken = 0;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedCategories =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  bool _categoriesLoading = true;
  Object? _categoriesError;

  Query<Map<String, dynamic>> get _categoryQuery => FirebaseFirestore.instance
      .collection('prdcategory')
      .where('isPublish', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(12);

  Future<void> _loadCategoriesCacheFirst() async {
    QuerySnapshot<Map<String, dynamic>>? cachedSnapshot;

    try {
      cachedSnapshot = await _categoryQuery.get(
        const GetOptions(source: Source.cache),
      );

      if (mounted && cachedSnapshot.docs.isNotEmpty) {
        setState(() {
          _cachedCategories = cachedSnapshot!.docs;
          _categoriesLoading = false;
          _categoriesError = null;
        });
        _precacheCategoryImages(cachedSnapshot.docs);
      }
    } catch (error) {
      debugPrint('[Categories] Cache read unavailable: $error');
    }

    try {
      final serverSnapshot = await _categoryQuery.get(
        const GetOptions(source: Source.server),
      );

      if (!mounted) return;
      setState(() {
        _cachedCategories = serverSnapshot.docs;
        _categoriesLoading = false;
        _categoriesError = null;
      });
      _precacheCategoryImages(serverSnapshot.docs);
    } catch (error) {
      debugPrint('[Categories] Server refresh failed: $error');
      if (!mounted) return;

      // Keep showing cached categories when the network is unavailable.
      if (_cachedCategories.isEmpty &&
          (cachedSnapshot == null || cachedSnapshot.docs.isEmpty)) {
        setState(() {
          _categoriesLoading = false;
          _categoriesError = error;
        });
      }
    }
  }

  void _retryCategories() {
    setState(() {
      _categoriesLoading = _cachedCategories.isEmpty;
      _categoriesError = null;
    });
    _loadCategoriesCacheFirst();
  }

  void _precacheCategoryImages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final doc in docs) {
        final imageUrl = (doc.data()['image'] ?? '').toString().trim();
        if (imageUrl.isEmpty) continue;
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        ).catchError((_) {});
      }
    });
  }

  static const Color _premiumNavy = Color(0xFF0B1F3A);
  static const Color _premiumNavyLight = Color(0xFF173B69);
  static const Color _premiumGold = Color(0xFFF2A900);
  static const Color _pageBackground = Color(0xFFF5F7FB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF667085);
  static const Color _borderColor = Color(0xFFE8ECF2);

  List<BoxShadow> get _softShadow => [
        BoxShadow(
          color: const Color(0xFF0B1F3A).withOpacity(0.08),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  Color _sectionAccent(String key, Color fallback) {
    try {
      return AppColors().getColor(key);
    } catch (_) {
      return fallback;
    }
  }

  Widget _topActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.10),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _countBadge({
    required Widget child,
    required int count,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: -4,
            top: -5,
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE5484D),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _premiumNavy, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _premiumLoader({double height = 130}) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: _premiumNavy,
          ),
        ),
      ),
    );
  }

  Widget _networkImageFallback({double iconSize = 34}) {
    return Container(
      color: const Color(0xFFF0F2F6),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: iconSize,
        color: const Color(0xFF98A2B3),
      ),
    );
  }


 Future<void> _signOut() async {
  try {
    // Optional: also sign out provider SDKs so their sessions aren’t kept
    //try { await GoogleSignIn().signOut(); } catch (_) {}
    //try { await FacebookAuth.instance.logOut(); } catch (_) {}

    await FirebaseAuth.instance.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isSignedIn');      // AuthGate doesn’t use this anyway
    // Do NOT reset isFirstAccess; you want it to stay false after first run.

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign out failed: $e')),
    );
  }
}

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// ==== CURRENCY (centralized) ====
  String currencySymbol = 'GHS';
  double exchangeRate = 1.0;
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


  double _convertPrice(num? price) {
    if (price == null) return 0.0;
    return price.toDouble() * exchangeRate;
  }

//added 15-12-24
  String? selectedColor;
  String? selectedSize;

  void _placeOrder(Map<String, dynamic> productData, int quantity) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showError("User not signed in");
      return;
    }

    // Check if the product has color or size options
    final hasColors = productData['product_colors'] != null &&
        (productData['product_colors'] as List).isNotEmpty;
    final hasSizes = productData['product_sizes'] != null &&
        (productData['product_sizes'] as List).isNotEmpty;

    // If color or size selection is required but not made, navigate to ProductDetailsScreen
    if ((hasColors && selectedColor == null) ||
        (hasSizes && selectedSize == null)) {
      _showError("Please select a color and size before adding to cart.");
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ProductDetailsScreen(productId: productData['id']),
        ),
      );
      return;
    }

    try {
      // Check if the product already exists in the cart for this user with selected options
      final cartQuerySnapshot = await FirebaseFirestore.instance
          .collection('cartitems')
          .where('userId', isEqualTo: userId)
          .where('productId', isEqualTo: productData['id'])
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
          //newly added line
          'productprice': productData['productprice'] ?? 0,
          'tax': productData['tax'] ?? 0,
          'cost_per_item': productData['cost_per_item'] ?? 0,
          //newly added line
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

  //18-9-2025 ADVERT
  Map<String, dynamic>? adData;

  late String userId;

 
 @override
void initState() {
  super.initState();

  // Warm category metadata + images from Firestore/image cache first,
  // then refresh them from the server without blocking the home screen.
  _loadCategoriesCacheFirst();

  // Load currency ONCE
  _loadCurrencyData();

  // AD setup (your existing code)
  _checkAndShowAd();


  final FirebaseAuth auth = FirebaseAuth.instance;
  final User? currentUser = auth.currentUser;

  if (currentUser != null) {
    userId = currentUser.uid;
  } else {
    userId = '';
  }

  FirebaseFirestore.instance
      .collection('bg_colors')
      .doc('kNsqJFo4m8LCZmG38Yvr')
      .snapshots()
      .listen((snapshot) {
    if (snapshot.exists) {
      AppColors().updateColors(snapshot.data()!);
      setState(() {});
    }
  });
}


  /*Future<void> _checkAndShowAd() async {
print('🟢 _checkAndShowAd was called');


    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get the last ad display time
    String? lastAdTime = prefs.getString('lastAdTime');
    DateTime now = DateTime.now();

   print('🔵 Attempting to fetch ad from Firestore...');
try {
  QuerySnapshot snapshot = await FirebaseFirestore.instance
      .collection('ads')
      .orderBy('priority')
      .limit(1)
      .get();

  print('🟣 Snapshot received with ${snapshot.docs.length} docs');

  if (snapshot.docs.isNotEmpty) {
    adData = snapshot.docs.first.data() as Map<String, dynamic>;
    print('🟢 Ad data: $adData');

    _showAdModal(adData!);

    prefs.setString('lastAdTime', now.toIso8601String());
  } else {
    print('⚪️ No ads found in Firestore');
  }
} catch (e) {
  print('🔥 Error fetching ad: $e');
}

  }*/

  Future<void> _checkAndShowAd() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get the last ad display time
    String? lastAdTime = prefs.getString('lastAdTime');
    DateTime now = DateTime.now();

    // Fetch ad from Firestore to get interval value
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('ads')
          .orderBy('priority')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        adData = snapshot.docs.first.data() as Map<String, dynamic>;

        // Get the interval in seconds from the ad data, defaulting to 172800 (48 hours)
        int intervalSeconds = adData!['interval'] ?? 172800;

        // Check if the interval has elapsed
       if (lastAdTime != null && lastAdTime.isNotEmpty) {
  final DateTime? lastShown = DateTime.tryParse(lastAdTime);

  if (lastShown != null &&
      now.difference(lastShown).inSeconds < intervalSeconds) {
    return;
  }
}
        // Show the ad modal
        _showAdModal(adData!);

        // Save the current time as the last ad display time
        prefs.setString('lastAdTime', now.toIso8601String());
      }
    } catch (e) {
      debugPrint('Error fetching ad: $e');
    }
  }

  // Fetch an ad from Firestore and show it as a modal
/*  Future<void> _fetchAndShowAd() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('ads')
        //  .orderBy('priority')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          adData = snapshot.docs.first.data() as Map<String, dynamic>;
        });

        // Show the modal dialog with the fetched ad data
        _showAdModal(adData!);
      }
    } catch (e) {
      debugPrint('Error fetching ad: $e');
    }
  }*/

  /* void _showAdModal(Map<String, dynamic> ad) {
  try {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Stack(
          children: [
            Container(color: Colors.black.withOpacity(0.6)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ad['image'] != null)
                    CachedNetworkImage(
                      imageUrl: ad['image'],
                      // ...
                    ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  )
                ],
              ),
            ),
          ],
        );
      },
    );
  } catch (e) {
    print('🔥 Modal rendering failed: $e');
  }
}*/

  void _showAdModal(Map<String, dynamic> ad) {
    final String productId = (ad['productId'] ??
            ad['productID'] ??
            ad['product_id'] ??
            '')
        .toString()
        .trim();

    final bool isClickable = productId.isNotEmpty;
    final BuildContext pageContext = context;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: isClickable
                      ? () {
                          Navigator.of(dialogContext).pop();

                          Future.microtask(() {
                            if (!mounted) return;

                            Navigator.of(pageContext).push(
                              MaterialPageRoute(
                                builder: (_) => ProductDetailsScreen(
                                  productId: productId,
                                ),
                              ),
                            );
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.24),
                          blurRadius: 34,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ad['image'] != null &&
                              ad['image'].toString().trim().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: ad['image'].toString().trim(),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height:
                                  MediaQuery.of(dialogContext).size.height *
                                      0.52,
                              placeholder: (context, url) => _premiumLoader(
                                height:
                                    MediaQuery.of(dialogContext).size.height *
                                        0.52,
                              ),
                              errorWidget: (context, url, error) =>
                                  _networkImageFallback(iconSize: 50),
                            )
                          : _networkImageFallback(iconSize: 50),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -14,
                right: -10,
                child: Material(
                  color: _premiumNavy,
                  shape: const CircleBorder(),
                  elevation: 8,
                  child: InkWell(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  //18-9-2025 ADVERT

//added 21 01 2025 for notifications
  int _getUnreadCount(List<NotificationModel> notifications) {
    return notifications
        .where((notification) =>
            (notification.receiverIds == null ||
                notification.receiverIds!.contains(userId)) &&
            !notification.readBy.contains(userId))
        .length;
  }

//added 29 11 2025

Stream<List<NotificationModel>> _getNotificationsStream() {
  final user = FirebaseAuth.instance.currentUser;

  // If nobody is logged in, just return an empty stream (or handle as you like)
  if (user == null) {
    return Stream<List<NotificationModel>>.value(<NotificationModel>[]);
    // or: return const Stream.empty();  // also works in recent Dart
  }

  final String currentUserId = user.uid;

  return FirebaseFirestore.instance
      .collection('notifications')
      .orderBy('timestamp', descending: true)
      .limit(30)
      .snapshots()
      .map((querySnapshot) {
        return querySnapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc.data(), doc.id))
            .where((notification) =>
                notification.receiverIds == null ||
                notification.receiverIds!.contains(currentUserId))
            .toList();
      });
}


//added 21 01 2025 for notifications

//commented 15 04 2025
/*  bool isLoading = true;

  Future<void> _loadData() async {
    // Simulate loading for all streams and async calls
    await Future.wait([
      _getNotificationsStream().first, // Fetch notifications
//_getCartItems().first, // Fetch cart items
      Future.delayed(Duration(seconds: 2)), // Simulate additional loading
    ]);

    setState(() {
      isLoading = false; // Once all data is loaded, remove the indicator
    });
  }*/


  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;
    final categoryAccent =
        _sectionAccent('category', const Color(0xFF2563EB));
    final topGradientStart =
        Color.lerp(categoryAccent, _premiumNavy, 0.72)!;
    final topGradientEnd =
        Color.lerp(categoryAccent, _premiumNavyLight, 0.48)!;
    final topSafeArea = MediaQuery.of(context).padding.top;
    final expandedHeaderHeight = topSafeArea + 108.0;
    final collapsedHeaderHeight = topSafeArea + 54.0;
    // The actual Store/Social bar belongs to the parent screen. Keep only a
    // small safe-area allowance here so this page does not waste shopping space.
    final bottomClearance = MediaQuery.of(context).viewPadding.bottom + 24.0;
    final notificationsStream = _getNotificationsStream();
    final Stream<QuerySnapshot>? cartStream = currentUser != null
        ? _firestore
            .collection('cartitems')
            .where('userId', isEqualTo: currentUser.uid)
            .snapshots()
        : null;

    Widget buildSearchBar() {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrdSearchPage(),
              ),
            );
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.09),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: _premiumNavy,
                  size: 21,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Search products or brands',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: _premiumNavy,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildExpandedActions(double visibility) {
      return IgnorePointer(
        ignoring: visibility < 0.45,
        child: Opacity(
          opacity: visibility,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - visibility)),
            child: Row(
              children: [
                _topActionButton(
                  icon: Icons.person_outline_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreenPage(),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      height: 30,
                      width: 132,
                      child: Image.asset(
                        'assets/logoappbar.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'TREMSOL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                StreamBuilder<List<NotificationModel>>(
                  stream: notificationsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Material(
                        color: Colors.white.withOpacity(0.12),
                        shape: const CircleBorder(),
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }

                    int unreadCount = 0;
                    if (snapshot.hasData) {
                      unreadCount = _getUnreadCount(snapshot.data!);
                    }

                    if (unreadCount > 0) {
                      FlutterAppBadger.updateBadgeCount(unreadCount);
                    } else {
                      FlutterAppBadger.removeBadge();
                    }

                    return _countBadge(
                      count: unreadCount,
                      child: _topActionButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const FBNotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 7),
                StreamBuilder<QuerySnapshot>(
                  stream: cartStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Material(
                        color: Colors.white.withOpacity(0.12),
                        shape: const CircleBorder(),
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }

                    final cartCount =
                        snapshot.hasData ? snapshot.data!.docs.length : 0;

                    return _countBadge(
                      count: cartCount,
                      child: _topActionButton(
                        icon: Icons.shopping_cart_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CartPage(),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            primary: true,
            pinned: true,
            floating: false,
            snap: false,
            toolbarHeight: 54,
            expandedHeight: 108,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: topGradientStart,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final currentHeight = constraints.biggest.height;
                final range =
                    expandedHeaderHeight - collapsedHeaderHeight;
                final visibility = range <= 0
                    ? 0.0
                    : ((currentHeight - collapsedHeaderHeight) / range)
                        .clamp(0.0, 1.0)
                        .toDouble();

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [topGradientStart, topGradientEnd],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 14,
                        right: 14,
                        top: topSafeArea + 2,
                        child: buildExpandedActions(visibility),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 7,
                        child: buildSearchBar(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MediaSliderss(),
                  ),
                ),
                const SizedBox(height: 5),
                _buildSectionHeader(
                  'SHOP BY CATEGORY',
                  icon: Icons.grid_view_rounded,
                  accentColor: _sectionAccent(
                    'category',
                    const Color(0xFF2563EB),
                  ),
                  showSeeAll: false,
                ),
                _buildCategorySection(context),
                _buildSectionHeader(
                  'BULK BUY',
                  icon: Icons.inventory_2_outlined,
                  accentColor: _sectionAccent(
                    'bulk',
                    const Color(0xFF7C3AED),
                  ),
                  onSeeAllPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BulkBuyPage(),
                      ),
                    );
                  },
                ),
                _buildBulkBuySection(context),
                _buildDealsSection('Flash', context),
                _buildSectionHeader(
                  'SPECIAL DEALS',
                  icon: Icons.auto_awesome_rounded,
                  accentColor: _sectionAccent(
                    'special',
                    const Color(0xFFEA580C),
                  ),
                  showSeeAll: false,
                ),
                _buildSpecialDealsSection(context),
                _buildSectionHeader(
                  'WEEKLY DEALS',
                  icon: Icons.calendar_month_outlined,
                  accentColor: _sectionAccent(
                    'weekly',
                    const Color(0xFF059669),
                  ),
                  onSeeAllPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WeeklyDealsPage(),
                      ),
                    );
                  },
                ),
                _buildWeeklyDealsSection(),
                _buildSectionHeader(
                  'TRENDING DEALS',
                  icon: Icons.trending_up_rounded,
                  accentColor: _sectionAccent(
                    'trending',
                    const Color(0xFFDB2777),
                  ),
                  onSeeAllPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrendingDealsPage(),
                      ),
                    );
                  },
                ),
                _buildTrendingProductGrid(),
                SizedBox(height: bottomClearance),
              ],
            ),
          ),
        ],
      ),
    );
  }

//THIS IS THE MAIN PART

  //WEEKLY SECTION BEGIN
  //modified 15-12-24
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

  Widget _buildWeeklyDealsSection() {
    const int maxWeeklyItems = 15;

    return TimedStreamBuilder<QuerySnapshot>(
      key: ValueKey('weekly-$_reloadToken'),
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('producttag',
              arrayContainsAny: ['Weekly', 'weekly', 'WEEKLY'])
          .where('isPublish', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(maxWeeklyItems)
          .snapshots(),
      timeout: const Duration(seconds: 15),
      onTimeout: (_) => FirestoreErrorCard(
        error: Exception('timeout'),
        onRetry: () => setState(() => _reloadToken++),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FirestoreErrorCard(
            error: snapshot.error!,
            onRetry: () => setState(() => _reloadToken++),
          );
        }
        if (!snapshot.hasData) {
          return _premiumLoader(height: 170);
        }

        final products = snapshot.data!.docs;
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: GridView.builder(
            padding: EdgeInsets.zero,
            primary: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.58,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final name = (product['productname'] ?? '').toString();
              final imageUrl = (product['image'] ?? '').toString();

              final productPrice =
                  (product['productprice'] as num?)?.toDouble() ?? 0.0;
              final tax = (product['tax'] as num?)?.toDouble() ?? 0.0;
              final iniSellingprice = productPrice + tax;
              final finSellingprice =
                  (product['productsellingprice'] as num?)?.toDouble() ?? 0.0;

              final discountedPrice =
                  (product['productdiscprice'] is String
                          ? double.tryParse(product['productdiscprice'] ?? '0')
                          : (product['productdiscprice'] as num?)?.toDouble()) ??
                      0.0;

              final discountedPercentage = (iniSellingprice > 0 &&
                      finSellingprice > 0 &&
                      discountedPrice > 0)
                  ? ((iniSellingprice - finSellingprice) / iniSellingprice) *
                      100
                  : 0.0;

              final hasDiscount = discountedPercentage > 0 &&
                  discountedPercentage < 100;
              final currentPrice =
                  hasDiscount ? finSellingprice : iniSellingprice;

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailsScreen(productId: product.id),
                      ),
                    );
                  },
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor),
                      boxShadow: _softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    _premiumLoader(height: 100),
                                errorWidget: (context, url, error) =>
                                    _networkImageFallback(),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.04),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (hasDiscount)
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5484D),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '-${discountedPercentage.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _capitalizeFirstLetter(name),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(currentPrice))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _premiumNavy,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (hasDiscount)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(iniSellingprice))}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 9.5,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  //WEEKLY SECTION END
  //TRENDING SECTION  BEGINING

  Widget _buildTrendingProductGrid() {
    const int displayLimit = 42;
    final screenWidth = MediaQuery.of(context).size.width;
    const int crossAxisCount = 2;
    final double childAspectRatio = screenWidth / (screenWidth * 1.42);

    final settingsRef =
        FirebaseFirestore.instance.collection('settings').doc('homepage');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: settingsRef.snapshots(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data?.data() ?? const {};
        final String trendingSort =
            (settings['trendingSort'] ?? 'mostOrdered').toString();
        final bool override = settings['trendingOverride'] == true;

        Query<Map<String, dynamic>> base = FirebaseFirestore.instance
            .collection('products')
            .where(
              'producttag',
              arrayContainsAny: ['Trending', 'trending', 'TRENDING'],
            )
            .where('isPublish', isEqualTo: true);

        Query<Map<String, dynamic>> query;
        if (override) {
          query = base
              .where('trendingRank', isGreaterThan: -1)
              .orderBy('trendingRank')
              .limit(displayLimit);
        } else {
          switch (trendingSort) {
            case 'mostViewed':
              query = base
                  .orderBy('viewsCount', descending: true)
                  .limit(displayLimit);
              break;
            case 'priceAsc':
              query = base
                  .orderBy('productsellingprice', descending: false)
                  .limit(displayLimit);
              break;
            case 'mostOrdered':
            default:
              query = base
                  .orderBy('ordersCount', descending: true)
                  .limit(displayLimit);
              break;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _premiumLoader(height: 190);
            }
            final products = snapshot.data!.docs;

            if (products.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                primary: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final m = product.data();

                  final name = (m['productname'] ?? '').toString();
                  final imageUrl = (m['image'] ?? '').toString();

                  final productPrice =
                      (m['productprice'] as num?)?.toDouble() ?? 0.0;
                  final tax = (m['tax'] as num?)?.toDouble() ?? 0.0;
                  final iniSellingprice = productPrice + tax;
                  final finSellingprice =
                      (m['productsellingprice'] as num?)?.toDouble() ?? 0.0;

                  final discountedPercentage = (iniSellingprice > 0 &&
                          finSellingprice > 0)
                      ? ((iniSellingprice - finSellingprice) /
                              iniSellingprice) *
                          100
                      : 0.0;

                  final productState = (m['productstate'] ?? '').toString();
                  final double? rating = (m['rating'] is num)
                      ? (m['rating'] as num).toDouble()
                      : null;
                  final bool hasRating = rating != null && rating > 0;

                  final hasDiscount = discountedPercentage > 0 &&
                      discountedPercentage < 100;
                  final currentPrice =
                      hasDiscount ? finSellingprice : iniSellingprice;

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductDetailsScreen(productId: product.id),
                          ),
                        );
                      },
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _borderColor),
                          boxShadow: _softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        _premiumLoader(height: 160),
                                    errorWidget: (context, url, error) =>
                                        _networkImageFallback(iconSize: 42),
                                  ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.08),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (productState.isNotEmpty)
                                    Positioned(
                                      left: 9,
                                      top: 9,
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 92),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.94),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: _borderColor,
                                          ),
                                        ),
                                        child: Text(
                                          productState.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _premiumNavy,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (hasDiscount)
                                    Positioned(
                                      right: 9,
                                      top: 9,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE5484D),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '-${discountedPercentage.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 11, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _capitalizeFirstLetter(name),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 13,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(currentPrice))}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _premiumNavy,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      if (hasDiscount)
                                        Expanded(
                                          child: Text(
                                            '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(iniSellingprice))}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: _textSecondary,
                                              fontSize: 11,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        )
                                      else
                                        const Spacer(),
                                      if (hasRating) ...[
                                        const Icon(
                                          Icons.star_rounded,
                                          color: _premiumGold,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          rating!.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: _textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ] else ...[
                                        const Icon(
                                          Icons.star_rounded,
                                          color: _textSecondary,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 2),
                                        const Text(
                                          'Not rated',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }


//END OF THE MAIN PART
  Widget _buildDealsSection(String dealTag, BuildContext context) {
    final flashAccent =
        _sectionAccent('flash', const Color(0xFFE5484D));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [flashAccent, Color.lerp(flashAccent, _premiumNavy, 0.42)!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: flashAccent.withOpacity(0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FLASH DEALS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const _FlashDealsCountdown(),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FlashDealsPage(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SEE ALL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildFlashShopProductItem(),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildFlashShopProductItem() {
    const int maxFlashItems = 10;

    return TimedStreamBuilder<QuerySnapshot>(
      key: ValueKey('flash-$_reloadToken'),
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('producttag', arrayContainsAny: ['Flash', 'flash', 'FLASH'])
          .where('isPublish', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(maxFlashItems)
          .snapshots(),
      timeout: const Duration(seconds: 15),
      onTimeout: (_) => FirestoreErrorCard(
        error: Exception('timeout'),
        onRetry: () => setState(() => _reloadToken++),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FirestoreErrorCard(
            error: snapshot.error!,
            onRetry: () => setState(() => _reloadToken++),
          );
        }
        if (!snapshot.hasData) {
          return _premiumLoader(height: 215);
        }

        final products = snapshot.data!.docs;
        if (products.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: MediaQuery.of(context).size.width * 0.50,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              final name = (product['productname'] ?? '').toString();
              final imageUrl = (product['image'] ?? '').toString();

              final productPrice =
                  (product['productprice'] as num?)?.toDouble() ?? 0.0;
              final tax = (product['tax'] as num?)?.toDouble() ?? 0.0;
              final iniSellingprice = productPrice + tax;
              final finSellingprice =
                  (product['productsellingprice'] as num?)?.toDouble() ?? 0.0;

              final discountedPercentage = (iniSellingprice > 0 &&
                      finSellingprice > 0)
                  ? ((iniSellingprice - finSellingprice) / iniSellingprice) *
                      100
                  : 0.0;

              final hasDiscount = discountedPercentage > 0 &&
                  discountedPercentage < 100;
              final currentPrice =
                  hasDiscount ? finSellingprice : iniSellingprice;

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailsScreen(productId: product.id),
                      ),
                    );
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.39,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _borderColor),
                      boxShadow: _softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    _premiumLoader(height: 120),
                                errorWidget: (context, url, error) =>
                                    _networkImageFallback(iconSize: 40),
                              ),
                              if (hasDiscount)
                                Positioned(
                                  top: 9,
                                  right: 9,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5484D),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '-${discountedPercentage.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _capitalizeFirstLetter(name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(currentPrice))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasDiscount
                                      ? const Color(0xFFE5484D)
                                      : _premiumNavy,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (hasDiscount)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(iniSellingprice))}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 10.5,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

// Capitalize the first letter of each word in the product name
  String _capitalizeFirstLetter(String input) {
    return input
        .split(' ')
        .map((str) =>
            str.isNotEmpty ? str[0].toUpperCase() + str.substring(1) : '')
        .join(' ');
  }

//THE END

  Widget _buildSpecialDealsSection(BuildContext context) {
    const int maxSpecialItems = 10;

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('specialproducts')
          .limit(maxSpecialItems)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _premiumLoader(height: 148);
        }

        if (snapshot.hasError) {
          return const SizedBox(
            height: 110,
            child: Center(
              child: Text(
                'Failed to load special deals',
                style: TextStyle(
                  color: Color(0xFFE5484D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final specialProducts = snapshot.data!.docs;
        final double viewportWidth = MediaQuery.of(context).size.width;

        return SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            scrollDirection: Axis.horizontal,
            itemCount: (specialProducts.length / 2).ceil(),
            separatorBuilder: (context, index) =>
                const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final firstProduct = specialProducts[index * 2];
              final int secondIndex = index * 2 + 1;
              final QueryDocumentSnapshot? secondProduct =
                  secondIndex < specialProducts.length
                      ? specialProducts[secondIndex]
                      : null;

              return Container(
                width: viewportWidth - 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: _premiumNavy.withOpacity(0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildSpecialProductItem(
                          context,
                          firstProduct,
                        ),
                      ),
                      if (secondProduct != null)
                        Expanded(
                          child: _buildSpecialProductItem(
                            context,
                            secondProduct,
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
  }

  Widget _buildSpecialProductItem(
    BuildContext context,
    QueryDocumentSnapshot product,
  ) {
    final String imageUrl =
        (product['imagepath'] ?? '').toString().trim();

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SpecialDealsScreen(),
            ),
          );
        },
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          placeholder: (context, url) => _premiumLoader(height: 144),
          errorWidget: (context, url, error) =>
              _networkImageFallback(iconSize: 42),
        ),
      ),
    );
  }

  Widget _buildMediaSlider() {
    return cs.CarouselSlider(
      options: cs.CarouselOptions(
        height: 200.0,
        autoPlay: true,
        enlargeCenterPage: true,
      ),
      items: [
        'https://firebasestorage.googleapis.com/v0/b/social-apps-77d9c.appspot.com/o/specialproducts%2Fsecond.jpg?alt=media&token=d6701cd1-bf6d-45d1-89e8-16aafa7b8087',
        'https://firebasestorage.googleapis.com/v0/b/social-apps-77d9c.appspot.com/o/specialproducts%2Fsecond.jpg?alt=media&token=d6701cd1-bf6d-45d1-89e8-16aafa7b8087',
        'https://firebasestorage.googleapis.com/v0/b/social-apps-77d9c.appspot.com/o/specialproducts%2Fsecond.jpg?alt=media&token=d6701cd1-bf6d-45d1-89e8-16aafa7b8087',
      ].map((item) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: const BoxDecoration(
                color: Colors.amber,
              ),
              child: CachedNetworkImage(
                imageUrl: item,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    VoidCallback? onSeeAllPressed,
    bool showSeeAll = true,
    IconData icon = Icons.local_mall_outlined,
    Color accentColor = _premiumNavy,
  }) {
    final Color gradientEnd =
        Color.lerp(accentColor, Colors.black, 0.22) ?? accentColor;
    final bool useDarkContent = accentColor.computeLuminance() > 0.62;
    final Color foreground =
        useDarkContent ? _premiumNavy : Colors.white;
    final Color mutedForeground =
        useDarkContent ? _premiumNavy.withOpacity(0.72) : Colors.white70;

    return Padding(
      // Keep the compact spacing pattern from the original page.
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 3),
      child: Container(
        height: 46,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // The database colour remains the dominant section colour.
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [accentColor, gradientEnd],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.20),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -35,
              child: Container(
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foreground.withOpacity(0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 7, 5),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: foreground.withOpacity(
                        useDarkContent ? 0.10 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: foreground.withOpacity(0.14),
                      ),
                    ),
                    child: Icon(icon, color: foreground, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.40,
                      ),
                    ),
                  ),
                  if (showSeeAll && onSeeAllPressed != null)
                    TextButton(
                      onPressed: onSeeAllPressed,
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        backgroundColor: foreground.withOpacity(
                          useDarkContent ? 0.10 : 0.12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                          side: BorderSide(
                            color: foreground.withOpacity(0.12),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SEE ALL',
                            style: TextStyle(
                              color: foreground,
                              fontSize: 9.6,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.20,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: mutedForeground,
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context) {
    if (_categoriesLoading && _cachedCategories.isEmpty) {
      return _premiumLoader(height: 180);
    }

    if (_categoriesError != null && _cachedCategories.isEmpty) {
      return FirestoreErrorCard(
        error: _categoriesError!,
        onRetry: _retryCategories,
      );
    }

    final categories = _cachedCategories;
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.90,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final data = category.data();
          final categoryId = category.id;
          final categoryName = (data['name'] ?? '').toString();
          final imageUrl = (data['image'] ?? '').toString();

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubcategoryScreen(
                  categoryId: categoryId,
                  categoryName: categoryName,
                ),
              ),
            ),
            child: _buildCategoryItem(
              context,
              categoryName,
              imageUrl,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    String categoryName,
    String imageUrl,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _borderColor),
        boxShadow: _softShadow,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => _premiumLoader(height: 120),
            errorWidget: (context, url, error) =>
                _networkImageFallback(iconSize: 40),
          ),
          // Keep almost the whole category image visible. The dark scrim
          // is deliberately restricted to a very short strip at the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    Colors.transparent,
                    _premiumNavy.withOpacity(0.46),
                    _premiumNavy.withOpacity(0.92),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 7,
            height: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkBuySection(BuildContext context) {
    const int maxBulkItems = 12;

    return TimedStreamBuilder<QuerySnapshot>(
      key: ValueKey('bulk-$_reloadToken'),
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('producttag', arrayContainsAny: ['Bulk', 'bulk', 'BULK'])
          .where('isPublish', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(maxBulkItems)
          .snapshots(),
      timeout: const Duration(seconds: 15),
      onTimeout: (_) => FirestoreErrorCard(
        error: Exception('timeout'),
        onRetry: () => setState(() => _reloadToken++),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FirestoreErrorCard(
            error: snapshot.error!,
            onRetry: () => setState(() => _reloadToken++),
          );
        }
        if (!snapshot.hasData) {
          return _premiumLoader(height: 170);
        }

        final products = snapshot.data!.docs;
        if (products.isEmpty) return const SizedBox.shrink();

        final cardWidth = MediaQuery.of(context).size.width * 0.29;

        return SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductItem(
                context,
                (product['productname'] ?? '').toString(),
                (product['image'] ?? '').toString(),
                (product['productsellingprice'] as num?)?.toDouble() ?? 0.0,
                product,
                cardWidth: cardWidth,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductItem(
    BuildContext context,
    String name,
    String imageUrl,
    double price,
    QueryDocumentSnapshot product, {
    required double cardWidth,
  }) {
    final convertedPrice = _convertPrice(price);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProductDetailsScreen(productId: product.id),
            ),
          );
        },
        child: Container(
          width: cardWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: _premiumNavy.withOpacity(0.06),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _premiumLoader(height: 105),
                  errorWidget: (context, url, error) =>
                      _networkImageFallback(iconSize: 30),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalizeFirstLetter(name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$currencySymbol ${NumberFormat("#,##0.00").format(convertedPrice)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _premiumNavy,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildAdSlider() {
    return cs.CarouselSlider(
      options: cs.CarouselOptions(
        height: 200.0,
        autoPlay: true,
        enlargeCenterPage: true,
      ),
      items: [
        'https://firebasestorage.googleapis.com/v0/b/social-apps-77d9c.appspot.com/o/specialproducts%2Fsecond.jpg?alt=media&token=d6701cd1-bf6d-45d1-89e8-16aafa7b8087',
        'https://firebasestorage.googleapis.com/v0/b/social-apps-77d9c.appspot.com/o/specialproducts%2Fsecond.jpg?alt=media&token=d6701cd1-bf6d-45d1-89e8-16aafa7b8087',
        'https://firebasestorage.googleapis.com/v0/b/social-apps-77d9c.appspot.com/o/specialproducts%2Fsecond.jpg?alt=media&token=d6701cd1-bf6d-45d1-89e8-16aafa7b8087',
      ].map((item) {
        return Builder(
          builder: (BuildContext context) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                ),
                child: CachedNetworkImage(
                  imageUrl: item,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child:
                        Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

/// A lifecycle-aware, repeating two-hour countdown for the Flash Deals banner.
///
/// The timer is aligned to local two-hour windows (00:00–02:00, 02:00–04:00,
/// and so on), so every customer sees the same end time. It automatically
/// begins the next cycle and resynchronizes when the app returns from the
/// background.
class _FlashDealsCountdown extends StatefulWidget {
  const _FlashDealsCountdown();

  @override
  State<_FlashDealsCountdown> createState() =>
      _FlashDealsCountdownState();
}

class _FlashDealsCountdownState extends State<_FlashDealsCountdown>
    with WidgetsBindingObserver {
  static const Duration _cycleDuration = Duration(hours: 2);
  static const Color _countdownTextColor = Color(0xFF0B1F3A);

  Timer? _ticker;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCountdown();
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncCountdown(),
    );
  }

  int _calculateRemainingSeconds() {
    final now = DateTime.now();
    final secondsSinceMidnight =
        (now.hour * 3600) + (now.minute * 60) + now.second;
    final cycleSeconds = _cycleDuration.inSeconds;
    final elapsedInCurrentCycle = secondsSinceMidnight % cycleSeconds;

    // At the exact boundary, immediately begin the next full cycle.
    return cycleSeconds - elapsedInCurrentCycle;
  }

  void _syncCountdown() {
    final nextValue = _calculateRemainingSeconds();

    if (!mounted || nextValue == _remainingSeconds) return;

    setState(() {
      _remainingSeconds = nextValue;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Mobile operating systems may pause Dart timers in the background.
      // Recreate and immediately resync the ticker when the app resumes.
      _syncCountdown();
      _startTicker();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Row(
      children: [
        const Text(
          'ENDS IN  ',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: _countdownTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
