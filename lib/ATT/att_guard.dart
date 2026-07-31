// // att_guard.dart
// import 'dart:io';
// import 'dart:async';
// import 'package:flutter/widgets.dart';
// import 'package:app_tracking_transparency/app_tracking_transparency.dart';

// class AttGuard with WidgetsBindingObserver {
//   final Duration afterOtherDialogDelay;
//   final Future<void> Function() initTrackingSdks;

//   AttGuard({
//     required this.initTrackingSdks,
//     this.afterOtherDialogDelay = const Duration(milliseconds: 0),
//   });

//   Future<void> run() async {
//     if (!Platform.isIOS) {
//       // Non-iOS: just init SDKs.
//       await initTrackingSdks();
//       return;
//     }

//     // Ensure lifecycle callbacks fire.
//     WidgetsBinding.instance.addObserver(this);

//     // If app is already active, proceed; otherwise wait for resumed.
//     if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
//       await _requestThenInit();
//     } else {
//       final c = Completer<void>();
//       void onResumed() async {
//         WidgetsBinding.instance.removeObserver(this);
//         await _requestThenInit();
//         c.complete();
//       }

//       // One-shot wait for resumed.
//       _resumeWaiter = onResumed;
//     }
//   }

//   VoidCallback? _resumeWaiter;

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed && _resumeWaiter != null) {
//       final cb = _resumeWaiter!;
//       _resumeWaiter = null;
//       cb();
//     }
//   }

//   Future<void> _requestThenInit() async {
//     // Optional spacing after another system dialog (e.g., notifications).
//     if (afterOtherDialogDelay.inMilliseconds > 0) {
//       await Future.delayed(afterOtherDialogDelay);
//     }

//     final status = await AppTrackingTransparency.trackingAuthorizationStatus;
//     if (status == TrackingStatus.notDetermined) {
//       await AppTrackingTransparency.requestTrackingAuthorization();
//     }

//     // Now it's safe to initialize any SDKs that could track.
//     await initTrackingSdks();
//   }
// }
