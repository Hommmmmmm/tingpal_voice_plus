/*
 * @Author: WangHong hong.wang@azenta.com
 * @Date: 2026-05-12 09:54:32
 * @LastEditors: WangHong hong.wang@azenta.com
 * @LastEditTime: 2026-05-12 10:04:44
 * @FilePath: /TingPal/Users/WangHong/Desktop/tingpal_voice_plus/lib/tingpal_voice_plus_platform_interface.dart
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'tingpal_voice_plus_method_channel.dart';

enum TingpalVoiceEventType {
  onBeginOfSpeech,
  onEndOfSpeech,
  onResults,
  onCompleted,
  onVolumeChanged,
  onCancel,
}

class TingpalVoiceEvent {
  const TingpalVoiceEvent({required this.type, required this.payload});

  final TingpalVoiceEventType type;
  final Map<String, dynamic> payload;
}

abstract class TingpalVoicePlatform extends PlatformInterface {
  TingpalVoicePlatform() : super(token: _token);

  static final Object _token = Object();

  static TingpalVoicePlatform _instance = TingpalVoiceMethodChannelPlatform();

  static TingpalVoicePlatform get instance => _instance;

  static set instance(TingpalVoicePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> init({
    String? appIdIos,
    String? appIdAndroid,
    String? appIdWeb,
    String? appIdWindows,
  }) {
    throw UnimplementedError('init() has not been implemented.');
  }

  Future<void> setOptions(Map<String, dynamic> options) {
    throw UnimplementedError('setOptions() has not been implemented.');
  }

  Future<void> startListening() {
    throw UnimplementedError('startListening() has not been implemented.');
  }

  Future<void> stopListening() {
    throw UnimplementedError('stopListening() has not been implemented.');
  }

  Future<void> cancelListening() {
    throw UnimplementedError('cancelListening() has not been implemented.');
  }

  Future<void> disposeClient() {
    throw UnimplementedError('disposeClient() has not been implemented.');
  }

  Stream<TingpalVoiceEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }
}
