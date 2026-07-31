import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PromoCodeSection extends StatefulWidget {
  final double totalAmount;

  const PromoCodeSection({super.key, required this.totalAmount});

  @override
  _PromoCodeSectionState createState() => _PromoCodeSectionState();
}

class _PromoCodeSectionState extends State<PromoCodeSection> {
  final TextEditingController _promoCodeController = TextEditingController();
  String? _promoMessage;
  double? _discountedTotal;

    // Variables for currency data
  String? currencySymbol;

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


  @override
  void initState() {
    super.initState();
    _loadCurrencyData();
  }


double _convertPrice(double price) {
    return price * exchangeRate;
  }


  Future<void> _applyPromoCode() async {
    final promoCode = _promoCodeController.text.trim();

    if (promoCode.isEmpty) {
      setState(() {
        _promoMessage = "Please enter a promo code.";
      });
      return;
    }

    final promoSnapshot = await FirebaseFirestore.instance
        .collection('promocodes')
        .doc(promoCode)
        .get();

    if (promoSnapshot.exists) {
      final data = promoSnapshot.data()!;
      final discountPercentage = data['discountPercentage'] as double;

      setState(() {
        _promoMessage = "Promo code applied successfully!";
        _discountedTotal = widget.totalAmount -
            (widget.totalAmount * (discountPercentage / 100));
      });
    } else {
      setState(() {
        _promoMessage = "Invalid promo code.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _promoCodeController,
            decoration: InputDecoration(
              labelText: "Enter Promo Code",
              suffixIcon: IconButton(
                icon: const Icon(Icons.check),
                onPressed: _applyPromoCode,
              ),
            ),
          ),
          if (_promoMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _promoMessage!,
              style: TextStyle(
                color: _promoMessage == "Promo code applied successfully!"
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total:",
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
          Text(
  _discountedTotal != null
      ? "$currencySymbol${_discountedTotal!.toStringAsFixed(2)}"
      : "$currencySymbol${_convertPrice(widget.totalAmount).toStringAsFixed(2)}",
  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
)

            ],
          ),
        ],
      ),
    );
  }
}
