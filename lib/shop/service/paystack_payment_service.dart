// File: lib/services/paystack_payment_service.dart
import 'package:flutter/material.dart';
import 'package:pay_with_paystack/pay_with_paystack.dart';

/// A service that handles Paystack payments.
class PaystackPaymentService {
  /// Processes a Paystack payment.
  static Future<void> processPaystackPayment({
    required BuildContext context,
    required double totalAmount,
    required double shippingFee,
    required Future<String?> Function() onTransactionCompleted,
    required VoidCallback onTransactionFailed,
  }) async {
    final uniqueTransRef = PayWithPayStack().generateUuidV4();
    final amountInPesewas = ((totalAmount + shippingFee) * 100).toInt().toDouble();

    PayWithPayStack().now(
      context: context,
      secretKey: "sk_test_b39874d55f8ee9be128b489a7fd99ec8e01a9036",
      customerEmail: "ecdshelp@gmail.com",
      reference: uniqueTransRef,
      currency: "GHS",
      amount: amountInPesewas,
      callbackUrl: 'https://your.callback.url',
      transactionCompleted: () async {
        await onTransactionCompleted();
      },
      transactionNotCompleted: () {
        onTransactionFailed();
      },
    );
  }
}