import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../homescreen.dart';
import 'payment_options.dart';
import 'shipping_address/add_shipping_address.dart';
import 'shipping_address/edit_shippingaddress.dart';
import 'service/regional_shipping_fee_service.dart';


class CheckoutPage extends StatefulWidget {
  final double tAmount; // Field to hold the passed value

  const CheckoutPage({super.key, required this.tAmount});

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _shippingAddressController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _orderNotesController =
      TextEditingController(); // Controller for order notes
  bool _isShippingAddressExpanded = false;
  bool _isOrderNotesExpanded =
      false; // To control the visibility of the order notes section
  bool _hasShippingAddress = false;
  Map<String, dynamic>? _shippingAddress;

  double totalAmount = 0.0;
  double shippingFee = 0.0;

  String? currencySymbol;
  double? exchangeRate;

  String uidlocvar = "";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _calculateInitialTotalAmount();
    _loadCurrencyData();
    _refreshShippingAddressAndFee();
  }


  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _shippingAddressController.dispose();
    _phoneController.dispose();
    _orderNotesController.dispose();
    super.dispose();
  }



  bool _isLoading = false;
  bool _isShippingDataLoading = true;
  String? _shippingFeeError;

//added 2-1-2024
//updated 27 04 2025


  Future<void> _navigateToPaymentOptions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to proceed.')),
      );
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final isReady = await _refreshShippingAddressAndFee(
        showErrors: true,
      );

      if (!isReady || !mounted) return;

      final currentAddress = _shippingAddress;
      if (currentAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add and select a default shipping address.'),
          ),
        );
        return;
      }

      final shippingAddress = [
        currentAddress['address'] ?? '',
        currentAddress['city'] ?? '',
        currentAddress['region'] ?? '',
        currentAddress['zipcode'] ?? '',
        currentAddress['country'] ?? '',
      ]
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .join(', ');

      final userRegion =
          (currentAddress['region'] ?? '').toString().trim();
      final shippingCountry =
          (currentAddress['country'] ?? '').toString().trim();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentOptionsPage(
            region: userRegion,
            shippingCountry: shippingCountry,
            totalAmount: widget.tAmount,
            shippingFee: shippingFee,
            orderNotes: _orderNotesController.text.trim(),
            shippingAddress: shippingAddress,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

//added 08-12-2024
  //amended 28 -11- 2025
 bool _currencyLoaded = false;

Future<void> _loadCurrencyData() async {
  final prefs = await SharedPreferences.getInstance();

  final base = prefs.getString('baseCurrency') ?? 'GHS';
  final selected = prefs.getString('selectedCurrency') ?? base;
  final rate = prefs.getDouble('conversionRate') ?? 1.0;

  if (!mounted) return;
  setState(() {
    currencySymbol = selected;  // 👈 show user’s chosen currency code
    exchangeRate = rate;        // 👈 base → selected
    _currencyLoaded = true;
  });
}

  double _convertPrice(dynamic price) {
    if (price == null) {
      throw ArgumentError('Price cannot be null');
    }

    // Ensure the price is treated as a double
    final double parsedPrice =
        (price is int) ? price.toDouble() : (price as double);

    if (exchangeRate != null) {
      return parsedPrice * exchangeRate!;
    }

    return parsedPrice; // Default price without conversion
  }

  Future<void> _fetchUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _fullNameController.text = userData['fullname'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _shippingAddressController.text = userData['shippingaddress'] ?? '';
        _phoneController.text = userData['phone'] ?? '';

        if (!mounted) return;
        setState(() {
          _hasShippingAddress = userData['shippingaddress'] != null &&
              userData['shippingaddress'] != '';
        });
      }
    }
  }

 
 
  Future<bool> _refreshShippingAddressAndFee({
    bool showErrors = false,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      if (!mounted) return false;
      setState(() {
        _shippingAddress = null;
        shippingFee = 0;
        _shippingFeeError = 'You need to be signed in to continue.';
        _isShippingDataLoading = false;
      });
      return false;
    }

    if (mounted) {
      setState(() {
        _isShippingDataLoading = true;
        _shippingFeeError = null;
      });
    }

    try {
      final addressSnapshot = await FirebaseFirestore.instance
          .collection('shippingaddress')
          .where('uid', isEqualTo: userId)
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (addressSnapshot.docs.isEmpty) {
        if (!mounted) return false;
        setState(() {
          _shippingAddress = null;
          shippingFee = 0;
          _shippingFeeError = null;
          _isShippingDataLoading = false;
        });
        return false;
      }

      final addressDocument = addressSnapshot.docs.first;
      final addressData = addressDocument.data();
      final region = (addressData['region'] ?? '').toString().trim();

      if (region.isEmpty) {
        throw StateError(
          'The default shipping address does not have a valid region.',
        );
      }

      final regionalFee =
          await RegionalShippingFeeService.fetchFeeForRegion(region);

      if (!mounted) return false;
      setState(() {
        _shippingAddress = {
          'fullname': addressData['fullname'] ?? '',
          'id': (addressData['id'] ?? addressDocument.id).toString(),
          'address': addressData['address'] ?? '',
          'city': addressData['city'] ?? '',
          'region': region,
          'regionKey':
              RegionalShippingFeeService.normalizeRegionKey(region),
          'zipcode': addressData['zipcode'] ?? '',
          'country': addressData['country'] ?? '',
          'phone': addressData['phone'] ?? '',
        };
        shippingFee = regionalFee;
        _shippingFeeError = null;
        _isShippingDataLoading = false;
      });
      return true;
    } catch (error) {
      final message = _friendlyError(error);

      if (!mounted) return false;
      setState(() {
        shippingFee = 0;
        _shippingFeeError = message;
        _isShippingDataLoading = false;
      });

      if (showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  Future<void> _calculateInitialTotalAmount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('cartitems')
        .where('userId', isEqualTo: userId)
        .get();

    double newTotalAmount = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      newTotalAmount += (data['totalPrice'] ?? 0.0).toDouble();
    }

    if (!mounted) return;
    setState(() {
      totalAmount = newTotalAmount;
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Shipping address and its regional fee are refreshed together.

  Widget _buildShippingAddressSection() {
    if (_isShippingDataLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_shippingAddress == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text('No default shipping address found.'),
          TextButton(
            onPressed: () async {
              final wasAdded = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddShippingAddressPage(),
                ),
              );

              if (wasAdded == true) {
                await _refreshShippingAddressAndFee(showErrors: true);
              }
            },
            child: const Text('Add Address'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_shippingAddress!['fullname'] ?? 'No Name')
                            .toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        (_shippingAddress!['address'] ?? 'No Address')
                            .toString(),
                      ),
                      Text(
                        '${_shippingAddress!['city'] ?? 'No City'}, '
                        '${_shippingAddress!['region'] ?? 'No Region'} '
                        '${_shippingAddress!['zipcode'] ?? ''}',
                      ),
                      Text(
                        (_shippingAddress!['country'] ?? 'No Country')
                            .toString(),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final addressId =
                        (_shippingAddress!['id'] ?? '').toString();

                    if (addressId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Address ID is missing or invalid.',
                          ),
                        ),
                      );
                      return;
                    }

                    final wasUpdated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditShippingAddressPage(
                          addressId: addressId,
                        ),
                      ),
                    );

                    if (wasUpdated == true) {
                      await _refreshShippingAddressAndFee(
                        showErrors: true,
                      );
                    }
                  },
                  child: const Text(
                    'Change',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_shippingFeeError != null) ...[
          const SizedBox(height: 8),
          Text(
            _shippingFeeError!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(
        child: Text('You need to be signed in to view your cart.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Confirmation',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          /*  IconButton(
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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shipping Address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  
                  _buildShippingAddressSection(),
                  const SizedBox(height: 20),
                  _buildOrderNotesSection(), // Collapsible section for order notes
                  const SizedBox(height: 20),
                  const Text(
                    'Cart Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('cartitems')
                        .where('userId', isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
          
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('Your cart is empty.'));
                      }
          
                      final cartItems = snapshot.data!.docs;
          
                      return Column(
                        children: cartItems.map((cartItem) {
                          final data = cartItem.data() as Map<String, dynamic>;
                          final int quantity = data['quantity'] ?? 1;
          
                          Color? color;
                          if (data['selectedColor'] != null &&
                              data['selectedColor'].isNotEmpty) {
                            color = Color(int.parse(
                                    data['selectedColor'].substring(1),
                                    radix: 16))
                                .withOpacity(1.0);
                          }
          


double imageSize = MediaQuery.of(context).size.width * 0.15; // ~15%

                          return SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [


CachedNetworkImage(
  imageUrl: data['productImage'],
  width: imageSize,
  height: imageSize,
  fit: BoxFit.cover,
  placeholder: (context, url) => SizedBox(
    width: imageSize,
    height: imageSize,
    child: const Center(
      child: Icon(Icons.shopping_cart_outlined, size: 28, color: Colors.grey),
    ),
  ),
  errorWidget: (context, url, error) => Icon(Icons.broken_image, size: imageSize * 0.6),
),

                                     
                                     
                                     /*   Image.network(
                                          data['productImage'],
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),*/


                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['productName'],
                                                style:
                                                    const TextStyle(fontSize: 14),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                data['productDescription'] ?? '',
                                                style:
                                                    const TextStyle(fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (color != null)
                                                Row(
                                                  children: [
                                                    const Text('Color: ',
                                                        style: TextStyle(
                                                            fontSize: 12)),
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
                                              if (data['selectedSize'] != null &&
                                                  data['selectedSize'].isNotEmpty)
                                                Text(
                                                  'Size: ${data['selectedSize']}',
                                                  style:
                                                      const TextStyle(fontSize: 12),
                                                ),
                                            ],
                                          ),
                                        ),
          
                                        /* IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.grey, size: 18),
                                          onPressed: () {
                                            _confirmRemoveFromCart(cartItem.id);
                                          },
                                        ),*/
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          
                                           // '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(productsellingprice.toDouble()))}',
                                          //'$currencySymbol ${_convertPrice(data['totalPrice']).toDouble().toStringAsFixed(2)}',
                                          
                                          '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(data['totalPrice']))}',
          
                                          
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Row(
                                          children: [],
                                        ),
          
                                        /*Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove),
                                              onPressed: () async {
                                                final minQuantity =
                                                    await _getProductMinQuantity(
                                                        data['productId']);
                                                if (quantity > minQuantity) {
                                                  _updateQuantity(
                                                      cartItem.id, quantity - 1);
                                                } else {
                                                  _showSnackbar(
                                                      'Cannot reduce below minimum quantity of $minQuantity');
                                                }
                                              },
                                            ),
                                            Text(quantity.toString()),
                                            IconButton(
                                              icon: const Icon(Icons.add),
                                              onPressed: () {
                                                _updateQuantity(
                                                    cartItem.id, quantity + 1);
                                              },
                                            ),
                                          ],
                                        ),*/
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
          
                  const SizedBox(height: 10),
                  const Text(
                    'Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    // '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(data['totalPrice']))}',
                    'Subtotal: $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(totalAmount))}',
                   // 'Subtotal: $currencySymbol ${_convertPrice(totalAmount).toStringAsFixed(2)}',
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                   // 'Coupon Discount : - ($currencySymbol ${_convertPrice(totalAmount - widget.tAmount).toStringAsFixed(2)})',
                       'Coupon Discount : - ($currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(totalAmount - widget.tAmount))})',
                   
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  Text(
                    _isShippingDataLoading
                        ? 'Shipping Fee: Loading...'
                        : 'Shipping Fee (${_shippingAddress?['region'] ?? 'Region'}): '
                            '$currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(shippingFee))}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_shippingFeeError != null)
                    Text(
                      _shippingFeeError!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                  Text(
          
                    'Total : $currencySymbol ${NumberFormat("#,##0.00").format(_convertPrice(totalAmount - (totalAmount - widget.tAmount) + shippingFee))}',
                    //'Total : $currencySymbol ${_convertPrice(totalAmount - (totalAmount - widget.tAmount) + shippingFee).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
            // The loading overlay
    if (_isLoading) ...[
      Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.5), // semi-transparent black
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white, // or any color you want
            ),
          ),
        ),
      ),
    ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: (_isLoading ||
                    _isShippingDataLoading ||
                    _shippingFeeError != null ||
                    _shippingAddress == null)
                ? null
                : _navigateToPaymentOptions,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: const Color(0xFFFFA500),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Proceed to Payment',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        
         
        ),
      ),
    );
  }


  Widget _buildOrderNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Additional Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(
                _isOrderNotesExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _isOrderNotesExpanded = !_isOrderNotesExpanded;
                });
              },
            ),
          ],
        ),
        if (_isOrderNotesExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextField(
                controller: _orderNotesController,
                maxLines: 4, // Make it multiline
                decoration: const InputDecoration(
                  labelText: 'Enter any additional notes for your order',
                  border: OutlineInputBorder(),
                )),
          ),
      ],
    );
  }

  Future<void> _addShippingAddress() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fullname': _fullNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'shippingaddress': _shippingAddressController.text,
      });
      setState(() {
        _hasShippingAddress = true;
        _isShippingAddressExpanded = false;
      });
    }
  }

  Widget _buildTextField(TextEditingController controller, String labelText) {
    return TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ));
  }

  void _confirmRemoveFromCart(String cartItemId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Item'),
          content: const Text(
              'Are you sure you want to remove this item from the cart?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Remove'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _removeFromCart(cartItemId); // Perform the action
              },
            ),
          ],
        );
      },
    );
  }

  void _removeFromCart(String cartItemId) {
    FirebaseFirestore.instance.collection('cartitems').doc(cartItemId).delete();
    _calculateInitialTotalAmount();
  }

  Future<void> _updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity < 1) {
      _removeFromCart(cartItemId);
      return;
    }

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

      setState(() {
        totalAmount = totalAmount - data['totalPrice'] + newTotalPrice;
      });
    } catch (e) {
      print('Error updating quantity: $e');
    }
  }

  Future<int> _getProductMinQuantity(String productId) async {
    try {
      final productRef =
          FirebaseFirestore.instance.collection('products').doc(productId);
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        final data = productDoc.data() as Map<String, dynamic>;
        return data['productminquantity'] ?? 1;
      }
    } catch (e) {
      print('Error fetching product minimum quantity: $e');
    }
    return 1;
  }
}
