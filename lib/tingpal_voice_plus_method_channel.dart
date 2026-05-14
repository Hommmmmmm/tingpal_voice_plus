import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tingpal_voice_plus_platform_interface.dart';

class TingpalVoiceMethodChannelPlatform extends TingpalVoicePlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('tingpal_voice_plus');

  @visibleForTesting
  final EventChannel eventChannel = const EventChannel(
    'tingpal_voice_plus/events',
  );

  late final Stream<TingpalVoiceEvent> _eventStream = eventChannel
      .receiveBroadcastStream()
      .map((dynamic raw) {
        final payload = Map<String, dynamic>.from(raw as Map);
        final typeName = payload.remove('event') as String? ?? 'onCancel';
        return TingpalVoiceEvent(type: _mapType(typeName), payload: payload);
      });

  TingpalVoiceEventType _mapType(String typeName) {
    switch (typeName) {
      case 'onBeginOfSpeech':
        return TingpalVoiceEventType.onBeginOfSpeech;
      case 'onEndOfSpeech':
        return TingpalVoiceEventType.onEndOfSpeech;
      case 'onResults':
        return TingpalVoiceEventType.onResults;
      case 'onCompleted':
        return TingpalVoiceEventType.onCompleted;
      case 'onVolumeChanged':
        return TingpalVoiceEventType.onVolumeChanged;
      case 'onCancel':
        return TingpalVoiceEventType.onCancel;
      default:
        return TingpalVoiceEventType.onCancel;
    }
  }

  @override
  Future<void> init({
    String? appIdIos,
    String? appIdAndroid,
    String? appIdWeb,
    String? appIdWindows,
  }) async {
    await methodChannel.invokeMethod<void>('init', <String, dynamic>{
      'appIdIos': appIdIos,
      'appIdAndroid': appIdAndroid,
      'appIdWeb': appIdWeb,
      'appIdWindows': appIdWindows,
    });
  }

  @override
  Future<void> setOptions(Map<String, dynamic> options) async {
    await methodChannel.invokeMethod<void>('setOptions', options);
  }

  @override
  Future<void> startListening() async {
    await methodChannel.invokeMethod<void>('startListening');
  }

  @override
  Future<void> stopListening() async {
    await methodChannel.invokeMethod<void>('stopListening');
  }

  @override
  Future<void> cancelListening() async {
    await methodChannel.invokeMethod<void>('cancelListening');
  }

  @override
  Future<void> disposeClient() async {
    await methodChannel.invokeMethod<void>('disposeClient');
  }

  @override
  Stream<TingpalVoiceEvent> get events {
    return _eventStream;
  }
}
