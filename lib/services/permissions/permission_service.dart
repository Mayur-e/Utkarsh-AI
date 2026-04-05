import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();
  static final instance = PermissionService._();

  /// Check and request microphone permission
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check and request notification permission
  Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Get current status
  Future<Map<String, PermissionStatus>> getStatus() async {
    return {
      'microphone': await Permission.microphone.status,
      'notification': await Permission.notification.status,
    };
  }

  /// Open app settings if permanently denied
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

final permissionService = PermissionService.instance;
