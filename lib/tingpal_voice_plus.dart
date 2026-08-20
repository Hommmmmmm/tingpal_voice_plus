import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'tingpal_voice_plus_platform_interface.dart';

export 'tingpal_voice_plus_platform_interface.dart'
    show TingpalVoiceEvent, TingpalVoiceEventType;

class TingpalVoiceClient {
  TingpalVoiceClient._();

  static final TingpalVoiceClient instance = TingpalVoiceClient._();

  Future<void> init({
    String? appIdIos,
    String? appIdAndroid,
    String? appIdWeb,
    String? appIdWindows,
  }) {
    return TingpalVoicePlatform.instance.init(
      appIdIos: appIdIos,
      appIdAndroid: appIdAndroid,
      appIdWeb: appIdWeb,
      appIdWindows: appIdWindows,
    );
  }

  Future<void> setOptions(TingpalVoiceOptions options) {
    return TingpalVoicePlatform.instance.setOptions(options.toMap());
  }

  Future<void> start({TingpalVoiceCallbacks? callbacks}) async {
    if (callbacks != null) {
      _bindCallbacks(callbacks);
    }
    await TingpalVoicePlatform.instance.startListening();
  }

  Future<void> stop() {
    return TingpalVoicePlatform.instance.stopListening();
  }

  Future<void> cancel() {
    return TingpalVoicePlatform.instance.cancelListening();
  }

  Future<void> dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    return TingpalVoicePlatform.instance.disposeClient();
  }

  Stream<TingpalVoiceEvent> get events => TingpalVoicePlatform.instance.events;

  StreamSubscription<TingpalVoiceEvent>? _eventSubscription;

  void _bindCallbacks(TingpalVoiceCallbacks callbacks) {
    _eventSubscription?.cancel();
    _eventSubscription = events.listen((event) {
      switch (event.type) {
        case TingpalVoiceEventType.onBeginOfSpeech:
          callbacks.onBeginOfSpeech?.call();
          break;
        case TingpalVoiceEventType.onEndOfSpeech:
          callbacks.onEndOfSpeech?.call();
          break;
        case TingpalVoiceEventType.onResults:
          callbacks.onResults?.call(
            event.payload['result'] as String? ?? '',
            event.payload['isLast'] == true,
          );
          break;
        case TingpalVoiceEventType.onCompleted:
          callbacks.onCompleted?.call(
            Map<String, dynamic>.from(
              (event.payload['error'] as Map?) ?? <String, dynamic>{},
            ),
            event.payload['audioFilePath'] as String? ?? '',
          );
          break;
        case TingpalVoiceEventType.onVolumeChanged:
          callbacks.onVolumeChanged?.call(
            (event.payload['volume'] as num?)?.toInt() ?? 0,
          );
          break;
        case TingpalVoiceEventType.onCancel:
          callbacks.onCancel?.call();
          break;
      }
    });
  }
}

class TingpalVoiceCallbacks {
  TingpalVoiceCallbacks({
    this.onCancel,
    this.onEndOfSpeech,
    this.onBeginOfSpeech,
    this.onCompleted,
    this.onResults,
    this.onVolumeChanged,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onEndOfSpeech;
  final VoidCallback? onBeginOfSpeech;
  final void Function(Map<String, dynamic> error, String audioFilePath)?
  onCompleted;
  final void Function(String result, bool isLast)? onResults;
  final void Function(int volume)? onVolumeChanged;
}

class TingpalVoiceOptions {
  TingpalVoiceOptions({
    this.domain,
    this.resultType,
    this.asrAudioPath,
    this.extra = const <String, dynamic>{},
  });

  final String? domain;
  final String? resultType;
  final String? asrAudioPath;
  final Map<String, dynamic> extra;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'domain': domain,
      'result_type': resultType,
      'asr_audio_path': asrAudioPath,
      ...extra,
    }..removeWhere((_, value) => value == null);
  }
}

class TingpalAsrJsonResult {
  TingpalAsrJsonResult._();

  /// iOS ISRDataHelper.stringFromJson 的 Dart 等价实现：
  /// 遍历 ws 中每个词的所有 cw 候选，拼接 w 字段。
  static String stringFromJson(String rawJson) {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    final wordArray = json['ws'] as List?;
    if (wordArray == null || wordArray.isEmpty) return '';
    final buffer = StringBuffer();
    for (final wsItem in wordArray) {
      final wsDic = wsItem as Map<String, dynamic>;
      final cwArray = wsDic['cw'] as List?;
      if (cwArray == null) continue;
      for (final cwItem in cwArray) {
        final wDic = cwItem as Map<String, dynamic>;
        buffer.write(wDic['w'] as String? ?? '');
      }
    }
    return buffer.toString();
  }
}
