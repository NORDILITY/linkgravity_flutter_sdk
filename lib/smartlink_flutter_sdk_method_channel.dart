import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'smartlink_flutter_sdk_platform_interface.dart';

/// An implementation of [SmartlinkFlutterSdkPlatform] that uses method channels.
class MethodChannelSmartlinkFlutterSdk extends SmartlinkFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('smartlink_flutter_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
