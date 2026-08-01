import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tremsolapp/custom_ad/ad_widget.dart';
import 'package:tremsolapp/internet_connect/app_shell.dart';
import 'package:tremsolapp/services/presence_service.dart.dart';
import 'package:tremsolapp/shop/promo_deals_page.dart';



import 'auth/google_signin.dart';
import 'auth/signin_screen.dart';
import 'firebase_options.dart';
import 'homescreen.dart';
import 'auth/auth_gate.dart';

// --------------------- Globals ---------------------

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be initialized before Firestore, Authentication,
  // OneSignal configuration from Firestore, or any other Firebase service.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  FacebookAuth.instance.webAndDesktopInitialize(
    appId: '526801647139656',
    cookie: true,
    xfbml: true,
    version: 'v18.0',
  );

  // Draw the first Flutter frame as soon as Firebase is ready. The native
  // launch screen remains visible until this point, so there is no second
  // Flutter splash page.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GoogleSignInProvider>(
          create: (_) => GoogleSignInProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // OneSignal is non-critical for the first frame. Initializing it after the
  // app is visible shortens the native launch-screen duration.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeDeferredServices());
  });
}

Future<void> _initializeDeferredServices() async {
  try {
    await _initOneSignal();
  } catch (error, stackTrace) {
    debugPrint('[OneSignal] Initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

/// Initializes OneSignal and wires notification listeners.
Future<void> _initOneSignal() async {
  // Firestore location:
  // Collection: settings
  // Document:   onesignal
  // Field:      AppId
  final doc = await FirebaseFirestore.instance
      .collection('settings')
      .doc('onesignal')
      .get();

  final data = doc.data();
  final oneSignalAppId = data?['AppId']?.toString().trim();

  if (oneSignalAppId == null || oneSignalAppId.isEmpty) {
    debugPrint(
      '[OneSignal] AppId missing in Firestore: settings/onesignal.AppId',
    );
    return;
  }

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(oneSignalAppId);

  // Ask for notification permission on iOS and supported Android versions.
  await OneSignal.Notifications.requestPermission(true);

  // Explicit Android 13+ notification permission request.
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Foreground notifications use OneSignal's default display behaviour.
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    // Call event.preventDefault() here only when implementing
    // custom foreground notification handling.
  });

  // Open the promotional-products page when a notification is tapped.
  OneSignal.Notifications.addClickListener((event) {
    final additionalData = event.notification.additionalData ?? {};

    final notificationData = additionalData.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    _openPromoFromData(notificationData);
  });

  // Current OneSignal push subscription ID.
  final currentId = OneSignal.User.pushSubscription.id;

  if (currentId != null && currentId.isNotEmpty) {
    // TODO: Store currentId in Firestore and associate it with the signed-in user.
    debugPrint('[OneSignal] Current subscription ID: $currentId');
  }

  // Observe future subscription-ID changes.
  OneSignal.User.pushSubscription.addObserver((state) {
    final id = state.current.id;

    if (id != null && id.isNotEmpty) {
      // TODO: Store id in Firestore and associate it with the signed-in user.
      debugPrint('[OneSignal] Subscription ID updated: $id');
    }
  });
}

// -----------------------------------------------------------------
// Deep-link helpers
// -----------------------------------------------------------------

void _handlePayloadOrUrl(String payload) {
  try {
    final decoded = jsonDecode(payload);

    if (decoded is Map) {
      final map = decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );

      _openPromoFromData(map);
      return;
    }

    navKey.currentState?.pushNamed('/promo');
  } catch (_) {
    final uri = Uri.tryParse(payload);

    if (uri != null && uri.path.contains('promo')) {
      final map = <String, String>{};

      for (final key in ['categoryId', 'promoTag']) {
        final value = uri.queryParameters[key];

        if (value != null && value.isNotEmpty) {
          map[key] = value;
        }
      }

      _openPromoFromData(map);
    } else {
      navKey.currentState?.pushNamed('/promo');
    }
  }
}

/// Opens the promotional-products page.
///
/// The data argument is retained so that notification category or promo-tag
/// filters can be added later without changing the notification listener.
void _openPromoFromData(Map<String, String> data) {
  navKey.currentState?.pushNamed('/promo');
}

class ProductsRouteArgs {
  final String? tab;
  final String? categoryId;
  final String? query;
  final String? sort;

  const ProductsRouteArgs({
    this.tab,
    this.categoryId,
    this.query,
    this.sort,
  });

  factory ProductsRouteArgs.fromMap(Map<String, String> map) {
    return ProductsRouteArgs(
      tab: map['tab'],
      categoryId: map['categoryId'],
      query: map['query'],
      sort: map['sort'],
    );
  }

  Map<String, String> toMap() {
    return {
      if (tab != null) 'tab': tab!,
      if (categoryId != null) 'categoryId': categoryId!,
      if (query != null) 'query': query!,
      if (sort != null) 'sort': sort!,
    };
  }
}

void _openProductsFromData(Map<String, String> data) {
  final args = ProductsRouteArgs.fromMap(data);

  navKey.currentState?.pushNamed(
    '/products',
    arguments: args,
  );
}

Future<void> signOutUser() async {
  await FirebaseAuth.instance.signOut();
}

// --------------------- App widgets ---------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const AuthGate(),
      routes: {
        '/login': (_) => const SignInScreen(),
        '/home': (_) => const HomeScreen(),
        '/adModal': (_) => const AdModalPage(),
        '/promo': (_) => const PromoDealsPage(),
        '/products': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as ProductsRouteArgs?;

          return Scaffold(
            appBar: AppBar(
              title: Text(_titleFromArgs(args)),
            ),
            body: Center(
              child: Text(
                'Products List — filters: ${args?.toMap()}',
              ),
            ),
          );
        },
      },
    );
  }

  String _titleFromArgs(ProductsRouteArgs? args) {
    if (args?.tab == 'deals') return 'Deals';
    if (args?.tab == 'new') return 'New Arrivals';
    if (args?.tab == 'recommended') return 'Recommended';

    return 'Products';
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final uid = snapshot.data!.uid;

          return PresenceGate(
            uid: uid,
            child: const AppShell(),
          );
        }

        return const SignInScreen();
      },
    );
  }
}

/// Starts FirestorePresence for the current user and manages its lifecycle.
class PresenceGate extends StatefulWidget {
  final String uid;
  final Widget child;

  const PresenceGate({
    super.key,
    required this.uid,
    required this.child,
  });

  @override
  State<PresenceGate> createState() => _PresenceGateState();
}

class _PresenceGateState extends State<PresenceGate> {
  FirestorePresence? _presence;

  @override
  void initState() {
    super.initState();
    _startPresence(widget.uid);
  }

  @override
  void didUpdateWidget(covariant PresenceGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.uid != widget.uid) {
      _presence?.disposeService();
      _startPresence(widget.uid);
    }
  }

  void _startPresence(String uid) {
    _presence = FirestorePresence(uid)..start();
  }

  @override
  void dispose() {
    _presence?.disposeService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
