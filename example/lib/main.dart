import 'package:flutter/material.dart';
import 'package:tingpal_voice_plus/tingpal_voice_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _voiceClient = TingpalVoiceClient.instance;
  String _statusText = 'Idle';
  String _resultText = '';

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    await _voiceClient.init(
      appIdIos: 'your_ios_app_id',
      appIdAndroid: 'your_android_app_id',
      appIdWeb: 'your_web_app_id',
      appIdWindows: 'your_windows_app_id',
    );

    await _voiceClient.setOptions(
      TingpalVoiceOptions(
        domain: 'iat',
        resultType: 'json',
        asrAudioPath: 'audio.pcm',
        extra: const <String, dynamic>{'dwa': 'wpgs'},
      ),
    );

    _voiceClient.events.listen((event) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = event.type.name;
        if (event.type == TingpalVoiceEventType.onResults) {
          _resultText = event.payload['result'] as String? ?? _resultText;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Tingpal Voice Plus Example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $_statusText'),
              const SizedBox(height: 8),
              Text('Result: $_resultText'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => _voiceClient.start(),
                    child: const Text('Start'),
                  ),
                  ElevatedButton(
                    onPressed: () => _voiceClient.stop(),
                    child: const Text('Stop'),
                  ),
                  ElevatedButton(
                    onPressed: () => _voiceClient.cancel(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
