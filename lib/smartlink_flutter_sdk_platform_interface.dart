import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'smartlink_flutter_sdk_method_channel.dart';

abstract class SmartlinkFlutterSdkPlatform extends PlatformInterface {
  /// Constructs a SmartlinkFlutterSdkPlatform.
  SmartlinkFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static SmartlinkFlutterSdkPlatform _instance = MethodChannelSmartlinkFlutterSdk();

  /// The default instance of [SmartlinkFlutterSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelSmartlinkFlutterSdk].
  static SmartlinkFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SmartlinkFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(SmartlinkFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
