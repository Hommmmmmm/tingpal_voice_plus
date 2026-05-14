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
  TingpalAsrJsonResult({
    this.sn,
    this.ls,
    this.bg,
    this.ed,
    this.pgs,
    this.rg,
    this.ws,
  });

  factory TingpalAsrJsonResult.fromJsonString(String rawJson) {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    return TingpalAsrJsonResult(
      sn: (json['sn'] as num?)?.toInt(),
      ls: json['ls'] as bool?,
      bg: (json['bg'] as num?)?.toInt(),
      ed: (json['ed'] as num?)?.toInt(),
      pgs: json['pgs'] as String?,
      rg: (json['rg'] as List?)?.toList(),
      ws: (json['ws'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  int? sn;
  bool? ls;
  int? bg;
  int? ed;
  String? pgs;
  List<dynamic>? rg;
  List<Map<String, dynamic>>? ws;

  void merge(TingpalAsrJsonResult incoming) {
    sn = incoming.sn;
    ls = incoming.ls;
    bg = incoming.bg;
    ed = incoming.ed;
    rg = incoming.rg;

    if (incoming.pgs == 'apd') {
      ws ??= <Map<String, dynamic>>[];
      ws!.addAll(incoming.ws ?? const <Map<String, dynamic>>[]);
    } else {
      ws = incoming.ws;
    }
    pgs = incoming.pgs;
  }

  String resultText() {
    final segments = ws ?? const <Map<String, dynamic>>[];
    return segments.map((segment) {
      final candidates = (segment['cw'] as List?) ?? const [];
      if (candidates.isEmpty) {
        return '';
      }
      final first = Map<String, dynamic>.from(candidates.first as Map);
      return first['w'] as String? ?? '';
    }).join();
  }
}

class TingpalAsrResultAssembler {
  TingpalAsrJsonResult? _merged;

  void reset() {
    _merged = null;
  }

  String addJsonChunk(String rawJson) {
    final incoming = TingpalAsrJsonResult.fromJsonString(rawJson);
    if (_merged == null) {
      _merged = incoming;
    } else {
      _merged!.merge(incoming);
    }
    return _merged!.resultText();
  }

  String currentText() {
    return _merged?.resultText() ?? '';
  }
}
