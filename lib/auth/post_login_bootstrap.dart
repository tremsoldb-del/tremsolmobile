import '../services/user_metadata_service.dart';

/// Ensures every signed-in Tremsol user has the required account, commerce,
/// notification, app, device, locale, and last-seen metadata.
///
/// Existing values are preserved. Only missing profile/default fields are
/// backfilled, while current app/device/last-seen fields are refreshed.
Future<void> postLoginBootstrap({
  String? fullName,
  String? username,
  String? profilePic,
  bool captureSignupSnapshot = false,
}) async {
  await UserMetadataService.instance.syncCurrentUser(
    fullName: fullName,
    username: username,
    profilePic: profilePic,
    captureSignupSnapshot: captureSignupSnapshot,
    awaitNetworkMetadata: captureSignupSnapshot,
  );
}
