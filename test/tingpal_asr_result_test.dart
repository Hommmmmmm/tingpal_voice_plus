import 'package:flutter_test/flutter_test.dart';
import 'package:tingpal_voice_plus/tingpal_voice_plus.dart';

void main() {
  test('TingpalAsrJsonResult parses plain result text', () {
    const rawJson =
        '{"sn":1,"ls":true,"bg":0,"ed":0,"ws":[{"cw":[{"w":"今天"}]},{"cw":[{"w":"天气"}]}]}';

    final result = TingpalAsrJsonResult.stringFromJson(rawJson);

    expect(result, '今天天气');
  });
}
