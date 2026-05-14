import 'package:flutter_test/flutter_test.dart';
import 'package:tingpal_voice_plus/tingpal_voice_plus.dart';
import 'package:tingpal_voice_plus/tingpal_voice_plus_platform_interface.dart';
import 'package:tingpal_voice_plus/tingpal_voice_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTingpalVoicePlatform
    with MockPlatformInterfaceMixin
    implements TingpalVoicePlatform {
  final Stream<TingpalVoiceEvent> _emptyEvents =
      const Stream<TingpalVoiceEvent>.empty();

  @override
  Future<void> init({
    String? appIdIos,
    String? appIdAndroid,
    String? appIdWeb,
    String? appIdWindows,
  }) async {}

  @override
  Future<void> setOptions(Map<String, dynamic> options) async {}

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancelListening() async {}

  @override
  Future<void> disposeClient() async {}

  @override
  Stream<TingpalVoiceEvent> get events => _emptyEvents;
}

void main() {
  final TingpalVoicePlatform initialPlatform = TingpalVoicePlatform.instance;

  test('$TingpalVoiceMethodChannelPlatform is the default instance', () {
    expect(initialPlatform, isInstanceOf<TingpalVoiceMethodChannelPlatform>());
  });

  test('start and stop should be callable', () async {
    final voiceClient = TingpalVoiceClient.instance;
    final fakePlatform = MockTingpalVoicePlatform();
    TingpalVoicePlatform.instance = fakePlatform;

    await voiceClient.init(appIdAndroid: 'test');
    await voiceClient.start();
    await voiceClient.stop();
    await voiceClient.cancel();
    await voiceClient.dispose();
    expect(true, isTrue);
  });
}
