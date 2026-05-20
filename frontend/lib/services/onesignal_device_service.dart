import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../core/endpoints.dart';
import 'base_service.dart';

class OneSignalDeviceService {
  OneSignalDeviceService(this._baseService);

  final BaseService _baseService;

  bool get _supportsOneSignal =>
      _hasInitializedFlutterBinding() &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _hasInitializedFlutterBinding() {
    try {
      ServicesBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveCurrentSubscription({Map<String, dynamic>? userInfo}) async {
    if (!_supportsOneSignal) {
      debugPrint('OneSignal skipped: unsupported platform');
      return;
    }

    try {
      await OneSignal.User.pushSubscription.optIn();

      final Object? loggedInUserId = userInfo?['id'];
      debugPrint('OneSignal save for logged-in user id: $loggedInUserId');

      final String? subscriptionId = await _subscriptionIdWithRetry();
      debugPrint('OneSignal subscription ID: $subscriptionId');

      if (subscriptionId == null || subscriptionId.isEmpty) {
        debugPrint('OneSignal subscription ID is not available yet.');
        return;
      }

      final payload = <String, dynamic>{
        'device_token': subscriptionId,
        'provider': 'onesignal',
        'device_name': defaultTargetPlatform.name,
      };

      final dynamic response = await _baseService.postJson<dynamic>(
        Endpoints.saveOneSignalId,
        payload,
        (data) => data,
      );

      debugPrint('OneSignal /api/save-onesignal-id response: $response');
    } catch (error, stackTrace) {
      debugPrint('Failed to save OneSignal subscription ID: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String?> _subscriptionIdWithRetry() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final String? subscriptionId = OneSignal.User.pushSubscription.id;
      debugPrint(
        'OneSignal subscription lookup ${attempt + 1}: $subscriptionId',
      );

      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        return subscriptionId;
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    return OneSignal.User.pushSubscription.id;
  }
}
