import 'package:flutter/material.dart';

class AppColors {
  static final AppColors _instance = AppColors._internal();

  factory AppColors() {
    return _instance;
  }

  AppColors._internal();

  final Map<String, Color> _colors = {
    'bulk': Colors.deepPurple,
    'category': const Color(0xFF002A5C),
    'flash': const Color(0xFF002A5C),
    'special': const Color.fromARGB(255, 147, 1, 173),
    'trending': Colors.teal,
    'weekly': const Color(0xFFFFA500),
     'promo': const Color.fromARGB(255, 175, 247, 7),
  };

  bool _isPublished = false;

  /// Update global colors from Firestore
  void updateColors(Map<String, dynamic> data) {
    // Check for publish flag
    if (data['publish'] != true) return;

    _isPublished = true;

    for (var key in _colors.keys) {
      if (data.containsKey(key)) {
        final hexValue = data[key];

        if (hexValue is String && hexValue.isNotEmpty) {
          try {
            _colors[key] = _hexToColor(hexValue);
          } catch (e) {
            debugPrint('Invalid hex for "$key": $hexValue');
          }
        }
      }
    }
  }

  /// Get color by section key
  Color getColor(String key) => _colors[key] ?? Colors.grey;

  /// Check if the published flag is active
  bool get isPublished => _isPublished;

  /// Internal: Convert hex string to Color
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // Add full opacity
    return Color(int.parse(hex, radix: 16));
  }
}
