import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _navy = Color(0xFF003B6F);
  static const Color _orange = Color(0xFFFF3D00);
  static const Duration _minimumSplashDuration = Duration(milliseconds: 2800);

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _navigationTimer;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.78, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _loadLogoFromFirestore();
    _scheduleNavigation();
  }

  Future<void> _loadLogoFromFirestore() async {
    try {
      final document = await FirebaseFirestore.instance
          .collection('settings')
          .doc('logo')
          .get();

      final value = document.data()?['logo_url'];
      final url = value is String ? value.trim() : '';

      if (!mounted || url.isEmpty) return;

      setState(() {
        _logoUrl = url;
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to load the splash logo from Firestore: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _scheduleNavigation() {
    _navigationTimer = Timer(_minimumSplashDuration, _openApp);
  }

  void _openApp() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, secondaryAnimation) {
          return const AuthGate();
        },
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final logoWidth = (screenSize.width * 0.72).clamp(250.0, 390.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFF3F6FC),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _PremiumSplashBackground(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 7),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: _LogoCard(
                          width: logoWidth,
                          logoUrl: _logoUrl,
                        ),
                      ),
                    ),
                    const Spacer(flex: 6),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tremendous deals at amazing prices',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _navy,
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 24),
                          _LoadingDots(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  const _LogoCard({
    required this.width,
    required this.logoUrl,
  });

  final double width;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _SplashScreenState._navy.withOpacity(0.08),
            blurRadius: 38,
            spreadRadius: 3,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _SplashScreenState._orange.withOpacity(0.04),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(8, 2),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 2.45,
        child: _BrandLogo(logoUrl: logoUrl),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/logo.jpg',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    final url = logoUrl;
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 350),
            child: child,
          );
        }

        return fallback;
      },
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final activeDot = (_controller.value * 3).floor().clamp(0, 2);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final isActive = index == activeDot;
            final dotColor = index == 1
                ? _SplashScreenState._orange
                : _SplashScreenState._navy;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: isActive ? 9 : 7,
              height: isActive ? 9 : 7,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: dotColor.withOpacity(isActive ? 1 : 0.20),
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: dotColor.withOpacity(0.20),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

class _PremiumSplashBackground extends StatelessWidget {
  const _PremiumSplashBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFCFDFF),
            Color(0xFFF7F9FD),
            Color(0xFFEEF3FB),
          ],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -110,
            right: -105,
            child: _GlowCircle(
              size: 285,
              color: _SplashScreenState._orange,
              opacity: 0.045,
            ),
          ),
          Positioned(
            bottom: -145,
            left: -120,
            child: _GlowCircle(
              size: 360,
              color: _SplashScreenState._navy,
              opacity: 0.075,
            ),
          ),
          CustomPaint(
            painter: _WavePainter(),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final navyPaint = Paint()
      ..color = _SplashScreenState._navy.withOpacity(0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final orangePaint = Paint()
      ..color = _SplashScreenState._orange.withOpacity(0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final firstPath = Path()
      ..moveTo(-size.width * 0.18, size.height * 0.62)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.76,
        size.width * 0.42,
        size.height * 0.55,
        size.width * 1.15,
        size.height * 0.48,
      );

    final secondPath = Path()
      ..moveTo(-size.width * 0.20, size.height * 0.84)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.70,
        size.width * 0.60,
        size.height * 0.78,
        size.width * 1.20,
        size.height * 0.56,
      );

    final thirdPath = Path()
      ..moveTo(size.width * 0.28, size.height * 1.05)
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.83,
        size.width * 0.80,
        size.height * 0.86,
        size.width * 1.12,
        size.height * 0.68,
      );

    canvas.drawPath(firstPath, navyPaint);
    canvas.drawPath(secondPath, navyPaint);
    canvas.drawPath(thirdPath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
