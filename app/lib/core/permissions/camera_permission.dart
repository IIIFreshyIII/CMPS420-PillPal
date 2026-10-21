import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// The three states a caller actually needs to branch on.
enum CameraPermissionResult { granted, denied, permanentlyDenied }

const _permissionsChannel = MethodChannel('com.cmps420.pillpal/permissions');

/// Requests camera permission, prompting the system dialog if it hasn't been
/// decided yet. Calls native AVCaptureDevice on iOS without powering on the
/// camera lens hardware, preventing the green privacy indicator dot.
Future<CameraPermissionResult> requestCameraPermission() async {
  if (Platform.isIOS) {
    try {
      // 1. Check existing status first
      final checkStatus =
          await _permissionsChannel.invokeMethod<String>('checkCamera');
      if (checkStatus == 'granted') return CameraPermissionResult.granted;

      // 2. Request permission via AVCaptureDevice.requestAccess
      final granted =
          await _permissionsChannel.invokeMethod<bool>('requestCamera');
      if (granted == true) return CameraPermissionResult.granted;

      // 3. Re-check status to distinguish denied from notDetermined
      final postStatus =
          await _permissionsChannel.invokeMethod<String>('checkCamera');
      if (postStatus == 'denied') return CameraPermissionResult.permanentlyDenied;
      return CameraPermissionResult.denied;
    } catch (_) {
      // If MethodChannel fails or is missing in current native build, check
      // availableCameras() or grant in debug/profile to prevent falsely blocking the user
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) return CameraPermissionResult.granted;
      } catch (_) {}
      if (kDebugMode || kProfileMode) {
        return CameraPermissionResult.granted;
      }
      return CameraPermissionResult.denied;
    }
  }

  // Android: use permission_handler
  final status = await Permission.camera.request();
  if (status.isGranted) return CameraPermissionResult.granted;
  if (status.isPermanentlyDenied) {
    return CameraPermissionResult.permanentlyDenied;
  }
  return CameraPermissionResult.denied;
}

/// Checks the current status without prompting.
Future<CameraPermissionResult> checkCameraPermission() async {
  if (Platform.isIOS) {
    try {
      final status =
          await _permissionsChannel.invokeMethod<String>('checkCamera');
      if (status == 'granted') return CameraPermissionResult.granted;
      if (status == 'denied') return CameraPermissionResult.permanentlyDenied;
      return CameraPermissionResult.denied;
    } catch (_) {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) return CameraPermissionResult.granted;
      } catch (_) {}
      if (kDebugMode || kProfileMode) {
        return CameraPermissionResult.granted;
      }
      return CameraPermissionResult.denied;
    }
  }

  // Android: use permission_handler
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
