import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pay_with_paystack/pay_with_paystack.dart';
import 'package:paystack_for_flutter/paystack_for_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'COD/success_screen.dart';

class PaymentOptionsPage extends StatefulWidget {
  final String region;
  final String shippingCountry;
  final double totalAmount;
  final double shippingFee;
  final String orderNotes;
  final String shippingAddress;

  const PaymentOptionsPage({
    super.key,
    required this.region,
    required this.shippingCountry,
    required this.totalAmount,
    required this.shippingFee,
    required this.orderNotes,
    required this.shippingAddress,
  });

  @override
  State<PaymentOptionsPage> createState() => _PaymentOptionsPageState();
}

class _PaymentOptionsPageState extends State<PaymentOptionsPage> {
  String? selectedPaymentMethod;
  bool _isProcessing = false;
  bool _acceptCodTerms = false;
  bool _currencyLoaded = false;

  // Owned by the page so it is not disposed while the dialog's reverse
  // animation is still using the text field.
  final TextEditingController _deliveryPhoneController =
      TextEditingController();

  String? currencySymbol;
  double? exchangeRate;

  late final Future<_PaymentConfiguration> _configurationFuture;

  double get _baseTotal => widget.totalAmount + widget.shippingFee;

  double _displayAmount(double baseAmount) {
    return baseAmount * (exchangeRate ?? 1.0);
  }

  @override
  void initState() {
    super.initState();
    _configurationFuture = _loadPaymentConfiguration();
    _loadCurrencyData();
  }

  @override
  void dispose() {
    _deliveryPhoneController.dispose();
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

  Future<_PaymentConfiguration> _loadPaymentConfiguration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You need to be signed in to continue.');
    }

    final allowedRegionsFuture = FirebaseFirestore.instance
        .collection('cod')
        .doc('allowedRegions')
        .get();
    final protectedSettingsFuture = FirebaseFirestore.instance
        .collection('cod')
        .doc('protectedSettings')
        .get();
    final userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final defaultAddressFuture = FirebaseFirestore.instance
        .collection('shippingaddress')
        .where('uid', isEqualTo: user.uid)
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    final allowedRegionsDoc = await allowedRegionsFuture;
    final protectedSettingsDoc = await protectedSettingsFuture;
    final userDoc = await userFuture;
    final defaultAddress = await defaultAddressFuture;

    final allowedData = allowedRegionsDoc.data() ?? <String, dynamic>{};
    final settings = protectedSettingsDoc.data() ?? <String, dynamic>{};
    final userData = userDoc.data() ?? <String, dynamic>{};
    final addressData = defaultAddress.docs.isEmpty
        ? <String, dynamic>{}
        : defaultAddress.docs.first.data();

    final regions = (allowedData['regions'] as List<dynamic>? ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final configuredRegionKeys =
        (allowedData['regionKeys'] as List<dynamic>? ?? const [])
            .map((value) => _normalizeRegionKey(value.toString()))
            .where((value) => value.isNotEmpty);

    final allowedRegionKeys = <String>{
      ...regions.map(_normalizeRegionKey),
      ...configuredRegionKeys,
    };

    final failureCount = _readInt(
      userData['codFailureCount'] ??
          userData['deliveryFailureCount'] ??
          userData['codFailures'],
      fallback: 0,
    );

    final policy = _ProtectedCodPolicy(
      enabled: _readBool(settings['enabled'], fallback: true),
      warningAfter: _readInt(settings['warningAfter'], fallback: 1),
      escalatedAfter: _readInt(settings['escalatedAfter'], fallback: 2),
      suspendAfter: _readInt(settings['suspendAfter'], fallback: 3),
      escalatedDepositPercent: _readDouble(
        settings['escalatedDepositPercent'],
        fallback: 50,
      ).clamp(1, 100).toDouble(),
      failureCount: failureCount,
      manuallySuspended: _readBool(
        userData['codSuspended'],
        fallback: false,
      ),
    );

    final savedAddressRegion =
        (addressData['region'] ?? '').toString().trim();
    final passedRegion = widget.region.trim();
    final savedAddressRegionKey =
        (addressData['regionKey'] ?? '').toString().trim();

    // The visible region name is the source of truth. A previously stored
    // regionKey can become stale when an address is corrected in Firestore or
    // migrated from an older region list. Only use regionKey as a fallback
    // when no region name is available.
    final currentRegionKeys = <String>{
      if (savedAddressRegion.isNotEmpty)
        _normalizeRegionKey(savedAddressRegion),
      if (passedRegion.isNotEmpty) _normalizeRegionKey(passedRegion),
    }..removeWhere((key) => key.isEmpty);

    if (currentRegionKeys.isEmpty && savedAddressRegionKey.isNotEmpty) {
      currentRegionKeys.add(_normalizeRegionKey(savedAddressRegionKey));
    }

    final currentRegionLabel = savedAddressRegion.isNotEmpty
        ? savedAddressRegion
        : (passedRegion.isNotEmpty ? passedRegion : 'your region');

    debugPrint(
      '[PaymentOptions] currentRegionLabel=$currentRegionLabel '
      'currentRegionKeys=$currentRegionKeys '
      'allowedRegionKeys=$allowedRegionKeys '
      'protectedCodEnabled=${policy.enabled} '
      'codEligible=${policy.isEligible}',
    );

    final addressPhone = (addressData['phone'] ?? '').toString().trim();
    final userPhone = (userData['phone'] ?? '').toString().trim();
    final codDeliveryPhone =
        (userData['codDeliveryPhone'] ?? '').toString().trim();
    final authPhone = user.phoneNumber?.trim() ?? '';

    final initialPhone = addressPhone.isNotEmpty
        ? addressPhone
        : (codDeliveryPhone.isNotEmpty
            ? codDeliveryPhone
            : (authPhone.isNotEmpty ? authPhone : userPhone));

    return _PaymentConfiguration(
      allowedRegionKeys: allowedRegionKeys,
      currentRegionKeys: currentRegionKeys,
      currentRegionLabel: currentRegionLabel,
      policy: policy,
      initialPhone: initialPhone,
    );
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return fallback;
  }

  static String _normalizeRegionKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'\s+region$'), '');
  }

  void _onPaymentMethodSelected(String method) {
    setState(() {
      selectedPaymentMethod = method;
      if (method != 'Protected COD') {
        _acceptCodTerms = false;
      }
    });
  }

  Future<Map<String, dynamic>> _loadPaystackSettings() async {
    final settingsDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('doc8')
        .get()
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw StateError(
            'Payment settings are taking too long to load. Check your internet '
            'connection and try again.',
          ),
        );
    final data = settingsDoc.data();

    final secretKey = data?['paystack_key']?.toString().trim() ?? '';
    final callbackUrl =
        data?['paystack_callback_url']?.toString().trim() ?? '';

    if (secretKey.isEmpty || callbackUrl.isEmpty) {
      throw StateError('Online payment is not configured.');
    }

    return {
      'secretKey': secretKey,
      'callbackUrl': callbackUrl,
    };
  }

  Future<void> _handleProceed(
    String effectiveSelection,
    _PaymentConfiguration configuration,
  ) async {
    if (_isProcessing) return;

    if (effectiveSelection.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method.')),
      );
      return;
    }

    if (effectiveSelection == 'Protected COD' && !_acceptCodTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Protected Cash on Delivery terms to continue.',
          ),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (effectiveSelection == 'Paystack') {
        await _processFullPaystackPayment();
      } else {
        await _processProtectedCodPayment(configuration);
      }
    } catch (error, stackTrace) {
      debugPrint('Payment error: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _resolvePaymentReference(dynamic callbackReference, String fallback) {
    final reference = callbackReference?.toString().trim() ?? '';
    if (reference.isEmpty || reference.toLowerCase() == 'null') {
      return fallback;
    }
    return reference;
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '');
    return message.startsWith('Exception: ')
        ? message.replaceFirst('Exception: ', '')
        : message;
  }

  Future<void> _processFullPaystackPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('You need to be signed in to proceed.');

    final settings = await _loadPaystackSettings();
    final uniqueTransRef = PayWithPayStack().generateUuidV4();
    final amountInPesewas = (_baseTotal * 100).roundToDouble();

    await PaystackFlutter().pay(
      context: context,
      secretKey: settings['secretKey'] as String,
      amount: amountInPesewas,
      email: user.email ?? '',
      reference: uniqueTransRef,
      callbackUrl: settings['callbackUrl'] as String,
      showProgressBar: true,
      paymentOptions: const [
        PaymentOption.card,
        PaymentOption.bankTransfer,
        PaymentOption.mobileMoney,
      ],
      currency: Currency.GHS,
      metaData: {
        'user_id': user.uid,
        'payment_type': 'full_payment',
        'order_notes': widget.orderNotes,
        'shipping_fee': widget.shippingFee,
        'total': amountInPesewas,
        'reference': uniqueTransRef,
      },
      onSuccess: (callback) async {
        final paymentReference = _resolvePaymentReference(
          callback.reference,
          uniqueTransRef,
        );
        try {
          final orderId = await _createOrderFromCart(
            paymentMethod: 'Paystack',
            status: 'Paid',
            paid: true,
            paymentReference: paymentReference,
            extraFields: {
              'paymentStatus': 'paid',
              'paymentVerificationStatus':
                  'client_callback_pending_server_verification',
              'amountPaid': _baseTotal,
              'amountDueOnDelivery': 0.0,
            },
          );

          if (!mounted || orderId == null) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => CODOrderScreen(orderId: orderId),
            ),
            (route) => false,
          );
        } catch (error) {
          if (!mounted) return;
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment succeeded, but the order could not be completed. '
                'Please contact support with reference $paymentReference.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onCancelled: (_) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was cancelled. You can try again.'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _processProtectedCodPayment(
    _PaymentConfiguration configuration,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('You need to be signed in to proceed.');

    final customerEmail = user.email?.trim() ?? '';
    if (customerEmail.isEmpty) {
      throw StateError(
        'Your account does not have an email address. Add an email address '
        'before making the commitment payment.',
      );
    }

    if (!configuration.policy.isEligible) {
      throw StateError(
        'Cash on Delivery is currently unavailable for this account. '
        'Please use Paystack.',
      );
    }

    // Load and validate Paystack before showing the phone dialog. This avoids
    // leaving the customer behind a closed dialog while Firestore is loading.
    debugPrint('[ProtectedCOD] Loading Paystack settings');
    final settings = await _loadPaystackSettings();

    final commitmentAmount = configuration.policy.commitmentAmount(
      orderTotal: _baseTotal,
      shippingFee: widget.shippingFee,
    );
    if (commitmentAmount <= 0) {
      throw StateError(
        'The Protected COD commitment amount is zero. Configure a valid '
        'shipping fee before accepting COD orders.',
      );
    }

    final deliveryPhone = await _confirmDeliveryPhone(
      configuration.initialPhone,
    );
    if (deliveryPhone == null) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // Let the dialog finish its reverse animation before another route is
    // pushed. Pushing Paystack while the dialog is still closing can lock the
    // modal barrier on iOS.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final amountDue =
        math.max(0.0, _baseTotal - commitmentAmount).toDouble();
    final uniqueTransRef = PayWithPayStack().generateUuidV4();

    debugPrint(
      '[ProtectedCOD] Opening Paystack checkout. '
      'reference=$uniqueTransRef amount=$commitmentAmount',
    );

    await PaystackFlutter().pay(
      context: context,
      secretKey: settings['secretKey'] as String,
      amount: (commitmentAmount * 100).roundToDouble(),
      email: customerEmail,
      reference: uniqueTransRef,
      callbackUrl: settings['callbackUrl'] as String,
      showProgressBar: true,
      paymentOptions: const [
        PaymentOption.card,
        PaymentOption.bankTransfer,
        PaymentOption.mobileMoney,
      ],
      currency: Currency.GHS,
      metaData: {
        'user_id': user.uid,
        'payment_type': 'protected_cod_commitment',
        'commitment_amount': commitmentAmount,
        'amount_due_on_delivery': amountDue,
        'delivery_phone': deliveryPhone,
        'failure_count': configuration.policy.failureCount,
        'reference': uniqueTransRef,
      },
      onSuccess: (callback) async {
        final paymentReference = _resolvePaymentReference(
          callback.reference,
          uniqueTransRef,
        );
        try {
          // Saving the phone is useful but must not block checkout before the
          // customer reaches Paystack.
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'phone': deliveryPhone,
                  'codDeliveryPhone': deliveryPhone,
                  'codPhoneConfirmedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true))
                .timeout(const Duration(seconds: 10));
          } catch (phoneSaveError) {
            debugPrint(
              '[ProtectedCOD] Could not save confirmed phone: $phoneSaveError',
            );
          }

          final now = Timestamp.now();
          final orderId = await _createOrderFromCart(
            paymentMethod: 'Protected COD',
            status: 'Confirmed – Delivery Fee Paid',
            paid: false,
            paymentReference: paymentReference,
            extraFields: {
              'paymentStatus': 'commitment_paid',
              'paymentVerificationStatus':
                  'client_callback_pending_server_verification',
              'codProtectionEnabled': true,
              'codProtectionVersion': 1,
              'codCommitmentType': configuration.policy.isEscalated
                  ? 'risk_adjusted_deposit'
                  : 'delivery_fee',
              'codCommitmentAmount': commitmentAmount,
              'codCommitmentPaid': true,
              'codCommitmentPaidAt': FieldValue.serverTimestamp(),
              'amountPaid': commitmentAmount,
              'amountDueOnDelivery': amountDue,
              'deliveryPhone': deliveryPhone,
              'deliveryPhoneVerified': false,
              'deliveryPhoneVerificationMethod': 'not_required',
              'codPhoneConfirmed': true,
              'codPhoneConfirmedAt': FieldValue.serverTimestamp(),
              'codFailureCountAtOrder': configuration.policy.failureCount,
              'codRiskTier': configuration.policy.riskTier,
              'statusHistory': [
                {
                  'status': 'Awaiting Delivery Fee',
                  'at': now,
                },
                {
                  'status': 'Confirmed – Delivery Fee Paid',
                  'at': now,
                },
              ],
            },
          );

          if (!mounted || orderId == null) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => CODOrderScreen(orderId: orderId),
            ),
            (route) => false,
          );
        } catch (error, stackTrace) {
          debugPrint('[ProtectedCOD] Order completion error: $error');
          debugPrint('$stackTrace');
          if (!mounted) return;
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Your commitment payment succeeded, but the order could not '
                'be completed. Please contact support with reference '
                '$paymentReference.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onCancelled: (_) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Commitment payment was cancelled. Your cart has not been cleared.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<String?> _confirmDeliveryPhone(String initialPhone) async {
    _deliveryPhoneController.text = initialPhone;
    _deliveryPhoneController.selection = TextSelection.collapsed(
      offset: _deliveryPhoneController.text.length,
    );

    String? errorText;
    var isClosing = false;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void confirmPhone() {
              if (isClosing) return;

              final phone = _normalizePhone(_deliveryPhoneController.text);
              if (!_isValidInternationalPhone(phone)) {
                setDialogState(() {
                  errorText =
                      'Enter a valid phone number, for example +233XXXXXXXXX.';
                });
                return;
              }

              FocusScope.of(dialogContext).unfocus();
              setDialogState(() => isClosing = true);
              Navigator.of(dialogContext, rootNavigator: true).pop(phone);
            }

            return AlertDialog(
              title: const Text('Confirm delivery phone'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'We will use this number for delivery calls and order updates.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _deliveryPhoneController,
                      autofocus: true,
                      enabled: !isClosing,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialogState(() => errorText = null);
                        }
                      },
                      onSubmitted: (_) => confirmPhone(),
                      decoration: InputDecoration(
                        labelText: 'Delivery phone number',
                        hintText: '+233XXXXXXXXX',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No OTP will be sent. Please make sure the number is correct.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isClosing
                      ? null
                      : () {
                          FocusScope.of(dialogContext).unfocus();
                          setDialogState(() => isClosing = true);
                          Navigator.of(dialogContext, rootNavigator: true).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isClosing ? null : confirmPhone,
                  child: isClosing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm and Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  String _normalizePhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) return '';
    if (phone.startsWith('00')) phone = '+${phone.substring(2)}';
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('233')) return '+$phone';
    if (phone.startsWith('0')) return '+233${phone.substring(1)}';
    return '+233$phone';
  }

  bool _isValidInternationalPhone(String phone) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone);
  }

  Future<String?> _createOrderFromCart({
    required String paymentMethod,
    required String status,
    required bool paid,
    required String paymentReference,
    Map<String, dynamic> extraFields = const {},
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final userEmail = user?.email;
    if (userId == null || userEmail == null) {
      throw StateError('You need to be signed in to complete your order.');
    }

    final existingOrder = await FirebaseFirestore.instance
        .collection('ordersitems')
        .where('paymentReference', isEqualTo: paymentReference)
        .limit(1)
        .get();
    if (existingOrder.docs.isNotEmpty) {
      return existingOrder.docs.first.id;
    }

    final cartItems = await FirebaseFirestore.instance
        .collection('cartitems')
        .where('userId', isEqualTo: userId)
        .get();
    if (cartItems.docs.isEmpty) {
      throw StateError('Your cart is empty.');
    }

    final items = cartItems.docs.map((doc) => doc.data()).toList();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    var shippingCountry = widget.shippingCountry.trim();
    var shippingRegion = widget.region.trim();

    if ((shippingCountry.isEmpty || shippingRegion.isEmpty) &&
        widget.shippingAddress.trim().isNotEmpty) {
      final parsed = _parseCountryRegionFromAddress(widget.shippingAddress);
      if (shippingRegion.isEmpty) shippingRegion = parsed.$1;
      if (shippingCountry.isEmpty) shippingCountry = parsed.$2;
    }

    final shippingRegionKey = _normalizeRegionKey(shippingRegion);

    final orderRef = await FirebaseFirestore.instance
        .collection('ordersitems')
        .add({
      'userId': userId,
      'email': userEmail,
      'paymentMethod': paymentMethod,
      'items': items,
      'status': status,
      'totalAmount': widget.totalAmount,
      'shippingFee': widget.shippingFee,
      'orderNotes': widget.orderNotes,
      'shippingAddress': widget.shippingAddress,
      'shippingCountry': shippingCountry,
      'shippingRegion': shippingRegion,
      'shippingRegionKey': shippingRegionKey,
      'shippingFeeSource': 'settings/regionalShippingFees',
      'shippingFeeCurrency': 'GHS',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'mobile',
      'paid': paid,
      'paymentReference': paymentReference,
      '_aggDone': false,
      ...extraFields,
    });

    final orderId = orderRef.id;
    await orderRef.update({'orderId': orderId});

    await _applyRealtimeAggregates(
      orderRef: orderRef,
      items: items,
      userId: userId,
    );

    final batch = FirebaseFirestore.instance.batch();
    for (final item in cartItems.docs) {
      batch.delete(item.reference);
    }
    await batch.commit();

    var userName = 'Customer';
    final fullName = userData['fullname']?.toString().trim() ?? '';
    final username = userData['username']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) {
      userName = fullName;
    } else if (username.isNotEmpty) {
      userName = username;
    }

    await sendEmailFromFirestore(
      orderNumber: orderId,
      userName: userName,
    );
    await _createOrderNotification(
      orderId: orderId,
      userId: userId,
      userName: userName,
      paymentMethod: paymentMethod,
    );
    await _sendOrderSms(
      orderId: orderId,
      phone: (userData['phone'] ?? '').toString(),
    );

    return orderId;
  }

  Future<void> _createOrderNotification({
    required String orderId,
    required String userId,
    required String userName,
    required String paymentMethod,
  }) async {
    final settingsDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('doc5')
        .get();

    var title = 'Order Confirmed';
    var message = paymentMethod == 'Protected COD'
        ? 'Your protected Cash on Delivery order $orderId is confirmed.'
        : 'Your order $orderId has been placed successfully.';

    final data = settingsDoc.data();
    if (data != null) {
      title = (data['title'] ?? title).toString();
      message = (data['message'] ?? message)
          .toString()
          .replaceAll('{orderId}', orderId)
          .replaceAll('{username}', userName)
          .replaceAll('{paymentMethod}', paymentMethod);
    }

    final notificationRef =
        FirebaseFirestore.instance.collection('notifications').doc();
    await notificationRef.set({
      'notificationId': notificationRef.id,
      'title': title,
      'message': message,
      'readBy': [],
      'timestamp': Timestamp.now(),
      'receiverIds': [userId],
    });
  }

  Future<void> _sendOrderSms({
    required String orderId,
    required String phone,
  }) async {
    if (phone.trim().isEmpty) return;

    final smsDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('doc2')
        .get();
    if (!smsDoc.exists) return;

    final rawSms = smsDoc.data()?['message']?.toString() ??
        'Your order {orderId} has been placed.';
    final finalMessage = rawSms.replaceAll('{orderId}', orderId);

    try {
      final response = await http.post(
        Uri.parse('https://sendordersms-j2ojxidybq-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phone,
          'message': finalMessage,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('SMS failed: ${response.statusCode} ${response.body}');
      }
    } catch (error) {
      debugPrint('SMS error: $error');
    }
  }

  Future<void> sendEmailFromFirestore({
    required String orderNumber,
    required String userName,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('doc3')
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final fromEmail = (data['email'] ?? '').toString().trim();
      final password = (data['pass'] ?? '').toString();
      if (fromEmail.isEmpty || password.isEmpty) return;

      final appName = (data['appname'] ?? 'App').toString();
      final subjectTemplate =
          (data['subject'] ?? 'Order Confirmation - #').toString();
      final bodyTemplate = (data['body'] ??
              'Hello {username},<br><br>Thank you for your order!<br><br>'
                  'Your order number is: <b>{orderid}</b><br><br>'
                  'Cheers,<br>{appname} Team')
          .toString();

      final smtpHost =
          (data['smtp_host'] ?? 'mail.privateemail.com').toString();
      final port = _readInt(data['smtp_port'], fallback: 587);
      final ssl = _readBool(data['smtp_ssl'], fallback: false);
      final smtpUser = (data['smtp_username'] ?? fromEmail).toString();
      final recipient = FirebaseAuth.instance.currentUser?.email ?? '';
      if (recipient.isEmpty) return;

      final message = Message()
        ..from = Address(fromEmail, appName)
        ..recipients.add(recipient)
        ..subject = '$subjectTemplate$orderNumber'
        ..html = bodyTemplate
            .replaceAll('{username}', userName)
            .replaceAll('{orderid}', orderNumber)
            .replaceAll('{appname}', appName);

      final primary = SmtpServer(
        smtpHost,
        port: port,
        username: smtpUser,
        password: password,
        ssl: ssl,
      );

      try {
        await send(message, primary);
      } catch (_) {
        final fallback = SmtpServer(
          smtpHost,
          port: 465,
          username: smtpUser,
          password: password,
          ssl: true,
        );
        await send(message, fallback);
      }
    } catch (error) {
      debugPrint('Email error: $error');
    }
  }

  Future<void> _applyRealtimeAggregates({
    required DocumentReference<Map<String, dynamic>> orderRef,
    required List<Map<String, dynamic>> items,
    required String userId,
  }) async {
    final db = FirebaseFirestore.instance;
    final perProduct = <String, int>{};

    for (final item in items) {
      final productId = (item['productId'] ?? item['id'] ?? '').toString();
      if (productId.isEmpty) continue;
      final rawQuantity = item['qty'] ?? item['quantity'] ?? 1;
      final quantity = rawQuantity is num ? rawQuantity.toInt() : 1;
      perProduct[productId] =
          (perProduct[productId] ?? 0) + (quantity > 0 ? quantity : 1);
    }

    try {
      await db.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);
        final orderData = orderSnapshot.data() ?? <String, dynamic>{};
        if (orderData['_aggDone'] == true) return;

        for (final entry in perProduct.entries) {
          transaction.set(
            db.collection('products').doc(entry.key),
            {'ordersCount': FieldValue.increment(entry.value)},
            SetOptions(merge: true),
          );
        }

        final userRef = db.collection('users').doc(userId);
        final userSnapshot = await transaction.get(userRef);
        final userData = userSnapshot.data() ?? <String, dynamic>{};
        final rawTimestamp = orderData['timestamp'];
        final timestamp =
            rawTimestamp is Timestamp ? rawTimestamp : Timestamp.now();

        final updates = <String, dynamic>{
          'ordersCount': FieldValue.increment(1),
          'lastOrderAt': timestamp,
        };
        if (userData['firstOrderAt'] == null) {
          updates['firstOrderAt'] = timestamp;
        }

        transaction.set(userRef, updates, SetOptions(merge: true));
        transaction.set(
          orderRef,
          {'_aggDone': true},
          SetOptions(merge: true),
        );
      });
    } catch (error, stackTrace) {
      debugPrint('Realtime aggregates failed: $error');
      debugPrint('$stackTrace');
    }
  }

  (String, String) _parseCountryRegionFromAddress(String address) {
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return ('', '');
    return (parts[parts.length - 2], parts.last);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Method',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<_PaymentConfiguration>(
        future: _configurationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error == null
                      ? 'Unable to load payment options.'
                      : _friendlyError(snapshot.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final configuration = snapshot.data!;
          final regionEligible = configuration.currentRegionKeys.any(
            configuration.allowedRegionKeys.contains,
          );
          final isCodAllowed = regionEligible &&
              configuration.policy.enabled &&
              configuration.policy.isEligible;
          final paymentOptions = isCodAllowed
              ? const ['Protected COD', 'Paystack']
              : const ['Paystack'];
          final effectiveSelection = selectedPaymentMethod ??
              (paymentOptions.length == 1 ? paymentOptions.first : '');
          final commitmentAmount = configuration.policy.commitmentAmount(
            orderTotal: _baseTotal,
            shippingFee: widget.shippingFee,
          );
          final amountDueOnDelivery =
              math.max(0.0, _baseTotal - commitmentAmount).toDouble();

          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFEFEF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Choose your payment method',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF002A5C),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (isCodAllowed) ...[
                          PaymentOptionCard(
                            icon: Icons.verified_user_outlined,
                            title: 'Protected Cash on Delivery',
                            description: configuration.policy.isEscalated
                                ? 'Pay a ${configuration.policy.escalatedDepositPercent.toStringAsFixed(0)}% commitment deposit now and the balance on delivery.'
                                : 'Pay the regional delivery fee now and the item balance on delivery.',
                            isSelected:
                                effectiveSelection == 'Protected COD',
                            onTap: () =>
                                _onPaymentMethodSelected('Protected COD'),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          _CodUnavailableCard(
                            message: !regionEligible
                                ? 'Cash on Delivery is not currently enabled for '
                                    '${configuration.currentRegionLabel}. Please use Paystack.'
                                : (!configuration.policy.enabled
                                    ? 'Protected Cash on Delivery is temporarily disabled. '
                                        'Please use Paystack.'
                                    : 'Cash on Delivery is suspended for this account '
                                        'because of previous failed deliveries. Please '
                                        'use Paystack.'),
                          ),
                          const SizedBox(height: 16),
                        ],
                        PaymentOptionCard(
                          icon: Icons.payment,
                          title: 'Paystack',
                          description:
                              'Pay the complete order amount securely online.',
                          isSelected: effectiveSelection == 'Paystack',
                          onTap: () =>
                              _onPaymentMethodSelected('Paystack'),
                        ),
                        const SizedBox(height: 18),
                        if (effectiveSelection == 'Protected COD') ...[
                          _ProtectedCodSummary(
                            currency: currencySymbol ?? 'GHS',
                            commitmentAmount:
                                _displayAmount(commitmentAmount),
                            dueOnDelivery:
                                _displayAmount(amountDueOnDelivery),
                            totalAmount: _displayAmount(_baseTotal),
                            deliveryPhone:
                                configuration.initialPhone.trim().isEmpty
                                    ? ''
                                    : _normalizePhone(
                                        configuration.initialPhone,
                                      ),
                            warningText:
                                configuration.policy.warningMessage,
                          ),
                          const SizedBox(height: 12),
                          _CodTermsAgreement(
                            value: _acceptCodTerms,
                            enabled: !_isProcessing,
                            onChanged: (value) {
                              setState(() {
                                _acceptCodTerms = value;
                              });
                            },
                          ),
                        ] else if (_currencyLoaded) ...[
                          _FullPaymentSummary(
                            currency: currencySymbol ?? 'GHS',
                            displayTotal: _displayAmount(_baseTotal),
                            baseTotal: _baseTotal,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 8,
                        offset: Offset(0, -2),
                        color: Color(0x1A000000),
                      ),
                    ],
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 52,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => _handleProceed(
                            effectiveSelection,
                            configuration,
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: const Color(0xFF002A5C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            effectiveSelection == 'Protected COD'
                                ? 'Pay commitment & confirm order'
                                : (effectiveSelection == 'Paystack'
                                    ? 'Pay full amount'
                                    : 'Continue'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentConfiguration {
  final Set<String> allowedRegionKeys;
  final Set<String> currentRegionKeys;
  final String currentRegionLabel;
  final _ProtectedCodPolicy policy;
  final String initialPhone;

  const _PaymentConfiguration({
    required this.allowedRegionKeys,
    required this.currentRegionKeys,
    required this.currentRegionLabel,
    required this.policy,
    required this.initialPhone,
  });
}

class _ProtectedCodPolicy {
  final bool enabled;
  final int warningAfter;
  final int escalatedAfter;
  final int suspendAfter;
  final double escalatedDepositPercent;
  final int failureCount;
  final bool manuallySuspended;

  const _ProtectedCodPolicy({
    required this.enabled,
    required this.warningAfter,
    required this.escalatedAfter,
    required this.suspendAfter,
    required this.escalatedDepositPercent,
    required this.failureCount,
    required this.manuallySuspended,
  });

  bool get isEligible => !manuallySuspended && failureCount < suspendAfter;

  bool get isEscalated =>
      failureCount >= escalatedAfter && failureCount < suspendAfter;

  String get riskTier {
    if (!isEligible) return 'suspended';
    if (isEscalated) return 'high';
    if (failureCount >= warningAfter) return 'warning';
    return 'standard';
  }

  String? get warningMessage {
    if (isEscalated) {
      return 'Because this account has previous failed deliveries, a higher '
          'commitment deposit is required for this order.';
    }
    if (failureCount >= warningAfter) {
      return 'This account has a previous failed delivery. Another failed or '
          'rejected delivery may increase the required deposit or restrict COD.';
    }
    return null;
  }

  double commitmentAmount({
    required double orderTotal,
    required double shippingFee,
  }) {
    if (!isEscalated) {
      return math.min(orderTotal, shippingFee).toDouble();
    }
    final percentageDeposit = orderTotal * (escalatedDepositPercent / 100);
    return math
        .min(orderTotal, math.max(shippingFee, percentageDeposit))
        .toDouble();
  }
}

class PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE8F1FB)
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF002A5C)
                : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 38,
              color: isSelected
                  ? const Color(0xFF002A5C)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? const Color(0xFF002A5C)
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProtectedCodSummary extends StatelessWidget {
  final String currency;
  final double commitmentAmount;
  final double dueOnDelivery;
  final double totalAmount;
  final String deliveryPhone;
  final String? warningText;

  const _ProtectedCodSummary({
    required this.currency,
    required this.commitmentAmount,
    required this.dueOnDelivery,
    required this.totalAmount,
    required this.deliveryPhone,
    required this.warningText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB7CEE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF002A5C)),
              SizedBox(width: 8),
              Text(
                'Protected COD breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002A5C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AmountRow(
            label: 'Pay now',
            value: '$currency ${commitmentAmount.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const SizedBox(height: 7),
          _AmountRow(
            label: 'Pay on delivery',
            value: '$currency ${dueOnDelivery.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 7),
          _AmountRow(
            label: 'Total order amount',
            value: '$currency ${totalAmount.toStringAsFixed(2)}',
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.phone_in_talk_outlined,
                size: 19,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deliveryPhone.isEmpty
                      ? 'You will confirm a delivery phone number before payment. No OTP is required.'
                      : 'Delivery phone: $deliveryPhone. You can confirm or edit it before payment.',
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
          if (warningText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade900,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningText!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _CodTermsAgreement extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _CodTermsAgreement({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9F7FB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1DCE7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Checkbox(
                  value: value,
                  onChanged: enabled
                      ? (checked) => onChanged(checked ?? false)
                      : null,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'By placing your order, you agree that:',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF24232A),
                      ),
                    ),
                    SizedBox(height: 10),
                    _AgreementBullet(
                      text: 'Your commitment fee confirms your order.',
                    ),
                    SizedBox(height: 6),
                    _AgreementBullet(
                      text: 'You will pay the remaining balance upon delivery.',
                    ),
                    SizedBox(height: 6),
                    _AgreementBullet(
                      text:
                          'Cash on Delivery (COD) privileges may be restricted only if you refuse or reject a correctly delivered order.',
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
}

class _AgreementBullet extends StatelessWidget {
  final String text;

  const _AgreementBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(
            Icons.circle,
            size: 5,
            color: Color(0xFF5E5768),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Color(0xFF3D3942),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullPaymentSummary extends StatelessWidget {
  final String currency;
  final double displayTotal;
  final double baseTotal;

  const _FullPaymentSummary({
    required this.currency,
    required this.displayTotal,
    required this.baseTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF002A5C).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total to pay: $currency ${displayTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF002A5C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paystack will charge GHS ${baseTotal.toStringAsFixed(2)}.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF8A00),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 16 : 14,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
            color: emphasize ? const Color(0xFF002A5C) : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _CodUnavailableCard extends StatelessWidget {
  final String message;

  const _CodUnavailableCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
