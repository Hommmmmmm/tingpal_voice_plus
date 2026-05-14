// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tingpal_voice_plus/tingpal_voice_plus.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('voice client basic flow', (WidgetTester tester) async {
    final client = TingpalVoiceClient.instance;
    await client.init(appIdAndroid: 'test');
    await client.setOptions(TingpalVoiceOptions(domain: 'iat'));
    await client.start();
    await client.stop();
    await client.cancel();
    await client.dispose();
    expect(true, isTrue);
  });
}
