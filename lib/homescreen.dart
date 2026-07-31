import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/social/social_media_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'shop/shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isOpeningWhatsApp = false;

  final List<Widget> _children = [
    const ShopScreen(),
    const SocialMediaScreen(),
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void onTabTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    _controller.forward(from: 0).then((_) {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSignedIn', false);

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed('/login');
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to sign out. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openWhatsAppSupport() async {
    if (_isOpeningWhatsApp) return;

    setState(() {
      _isOpeningWhatsApp = true;
    });

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await FirebaseFirestore.instance
              .collection('settings')
              .doc('doc7')
              .get();

      if (!document.exists) {
        throw Exception('Support settings document does not exist.');
      }

      final Map<String, dynamic>? data = document.data();

      if (data == null) {
        throw Exception('Support settings are empty.');
      }

      final String rawPhoneNumber =
          (data['company_phone'] ?? '').toString().trim();

      // Converts +233241317756 to 233241317756.
      final String phoneNumber =
          rawPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      if (phoneNumber.isEmpty) {
        throw Exception('WhatsApp support number is unavailable.');
      }

      const String message =
          'Hello Tremsol Support, I need assistance with the Tremsol app.';

      final Uri whatsappUrl = Uri.https(
        'wa.me',
        '/$phoneNumber',
        <String, String>{
          'text': message,
        },
      );

      final bool opened = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('WhatsApp could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open WhatsApp support. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningWhatsApp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,

      body: IndexedStack(
        index: _currentIndex,
        children: _children,
      ),

      // Show WhatsApp quick support on the Store tab only.
      floatingActionButton: _currentIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(
                right: 2,
                bottom: 4,
              ),
              child: Semantics(
                button: true,
                label: 'Contact Tremsol support on WhatsApp',
                child: FloatingActionButton(
                  heroTag: 'tremsolWhatsAppSupport',
                  onPressed:
                      _isOpeningWhatsApp ? null : _openWhatsAppSupport,
                  tooltip: 'WhatsApp Support',
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shape: const CircleBorder(),
                  child: _isOpeningWhatsApp
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          size: 31,
                        ),
                ),
              ),
            )
          : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // Compact Store/Social navigation
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF002A5C),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(22),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 18,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 7, 18, 6),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                Expanded(
                  child: _buildNavigationItem(
                    index: 0,
                    icon: Icons.shopping_bag_outlined,
                    selectedIcon: Icons.shopping_bag_rounded,
                    label: 'Store',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNavigationItem(
                    index: 1,
                    icon: Icons.group_outlined,
                    selectedIcon: Icons.group_rounded,
                    label: 'Social',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final bool isSelected = _currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTabTapped(index),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  key: ValueKey<bool>(isSelected),
                  size: 22,
                  color: isSelected
                      ? const Color(0xFFFF4E00)
                      : Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFFF4E00)
                      : Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}