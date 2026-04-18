import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelLinkGravityFlutterSdk platform =
      MethodChannelLinkGravityFlutterSdk();
  const MethodChannel channel = MethodChannel('linkgravity_flutter_sdk');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
