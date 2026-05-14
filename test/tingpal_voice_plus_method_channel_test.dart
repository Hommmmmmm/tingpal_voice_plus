import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tingpal_voice_plus/tingpal_voice_plus_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TingpalVoiceMethodChannelPlatform platform =
      TingpalVoiceMethodChannelPlatform();
  const MethodChannel channel = MethodChannel('tingpal_voice_plus');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('init and startListening', () async {
    await platform.init(appIdAndroid: 'test');
    await platform.setOptions(const <String, dynamic>{'domain': 'iat'});
    await platform.startListening();
    await platform.stopListening();
    await platform.cancelListening();
    await platform.disposeClient();
    expect(true, isTrue);
  });
}
