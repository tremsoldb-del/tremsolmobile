import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../homescreen.dart';
import 'checkoutpage.dart';
import 'wishlist.page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const Color _navy = Color(0xFF002A5C);
  static const Color _orange = Color(0xFFFFA500);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _promoCodeController = TextEditingController();
  final FocusNode _promoFocusNode = FocusNode();
  final ValueNotifier<bool> _isApplyingPromo = ValueNotifier<bool>(false);

  String currencySymbol = 'GHS';
  double exchangeRate = 1.0;
  bool _currencyLoaded = false;

  String? _appliedPromoCode;
  DocumentReference<Map<String, dynamic>>? _appliedPromoReference;
  double _discountAmount = 0.0;
  bool _isPromoApplied = false;

  String _productLookupSignature = '';
  Future<Map<String, _CartProductState>>? _productLookupFuture;

  @override
  void initState() {
    super.initState();
    _loadCurrencyData();
  }

  @override
  void dispose() {
    _promoFocusNode.dispose();
    _isApplyingPromo.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencyData() async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString('baseCurrency') ?? 'GHS';
    final selected = prefs.getString('selectedCurrency') ?? base;
    final rate = prefs.getDouble('conversionRate') ?? 1.0;

    if (!mounted) return;
    setState(() {
      currencySymbol = selected;
      exchangeRate = rate;
      _currencyLoaded = true;
    });
  }

  double _convertPrice(num value) => value.toDouble() * exchangeRate;

  String _formatAmount(num amount) {
    return NumberFormat('#,##0.00').format(_convertPrice(amount));
  }

  String _capitalizeWords(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Color? _parseSelectedColor(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    try {
      final normalized = raw
          .replaceFirst('#', '')
          .replaceFirst('0x', '')
          .replaceFirst('0X', '');
      final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
      if (hex.length != 8) return null;
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, _CartProductState>> _productLookupFor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cartDocs,
  ) {
    final ids = cartDocs
        .map((doc) => (doc.data()['productId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final signature = ids.join('|');
    if (_productLookupFuture == null || signature != _productLookupSignature) {
      _productLookupSignature = signature;
      _productLookupFuture = _loadProductStates(ids);
    }

    return _productLookupFuture!;
  }

  Future<Map<String, _CartProductState>> _loadProductStates(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return <String, _CartProductState>{};

    final result = <String, _CartProductState>{};

    // Load products in small Firestore batches so the cart waits once instead
    // of showing a separate spinner for every item.
    const batchSize = 10;
    for (var start = 0; start < productIds.length; start += batchSize) {
      final end = math.min(start + batchSize, productIds.length);
      final batchIds = productIds.sublist(start, end);

      final snapshot = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();

      for (final document in snapshot.docs) {
        result[document.id] = _CartProductState.fromDocument(document);
      }

      for (final productId in batchIds) {
        result.putIfAbsent(
          productId,
          () => const _CartProductState.missing(),
        );
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return _buildSignedOutPage();
    }

    final userId = currentUser.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('cartitems')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, cartSnapshot) {
        if (cartSnapshot.hasError) {
          return _buildErrorScaffold(
            userId: userId,
            message: 'Unable to load your cart. Please try again.',
          );
        }

        if (cartSnapshot.connectionState == ConnectionState.waiting ||
            !cartSnapshot.hasData) {
          return _buildLoadingScaffold(userId);
        }

        final cartDocs = cartSnapshot.data!.docs;
        if (cartDocs.isEmpty) {
          return _buildEmptyCartScaffold(userId);
        }

        return FutureBuilder<Map<String, _CartProductState>>(
          future: _productLookupFor(cartDocs),
          builder: (context, productsSnapshot) {
            if (productsSnapshot.hasError) {
              return _buildErrorScaffold(
                userId: userId,
                itemCount: cartDocs.length,
                message:
                    'Some product information could not be loaded. Please try again.',
              );
            }

            // Do not block the entire cart on the secondary product lookup.
            // Cart documents already contain the display data needed to paint
            // the page. Product availability is verified in the background.
            final isCheckingProducts =
                productsSnapshot.connectionState == ConnectionState.waiting ||
                    !productsSnapshot.hasData;
            final productStates =
                productsSnapshot.data ?? <String, _CartProductState>{};
            final hasUnavailable = !isCheckingProducts &&
                cartDocs.any((doc) {
                  final productId =
                      (doc.data()['productId'] ?? '').toString().trim();
                  return !(productStates[productId]?.isAvailable ?? false);
                });

            final totalAmount = cartDocs.fold<double>(0.0, (sum, document) {
              final value = document.data()['totalPrice'];
              return sum + (value is num ? value.toDouble() : 0.0);
            });

            final safeDiscount = math.min(_discountAmount, totalAmount);
            final displayTotal = math.max(0.0, totalAmount - safeDiscount);

            return Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: const Color(0xFFFFF8FF),
              appBar: _buildAppBar(
                userId: userId,
                itemCount: cartDocs.length,
              ),
              // Keep the cart footer inside the resizable body instead of
              // bottomNavigationBar. On iOS the software keyboard can cover a
              // Scaffold bottomNavigationBar; putting the footer in the body
              // makes it move above the keyboard automatically.
              body: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        setState(() {
                          _productLookupSignature = '';
                          _productLookupFuture = null;
                        });
                        await _productLookupFor(cartDocs);
                      },
                      child: ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                        itemCount: cartDocs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cartDocument = cartDocs[index];
                          final productId =
                              (cartDocument.data()['productId'] ?? '')
                                  .toString()
                                  .trim();
                          final productState = productStates[productId] ??
                              const _CartProductState.provisional();

                          return _buildCartItem(
                            cartDocument: cartDocument,
                            productState: productState,
                            userId: userId,
                          );
                        },
                      ),
                    ),
                  ),
                  _buildCartFooter(
                    cartDocs: cartDocs,
                    totalAmount: totalAmount,
                    displayTotal: displayTotal,
                    hasUnavailable: hasUnavailable,
                    isCheckingProducts: isCheckingProducts,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Scaffold _buildSignedOutPage() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Cart',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: _navy,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.remove_shopping_cart, size: 80, color: Colors.grey),
              SizedBox(height: 18),
              Text(
                'Please sign in or create an account to access your cart.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Scaffold _buildLoadingScaffold(String userId, {int itemCount = 0}) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FF),
      appBar: _buildAppBar(userId: userId, itemCount: itemCount),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount > 0 ? math.min(itemCount, 4) : 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _CartItemLoadingCard(),
      ),
    );
  }

  Scaffold _buildErrorScaffold({
    required String userId,
    required String message,
    int itemCount = 0,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FF),
      appBar: _buildAppBar(userId: userId, itemCount: itemCount),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _productLookupSignature = '';
                    _productLookupFuture = null;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Scaffold _buildEmptyCartScaffold(String userId) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(userId: userId, itemCount: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 86,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nothing to show here right now.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WishlistPage(userId: userId),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _navy),
                    ),
                    child: const Text('Check Wishlist'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start Shopping'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required String userId,
    required int itemCount,
  }) {
    return AppBar(
      title: Text(
        itemCount > 0 ? 'Cart ($itemCount)' : 'Cart',
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      backgroundColor: _navy,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.favorite_border_outlined),
              tooltip: 'Wishlist',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WishlistPage(userId: userId),
                  ),
                );
              },
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('products')
                  .where('likes', arrayContains: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                if (count <= 0) return const SizedBox.shrink();

                return Positioned(
                  right: 4,
                  top: 5,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Home',
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildCartItem({
    required QueryDocumentSnapshot<Map<String, dynamic>> cartDocument,
    required _CartProductState productState,
    required String userId,
  }) {
    final data = cartDocument.data();
    final productId = (data['productId'] ?? '').toString().trim();
    final productName = _capitalizeWords(
      (data['productName'] ?? productState.name ?? 'Product').toString(),
    );
    final description =
        (data['productDescription'] ?? productState.description ?? '')
            .toString()
            .trim();
    final productImage =
        (data['productImage'] ?? productState.imageUrl ?? '').toString().trim();
    final quantityValue = data['quantity'];
    final quantity = quantityValue is num ? quantityValue.toInt() : 1;
    final priceValue = data['totalPrice'];
    final totalPrice = priceValue is num ? priceValue.toDouble() : 0.0;
    final color = _parseSelectedColor(data['selectedColor']);
    final selectedSize = (data['selectedSize'] ?? '').toString().trim();
    final isUnavailable = !productState.isAvailable;

    var isLiked = productState.likes.contains(userId);

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Opacity(
          opacity: isUnavailable ? 0.64 : 1,
          child: Card(
            elevation: 1.5,
            margin: EdgeInsets.zero,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: productImage.isEmpty
                            ? const _ProductImageFallback()
                            : CachedNetworkImage(
                                imageUrl: productImage,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const _ProductImageFallback(),
                                errorWidget: (_, __, ___) =>
                                    const _ProductImageFallback(
                                  icon: Icons.broken_image_outlined,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    productName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                if (!isUnavailable && !isLiked)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    icon: const Icon(
                                      Icons.favorite_border,
                                      size: 21,
                                    ),
                                    onPressed: () async {
                                      final changed = await _toggleLikeStatus(
                                        productId: productId,
                                        isLiked: isLiked,
                                      );
                                      if (changed && mounted) {
                                        setLocalState(() => isLiked = true);
                                      }
                                    },
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.grey,
                                    size: 21,
                                  ),
                                  onPressed: () =>
                                      _confirmDeleteCartItem(cartDocument.id),
                                ),
                              ],
                            ),
                            if (description.isNotEmpty && !isUnavailable) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                            if (isUnavailable) ...[
                              const SizedBox(height: 5),
                              const Text(
                                'This product is no longer available',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (color != null || selectedSize.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (color != null)
                                    _CartAttributeChip(
                                      label: 'Color',
                                      color: color,
                                    ),
                                  if (selectedSize.isNotEmpty)
                                    _CartAttributeChip(
                                      label: 'Size: $selectedSize',
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$currencySymbol ${_formatAmount(totalPrice)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202027),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove, size: 19),
                              onPressed: isUnavailable
                                  ? null
                                  : () => _decreaseQuantity(
                                        productId: productId,
                                        cartItemId: cartDocument.id,
                                        quantity: quantity,
                                      ),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$quantity',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add, size: 19),
                              onPressed: isUnavailable
                                  ? null
                                  : () => _updateQuantity(
                                        cartDocument.id,
                                        quantity + 1,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartFooter({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cartDocs,
    required double totalAmount,
    required double displayTotal,
    required bool hasUnavailable,
    required bool isCheckingProducts,
  }) {
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoCodeController,
                      focusNode: _promoFocusNode,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      // "Done" only closes the keyboard. Validation should
                      // happen only when the user explicitly taps Apply.
                      onSubmitted: (_) => _promoFocusNode.unfocus(),
                      decoration: InputDecoration(
                        hintText: 'Enter promo code',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isApplyingPromo,
                      builder: (context, isApplying, _) {
                        return ElevatedButton(
                          onPressed: isApplying
                              ? null
                              : () => _applyPromoFromFooter(
                                    totalAmount: totalAmount,
                                    cartDocs: cartDocs,
                                    hasUnavailable: hasUnavailable,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF4F1F7),
                            foregroundColor: const Color(0xFF6B4FA1),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: isApplying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Apply'),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_isPromoApplied && _discountAmount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'You saved $currencySymbol ${_formatAmount(_discountAmount)} with "$_appliedPromoCode".',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Total: $currencySymbol ${_formatAmount(displayTotal)}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE53935),
                ),
              ),
              if (isCheckingProducts) ...[
                const SizedBox(height: 6),
                const Text(
                  'Checking product availability…',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (hasUnavailable) ...[
                const SizedBox(height: 6),
                const Text(
                  'Remove unavailable items before continuing to checkout.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isCheckingProducts
                      ? null
                      : hasUnavailable
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Some items are unavailable. Please remove them before checkout.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      : () {
                          FocusScope.of(context).unfocus();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutPage(
                                tAmount: displayTotal,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (isCheckingProducts || hasUnavailable)
                            ? Colors.grey
                            : _orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isCheckingProducts
                        ? 'Checking availability…'
                        : hasUnavailable
                            ? 'Resolve unavailable items'
                            : 'Checkout (${cartDocs.length})',
                    style: const TextStyle(fontSize: 16.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _toggleLikeStatus({
    required String productId,
    required bool isLiked,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isLiked ? 'Remove from Wishlist' : 'Add to Wishlist'),
        content: Text(
          isLiked
              ? 'Remove this product from your wishlist?'
              : 'Add this product to your wishlist?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await _firestore.collection('products').doc(productId).update({
        'likes': isLiked
            ? FieldValue.arrayRemove([currentUser.uid])
            : FieldValue.arrayUnion([currentUser.uid]),
      });

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLiked
                ? 'Product removed from your wishlist.'
                : 'Product added to your wishlist.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update wishlist: $error'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<void> _confirmDeleteCartItem(String cartItemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Are you sure you want to remove this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteCartItem(cartItemId);
    }
  }

  Future<void> _decreaseQuantity({
    required String productId,
    required String cartItemId,
    required int quantity,
  }) async {
    final minimum = await _getProductMinQuantity(productId);
    if (!mounted) return;

    if (quantity <= minimum || quantity <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Minimum quantity for this product is $minimum.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _updateQuantity(cartItemId, quantity - 1);
  }

  Future<int> _getProductMinQuantity(String productId) async {
    try {
      final document =
          await _firestore.collection('products').doc(productId).get();
      final value = document.data()?['productminquantity'];
      if (value is num && value.toInt() > 0) return value.toInt();
    } catch (_) {
      // Fall back to one when the product minimum cannot be read.
    }
    return 1;
  }

  Future<void> _updateQuantity(String cartItemId, int newQuantity) async {
    try {
      final reference = _firestore.collection('cartitems').doc(cartItemId);
      final snapshot = await reference.get();
      final data = snapshot.data();
      if (data == null) return;

      final currentQuantityValue = data['quantity'];
      final currentQuantity = currentQuantityValue is num
          ? math.max(1, currentQuantityValue.toInt())
          : 1;
      final totalPriceValue = data['totalPrice'];
      final currentTotal =
          totalPriceValue is num ? totalPriceValue.toDouble() : 0.0;
      final unitPrice = currentTotal / currentQuantity;

      await reference.update({
        'quantity': newQuantity,
        'totalPrice': unitPrice * newQuantity,
      });

      await _revalidatePromoAfterCartChange();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update quantity: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCartItem(String cartItemId) async {
    try {
      await _firestore.collection('cartitems').doc(cartItemId).delete();
      await _revalidatePromoAfterCartChange();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to remove the item: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _applyPromoFromFooter({
    required double totalAmount,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cartDocs,
    required bool hasUnavailable,
  }) async {
    if (_isApplyingPromo.value) return;

    if (hasUnavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please remove unavailable items before applying a promo code.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final code = _promoCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a promo code first.')),
      );
      _promoFocusNode.requestFocus();
      return;
    }

    _isApplyingPromo.value = true;
    try {
      final applied = await _validatePromoCode(
        code: code,
        totalAmount: totalAmount,
        cartDocs: cartDocs,
      );

      // Keep the field usable after an invalid code so the user can correct
      // it immediately. Close the keyboard only after a successful apply.
      if (applied) {
        _promoFocusNode.unfocus();
      } else if (mounted) {
        _promoFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        _isApplyingPromo.value = false;
      }
    }
  }

  Future<bool> _validatePromoCode({
    required String code,
    required double totalAmount,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cartDocs,
  }) async {
    try {
      final promoSnapshot = await _firestore
          .collection('promo_codes')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (promoSnapshot.docs.isEmpty) {
        _showPromoMessage('Invalid or inactive promo code.', isError: true);
        return false;
      }

      final promoDocument = promoSnapshot.docs.first;
      final data = promoDocument.data();
      final expiryTimestamp = data['expiryDate'];
      final expiryDate = expiryTimestamp is Timestamp
          ? expiryTimestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final minOrderValue =
          data['minOrderValue'] is num ? (data['minOrderValue'] as num).toDouble() : 0.0;
      final discountType = (data['discountType'] ?? '').toString();
      final discountValue =
          data['value'] is num ? (data['value'] as num).toDouble() : 0.0;
      final usagePerUser =
          data['usagePerUser'] is num ? (data['usagePerUser'] as num).toInt() : 1;
      final usersUsed = data['usersUsed'] is Map
          ? Map<String, dynamic>.from(data['usersUsed'] as Map)
          : <String, dynamic>{};
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final currentUsageValue = uid == null ? 0 : usersUsed[uid];
      final currentUsage =
          currentUsageValue is num ? currentUsageValue.toInt() : 0;

      final alreadyUsedInCart = cartDocs.any(
        (document) => document.data()['promoCodeUsed'] == code,
      );

      if (alreadyUsedInCart) {
        _showPromoMessage(
          'This promo code is already applied to your cart.',
          isError: true,
        );
        return false;
      }

      if (DateTime.now().isAfter(expiryDate)) {
        _showPromoMessage('Promo code has expired.', isError: true);
        return false;
      }

      if (totalAmount < minOrderValue) {
        _showPromoMessage(
          'Minimum order value is $currencySymbol ${_formatAmount(minOrderValue)}.',
          isError: true,
        );
        return false;
      }

      if (currentUsage >= usagePerUser) {
        _showPromoMessage('Promo code usage limit reached.', isError: true);
        return false;
      }

      final calculatedDiscount = discountType == 'percentage'
          ? totalAmount * (discountValue / 100)
          : discountValue;
      final safeDiscount = math.min(totalAmount, calculatedDiscount);

      final batch = _firestore.batch();
      for (final cartDocument in cartDocs) {
        batch.update(cartDocument.reference, {'promoCodeUsed': code});
      }
      await batch.commit();

      if (uid != null) {
        await promoDocument.reference.update({
          'usersUsed.$uid': FieldValue.increment(1),
          'usageLimit': FieldValue.increment(-1),
        });
      }

      await _firestore.collection('discounts').add({
        'userId': uid,
        'date': Timestamp.now(),
        'discountAmount': safeDiscount,
        'promoCode': code,
      });

      if (!mounted) return true;
      setState(() {
        _discountAmount = safeDiscount;
        _appliedPromoCode = code;
        _appliedPromoReference = promoDocument.reference;
        _isPromoApplied = true;
      });

      _showPromoMessage('Promo code applied successfully.');
      return true;
    } catch (error) {
      _showPromoMessage(
        'An error occurred while validating the promo code.',
        isError: true,
      );
      debugPrint('Promo validation error: $error');
      return false;
    }
  }

  Future<void> _revalidatePromoAfterCartChange() async {
    if (!_isPromoApplied || _appliedPromoCode == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cartSnapshot = await _firestore
        .collection('cartitems')
        .where('userId', isEqualTo: uid)
        .get();

    final newTotal = cartSnapshot.docs.fold<double>(0.0, (sum, document) {
      final value = document.data()['totalPrice'];
      return sum + (value is num ? value.toDouble() : 0.0);
    });

    DocumentSnapshot<Map<String, dynamic>> promoDocument;
    if (_appliedPromoReference != null) {
      promoDocument = await _appliedPromoReference!.get();
    } else {
      final query = await _firestore
          .collection('promo_codes')
          .where('code', isEqualTo: _appliedPromoCode)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return;
      promoDocument = query.docs.first;
    }

    final promoData = promoDocument.data();
    if (promoData == null) return;

    final minOrderValue = promoData['minOrderValue'] is num
        ? (promoData['minOrderValue'] as num).toDouble()
        : 0.0;
    final discountType = (promoData['discountType'] ?? '').toString();
    final discountValue = promoData['value'] is num
        ? (promoData['value'] as num).toDouble()
        : 0.0;

    if (newTotal < minOrderValue) {
      final batch = _firestore.batch();
      for (final document in cartSnapshot.docs) {
        batch.update(
          document.reference,
          {'promoCodeUsed': FieldValue.delete()},
        );
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _isPromoApplied = false;
        _appliedPromoCode = null;
        _appliedPromoReference = null;
        _discountAmount = 0.0;
        _promoCodeController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Promo code removed because the cart total is below '
            '$currencySymbol ${_formatAmount(minOrderValue)}.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final adjustedDiscount = discountType == 'percentage'
        ? newTotal * (discountValue / 100)
        : discountValue;

    if (!mounted) return;
    setState(() {
      _discountAmount = math.min(newTotal, adjustedDiscount);
    });
  }

  void _showPromoMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}

class _CartProductState {
  final bool exists;
  final bool isPublished;
  final Set<String> likes;
  final String? name;
  final String? description;
  final String? imageUrl;

  const _CartProductState({
    required this.exists,
    required this.isPublished,
    required this.likes,
    this.name,
    this.description,
    this.imageUrl,
  });

  const _CartProductState.provisional()
      : exists = true,
        isPublished = true,
        likes = const <String>{},
        name = null,
        description = null,
        imageUrl = null;

  const _CartProductState.missing()
      : exists = false,
        isPublished = false,
        likes = const <String>{},
        name = null,
        description = null,
        imageUrl = null;

  bool get isAvailable => exists && isPublished;

  factory _CartProductState.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawLikes = data['likes'];

    return _CartProductState(
      exists: true,
      isPublished: data['isPublish'] is bool ? data['isPublish'] as bool : true,
      likes: rawLikes is Iterable
          ? rawLikes.map((value) => value.toString()).toSet()
          : const <String>{},
      name: (data['name'] ?? data['productName'])?.toString(),
      description:
          (data['description'] ?? data['productDescription'])?.toString(),
      imageUrl: (data['image'] ?? data['productImage'])?.toString(),
    );
  }
}

class _CartItemLoadingCard extends StatelessWidget {
  const _CartItemLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, color: Colors.grey.shade200),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: 0.72,
                  child: Container(height: 12, color: Colors.grey.shade200),
                ),
                const Spacer(),
                FractionallySizedBox(
                  widthFactor: 0.42,
                  child: Container(height: 16, color: Colors.grey.shade200),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  final IconData icon;

  const _ProductImageFallback({
    this.icon = Icons.shopping_bag_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      color: const Color(0xFFF2F2F4),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.grey, size: 30),
    );
  }
}

class _CartAttributeChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _CartAttributeChip({
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(label, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
}
