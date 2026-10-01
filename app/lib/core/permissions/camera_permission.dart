import 'package:permission_handler/permission_handler.dart';

/// The three states a caller actually needs to branch on. `permission_handler`
/// has more granular statuses (restricted, limited, provisional) that don't
/// apply to a plain camera permission on Android/iOS, so this collapses them
/// rather than leaking `PermissionStatus` into every call site.
enum CameraPermissionResult { granted, denied, permanentlyDenied }

/// Requests camera permission, prompting the system dialog if it hasn't been
/// decided yet. Call this once, right before pushing the live-scan or
/// upload-fallback screen -- neither screen should assume permission is
/// already granted.
Future<CameraPermissionResult> requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isGranted) return CameraPermissionResult.granted;
  if (status.isPermanentlyDenied) {
    return CameraPermissionResult.permanentlyDenied;
  }
  return CameraPermissionResult.denied;
}

/// Checks the current status without prompting -- for deciding whether to
/// show a "camera access needed" screen before the user even taps scan.
Future<CameraPermissionResult> checkCameraPermission() async {
  final status = await Permission.camera.status;
  if (status.isGranted) return CameraPermissionResult.granted;
  if (status.isPermanentlyDenied) {
    return CameraPermissionResult.permanentlyDenied;
  }
  return CameraPermissionResult.denied;
}

/// Opens the OS app-settings page -- the only way to recover from
/// [CameraPermissionResult.permanentlyDenied], since requesting again is a
/// no-op once the user has checked "don't ask again."
Future<bool> openCameraPermissionSettings() => openAppSettings();
