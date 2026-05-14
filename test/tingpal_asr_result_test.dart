import 'package:flutter_test/flutter_test.dart';
import 'package:tingpal_voice_plus/tingpal_voice_plus.dart';

void main() {
  test('TingpalAsrJsonResult parses plain result text', () {
    const rawJson =
        '{"sn":1,"ls":true,"bg":0,"ed":0,"ws":[{"cw":[{"w":"今天"}]},{"cw":[{"w":"天气"}]}]}';

    final result = TingpalAsrJsonResult.fromJsonString(rawJson);

    expect(result.resultText(), '今天天气');
    expect(result.sn, 1);
    expect(result.ls, true);
  });

  test('TingpalAsrResultAssembler merges dynamic correction chunks', () {
    const first = '{"sn":1,"ls":false,"pgs":"apd","ws":[{"cw":[{"w":"今天"}]}]}';
    const second = '{"sn":2,"ls":true,"pgs":"apd","ws":[{"cw":[{"w":"不错"}]}]}';

    final assembler = TingpalAsrResultAssembler();

    final t1 = assembler.addJsonChunk(first);
    final t2 = assembler.addJsonChunk(second);

    expect(t1, '今天');
    expect(t2, '今天不错');
    expect(assembler.currentText(), '今天不错');
  });
}
