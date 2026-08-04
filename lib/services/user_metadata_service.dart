import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Creates and maintains the Firestore profile for the signed-in user.
///
/// The service has two responsibilities:
/// 1. Create a complete user/app metadata record for new accounts.
/// 2. Backfill only missing fields for existing accounts while refreshing
///    current app, device, notification-token, and last-seen information.
class UserMetadataService {
  UserMetadataService._();

  static final UserMetadataService instance = UserMetadataService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isBlank(dynamic value) {
    return value == null || (value is String && value.trim().isEmpty);
  }

  String? _cleanNullable(dynamic value) {
    final cleaned = (value ?? '').toString().trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  String _cleanOrUnknown(dynamic value) {
    return _cleanNullable(value) ?? 'Unknown';
  }

  String _platformName() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String _fallbackUsername(User user, String? preferredName) {
    final preferred = _cleanNullable(preferredName);
    if (preferred != null) return preferred;

    final displayName = _cleanNullable(user.displayName);
    if (displayName != null) return displayName;

    final email = _cleanNullable(user.email);
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return '';
  }

  Map<String, dynamic> _localeMetadata() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final now = DateTime.now();

    return {
      'deviceLocaleTag': locale.toLanguageTag(),
      'deviceLanguageCode': _cleanNullable(locale.languageCode),
      'deviceCountryCode': _cleanNullable(locale.countryCode),
      'deviceTimezoneName': now.timeZoneName,
      'deviceTimezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
    };
  }

  Future<Map<String, dynamic>> _collectClientMetadata() async {
    final serverNow = FieldValue.serverTimestamp();
    final platform = _platformName();

    final data = <String, dynamic>{
      'appPlatform': platform,
      'platform': platform,
      'lastSeenAt': serverNow,
      'deviceInfoUpdatedAt': serverNow,
      'hasClientMetadata': true,
      'needsClientMetadataRefresh': false,
      ..._localeMetadata(),
    };

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      data.addAll({
        'appVersion': packageInfo.version,
        'appBuildNumber': packageInfo.buildNumber,
        'appPackageName': packageInfo.packageName,
        'appName': packageInfo.appName,
      });
    } catch (error) {
      debugPrint('Unable to read package metadata: $error');
      data.addAll({
        'appVersion': 'Unknown',
        'appBuildNumber': 'Unknown',
        'appPackageName': 'Unknown',
        'appName': 'Tremsol',
      });
    }

    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final info = await deviceInfo.webBrowserInfo;
        data.addAll({
          'osVersion': _cleanOrUnknown(info.platform),
          'deviceModel': _cleanOrUnknown(info.userAgent),
          'browserName': describeEnum(info.browserName),
          'deviceManufacturer': 'Unknown',
          'deviceBrand': 'Unknown',
          'deviceName': _cleanOrUnknown(info.appName),
          'isPhysicalDevice': false,
        });
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfo.androidInfo;
        data.addAll({
          'osVersion': 'Android ${_cleanOrUnknown(info.version.release)}',
          'androidVersionRelease': _cleanOrUnknown(info.version.release),
          'androidSdkInt': info.version.sdkInt,
          'deviceManufacturer': _cleanOrUnknown(info.manufacturer),
          'deviceBrand': _cleanOrUnknown(info.brand),
          'deviceModel': _cleanOrUnknown(info.model),
          'deviceName': _cleanOrUnknown(info.device),
          'isPhysicalDevice': info.isPhysicalDevice,
        });
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfo.iosInfo;
        data.addAll({
          'osVersion':
              '${_cleanOrUnknown(info.systemName)} ${_cleanOrUnknown(info.systemVersion)}',
          'iosSystemName': _cleanOrUnknown(info.systemName),
          'iosSystemVersion': _cleanOrUnknown(info.systemVersion),
          'deviceManufacturer': 'Apple',
          'deviceBrand': 'Apple',
          'deviceModel': _cleanOrUnknown(info.model),
          'deviceName': _cleanOrUnknown(info.name),
          'isPhysicalDevice': info.isPhysicalDevice,
        });
      } else {
        data.addAll({
          'osVersion': platform,
          'deviceManufacturer': 'Unknown',
          'deviceBrand': 'Unknown',
          'deviceModel': 'Unknown',
          'deviceName': 'Unknown',
          'isPhysicalDevice': true,
        });
      }
    } catch (error) {
      debugPrint('Unable to read device metadata: $error');
      data.addAll({
        'osVersion': data['osVersion'] ?? 'Unknown',
        'deviceManufacturer': data['deviceManufacturer'] ?? 'Unknown',
        'deviceBrand': data['deviceBrand'] ?? 'Unknown',
        'deviceModel': data['deviceModel'] ?? 'Unknown',
        'deviceName': data['deviceName'] ?? 'Unknown',
        'isPhysicalDevice': data['isPhysicalDevice'] ?? true,
      });
    }

    return data;
  }

  Future<Map<String, dynamic>> _lookupIpLocation() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return {};

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] == false) {
        return {};
      }

      final timezone = decoded['timezone'];
      final currency = decoded['currency'];

      return {
        'lastSeenIp': _cleanNullable(decoded['ip']),
        'lastSeenCountry': _cleanNullable(decoded['country']),
        'lastSeenCountryCode': _cleanNullable(decoded['country_code']),
        'lastSeenRegion': _cleanNullable(decoded['region']),
        'lastSeenCity': _cleanNullable(decoded['city']),
        'lastSeenLatitude': decoded['latitude'],
        'lastSeenLongitude': decoded['longitude'],
        'lastSeenTimezone': timezone is Map
            ? _cleanNullable(timezone['id'])
            : _cleanNullable(timezone),
        'lastSeenCurrencyCode': currency is Map
            ? _cleanNullable(currency['code'])
            : _cleanNullable(currency),
      }..removeWhere((key, value) => value == null);
    } catch (error) {
      debugPrint('Unable to read IP location metadata: $error');
      return {};
    }
  }

  void _putIfMissing(
    Map<String, dynamic> patch,
    Map<String, dynamic> existing,
    String key,
    dynamic value, {
    bool replaceBlankString = true,
  }) {
    final keyIsMissing = !existing.containsKey(key);
    final blankString = replaceBlankString && _isBlank(existing[key]);

    if (keyIsMissing || blankString) {
      patch[key] = value;
    }
  }

  bool _needsSignupSnapshot(Map<String, dynamic> existing) {
    const requiredSnapshotKeys = [
      'signupPlatform',
      'signupAppVersion',
      'signupOsVersion',
      'signupDeviceModel',
      'signupCapturedAt',
    ];

    return requiredSnapshotKeys.any(
      (key) => !existing.containsKey(key) || _isBlank(existing[key]),
    );
  }

  bool _needsNetworkRefresh(Map<String, dynamic> existing) {
    if (_isBlank(existing['lastSeenCountry']) ||
        _isBlank(existing['lastSeenCountryCode'])) {
      return true;
    }

    final lastUpdated = existing['locationMetadataUpdatedAt'];
    if (lastUpdated is! Timestamp) return true;

    return DateTime.now().difference(lastUpdated.toDate()) >=
        const Duration(hours: 24);
  }

  Map<String, dynamic> _signupClientSnapshot(
    Map<String, dynamic> clientMetadata,
  ) {
    return {
      'signupPlatform': clientMetadata['appPlatform'],
      'signupAppVersion': clientMetadata['appVersion'],
      'signupAppBuildNumber': clientMetadata['appBuildNumber'],
      'signupAppPackageName': clientMetadata['appPackageName'],
      'signupAppName': clientMetadata['appName'],
      'signupOsVersion': clientMetadata['osVersion'],
      'signupDeviceModel': clientMetadata['deviceModel'],
      'signupDeviceManufacturer': clientMetadata['deviceManufacturer'],
      'signupDeviceBrand': clientMetadata['deviceBrand'],
      'signupDeviceName': clientMetadata['deviceName'],
      'signupIsPhysicalDevice': clientMetadata['isPhysicalDevice'],
      'signupLocaleTag': clientMetadata['deviceLocaleTag'],
      'signupLanguageCode': clientMetadata['deviceLanguageCode'],
      'signupCountryCode': clientMetadata['deviceCountryCode'],
      'signupDeviceTimezoneName': clientMetadata['deviceTimezoneName'],
      'signupDeviceTimezoneOffsetMinutes':
          clientMetadata['deviceTimezoneOffsetMinutes'],
    }..removeWhere((key, value) => value == null);
  }

  Map<String, dynamic> _signupLocationSnapshot(
    Map<String, dynamic> locationMetadata,
  ) {
    return {
      'signupIp': locationMetadata['lastSeenIp'],
      'signupCountry': locationMetadata['lastSeenCountry'],
      'signupCountryCode': locationMetadata['lastSeenCountryCode'],
      'signupRegion': locationMetadata['lastSeenRegion'],
      'signupCity': locationMetadata['lastSeenCity'],
      'signupLatitude': locationMetadata['lastSeenLatitude'],
      'signupLongitude': locationMetadata['lastSeenLongitude'],
      'signupTimezone': locationMetadata['lastSeenTimezone'],
      'signupCurrencyCode': locationMetadata['lastSeenCurrencyCode'],
    }..removeWhere((key, value) => value == null);
  }

  Future<void> _syncFcmToken(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (_cleanNullable(token) == null) return;

      await ref.set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Unable to save FCM token: $error');
    }
  }

  Future<void> _syncNetworkMetadata({
    required DocumentReference<Map<String, dynamic>> ref,
    required bool captureSignupSnapshot,
    required bool backfillSignupSnapshot,
  }) async {
    try {
      final location = await _lookupIpLocation();
      if (location.isEmpty) return;

      final latestSnapshot = await ref.get();
      final existing = latestSnapshot.data() ?? <String, dynamic>{};
      final patch = <String, dynamic>{
        ...location,
        'locationMetadataUpdatedAt': FieldValue.serverTimestamp(),
      };

      _putIfMissing(
        patch,
        existing,
        'country',
        location['lastSeenCountry'] ?? '',
      );
      _putIfMissing(
        patch,
        existing,
        'countryCode',
        location['lastSeenCountryCode'],
      );

      // Do not populate Tremsol's profile `region` from IP data. That field is
      // used for shipping/COD selection, while lastSeenRegion is observational.
      if (captureSignupSnapshot || backfillSignupSnapshot) {
        final signupLocation = _signupLocationSnapshot(location);
        if (captureSignupSnapshot) {
          // For a real new signup, IP-derived country data is more reliable
          // than the device locale and should become the signup snapshot.
          patch.addAll(signupLocation);
        } else {
          for (final entry in signupLocation.entries) {
            _putIfMissing(patch, existing, entry.key, entry.value);
          }
        }

        patch['signupOriginSource'] = captureSignupSnapshot
            ? 'ip_lookup'
            : 'first_access_backfill_ip_lookup';
      }

      await ref.set(patch, SetOptions(merge: true));
    } catch (error, stackTrace) {
      debugPrint('Unable to save network metadata: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Synchronizes the current Firebase user with Firestore.
  ///
  /// [captureSignupSnapshot] should be true only immediately after a new
  /// account is created. For existing users, missing historical signup fields
  /// are backfilled from their first app access after this update and clearly
  /// marked as backfilled rather than being presented as original signup data.
  Future<void> syncCurrentUser({
    String? fullName,
    String? username,
    String? profilePic,
    bool captureSignupSnapshot = false,
    bool awaitNetworkMetadata = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    final existing = snapshot.data() ?? <String, dynamic>{};
    final isNewDocument = !snapshot.exists;
    final needsSignupBackfill =
        !captureSignupSnapshot && _needsSignupSnapshot(existing);

    final clientMetadata = await _collectClientMetadata();
    final serverNow = FieldValue.serverTimestamp();
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    final resolvedFullName = _cleanNullable(fullName) ??
        _cleanNullable(user.displayName) ??
        _cleanNullable(existing['username']) ??
        '';
    final resolvedUsername = _fallbackUsername(
      user,
      _cleanNullable(username) ?? _cleanNullable(existing['fullname']),
    );
    final resolvedProfilePic =
        _cleanNullable(profilePic) ?? _cleanNullable(user.photoURL) ?? '';

    final patch = <String, dynamic>{
      ...clientMetadata,
      'uid': user.uid,
      'lastOnline': serverNow,
      'updatedAt': serverNow,
      'isActive': true,
      'emailVerified': user.emailVerified,
      'emailVerificationStatus':
          user.emailVerified ? 'verified' : 'pending',
      'authProviderIds': providerIds,
      'primaryAuthProvider': providerIds.isNotEmpty ? providerIds.first : null,
    }..removeWhere((key, value) => value == null);

    if (_cleanNullable(user.email) != null) {
      patch['email'] = user.email;
    }
    if (_cleanNullable(user.phoneNumber) != null) {
      patch['phone'] = user.phoneNumber;
    }
    if (user.metadata.lastSignInTime != null) {
      patch['lastSignInAt'] = Timestamp.fromDate(user.metadata.lastSignInTime!);
    }

    _putIfMissing(patch, existing, 'fullname', resolvedFullName);
    _putIfMissing(patch, existing, 'username', resolvedUsername);
    _putIfMissing(patch, existing, 'profilepic', resolvedProfilePic);
    _putIfMissing(patch, existing, 'isWebuser', kIsWeb);
    _putIfMissing(patch, existing, 'role', 1, replaceBlankString: false);
    _putIfMissing(patch, existing, 'country', '');
    _putIfMissing(patch, existing, 'countryCode', null);
    _putIfMissing(patch, existing, 'region', '');
    _putIfMissing(patch, existing, 'shippingaddress', '');

    // Tremsol commerce/COD account defaults. These are only inserted when the
    // field does not already exist; existing counts and restrictions remain.
    _putIfMissing(patch, existing, 'ordersCount', 0, replaceBlankString: false);
    _putIfMissing(patch, existing, 'firstOrderAt', null,
        replaceBlankString: false);
    _putIfMissing(patch, existing, 'lastOrderAt', null,
        replaceBlankString: false);
    _putIfMissing(patch, existing, 'codFailureCount', 0,
        replaceBlankString: false);
    _putIfMissing(patch, existing, 'codSuspended', false,
        replaceBlankString: false);
    _putIfMissing(patch, existing, 'codPhoneVerified', false,
        replaceBlankString: false);
    _putIfMissing(patch, existing, 'codVerifiedPhone', '');

    final authCreatedAt = user.metadata.creationTime;
    _putIfMissing(
      patch,
      existing,
      'createdAt',
      authCreatedAt == null ? serverNow : Timestamp.fromDate(authCreatedAt),
      replaceBlankString: false,
    );
    _putIfMissing(
      patch,
      existing,
      'timestamp',
      authCreatedAt == null ? serverNow : Timestamp.fromDate(authCreatedAt),
      replaceBlankString: false,
    );
    _putIfMissing(
      patch,
      existing,
      'accountCreatedAt',
      authCreatedAt == null ? serverNow : Timestamp.fromDate(authCreatedAt),
      replaceBlankString: false,
    );

    if (captureSignupSnapshot || needsSignupBackfill || isNewDocument) {
      final signupClient = _signupClientSnapshot(clientMetadata);
      for (final entry in signupClient.entries) {
        _putIfMissing(patch, existing, entry.key, entry.value);
      }

      _putIfMissing(
        patch,
        existing,
        'signupCapturedAt',
        serverNow,
        replaceBlankString: false,
      );

      patch['signupSnapshotIsBackfilled'] = !captureSignupSnapshot;
      patch['signupSnapshotSource'] = captureSignupSnapshot
          ? 'signup'
          : 'first_access_backfill';

      if (!captureSignupSnapshot) {
        patch['signupMetadataBackfilledAt'] = serverNow;
      }

      _putIfMissing(
        patch,
        existing,
        'signupOriginSource',
        captureSignupSnapshot ? 'device_locale' : 'first_access_backfill',
      );
    }

    await ref.set(patch, SetOptions(merge: true));

    final fcmFuture = _syncFcmToken(ref);
    final shouldRefreshNetwork =
        captureSignupSnapshot || _needsNetworkRefresh(existing);

    Future<void>? networkFuture;
    if (shouldRefreshNetwork) {
      networkFuture = _syncNetworkMetadata(
        ref: ref,
        captureSignupSnapshot: captureSignupSnapshot,
        backfillSignupSnapshot: needsSignupBackfill || isNewDocument,
      );
    }

    if (awaitNetworkMetadata) {
      await Future.wait([
        fcmFuture,
        if (networkFuture != null) networkFuture,
      ]);
    } else {
      unawaited(fcmFuture);
      if (networkFuture != null) unawaited(networkFuture);
    }
  }
}
