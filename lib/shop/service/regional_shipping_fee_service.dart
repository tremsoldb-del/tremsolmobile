import 'package:cloud_firestore/cloud_firestore.dart';

class RegionalShippingFeeService {
  RegionalShippingFeeService._();

  static const String settingsCollection = 'settings';
  static const String settingsDocument = 'regionalShippingFees';

  static String normalizeRegionKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'\s+region$'), '');
  }

  static Future<double> fetchFeeForRegion(String region) async {
    final requestedKey = normalizeRegionKey(region);

    if (requestedKey.isEmpty) {
      throw StateError(
        'The selected shipping address does not have a valid region.',
      );
    }

    final document = await FirebaseFirestore.instance
        .collection(settingsCollection)
        .doc(settingsDocument)
        .get();

    if (!document.exists) {
      throw StateError(
        'Regional shipping fees have not been configured. '
        'Open the Regional Shipping Fees admin page and save the fees.',
      );
    }

    final data = document.data() ?? <String, dynamic>{};
    final rawFees = data['fees'];

    if (rawFees is! Map) {
      throw StateError(
        'The regional shipping fee configuration is invalid.',
      );
    }

    final normalizedFees = <String, dynamic>{};
    for (final entry in rawFees.entries) {
      final key = normalizeRegionKey(entry.key.toString());
      if (key.isNotEmpty) {
        normalizedFees[key] = entry.value;
      }
    }

    final rawFee = normalizedFees[requestedKey];
    final fee = _parseAmount(rawFee);

    if (fee == null || fee < 0) {
      throw StateError(
        'No valid shipping fee has been configured for $region.',
      );
    }

    return fee;
  }

  static double? _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned);
    }

    return null;
  }
}
