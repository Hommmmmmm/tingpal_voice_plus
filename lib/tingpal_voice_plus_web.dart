// ignore: avoid_web_libraries_in_flutter
import 'dart:async';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'tingpal_voice_plus_platform_interface.dart';

class TingpalVoicePlusWeb extends TingpalVoicePlatform {
  TingpalVoicePlusWeb();

  final StreamController<TingpalVoiceEvent> _eventController =
      StreamController<TingpalVoiceEvent>.broadcast();
  String? _appIdWeb;
  Map<String, dynamic> _voiceOptions = <String, dynamic>{};

  static void registerWith(Registrar registrar) {
    TingpalVoicePlatform.instance = TingpalVoicePlusWeb();
  }

  @override
  Future<void> init({
    String? appIdIos,
    String? appIdAndroid,
    String? appIdWeb,
    String? appIdWindows,
  }) async {
    _appIdWeb = appIdWeb;
  }

  @override
  Future<void> setOptions(Map<String, dynamic> options) async {
    _voiceOptions = options;
  }

  @override
  Future<void> startListening() async {
    _eventController.add(
      const TingpalVoiceEvent(
        type: TingpalVoiceEventType.onBeginOfSpeech,
        payload: <String, dynamic>{'platform': 'web'},
      ),
    );
    _eventController.add(
      TingpalVoiceEvent(
        type: TingpalVoiceEventType.onResults,
        payload: <String, dynamic>{
          'result': '[web] recognizing...',
          'isLast': false,
          'appIdWeb': _appIdWeb ?? '',
        },
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    _eventController.add(
      const TingpalVoiceEvent(
        type: TingpalVoiceEventType.onEndOfSpeech,
        payload: <String, dynamic>{},
      ),
    );
    _eventController.add(
      TingpalVoiceEvent(
        type: TingpalVoiceEventType.onCompleted,
        payload: <String, dynamic>{
          'error': <String, dynamic>{},
          'audioFilePath': _voiceOptions['asr_audio_path']?.toString() ?? '',
        },
      ),
    );
  }

  @override
  Future<void> cancelListening() async {
    _eventController.add(
      const TingpalVoiceEvent(
        type: TingpalVoiceEventType.onCancel,
        payload: <String, dynamic>{},
      ),
    );
  }

  @override
  Future<void> disposeClient() async {
    _appIdWeb = null;
    _voiceOptions = <String, dynamic>{};
    await _eventController.close();
  }

  @override
  Stream<TingpalVoiceEvent> get events {
    return _eventController.stream;
  }
}
