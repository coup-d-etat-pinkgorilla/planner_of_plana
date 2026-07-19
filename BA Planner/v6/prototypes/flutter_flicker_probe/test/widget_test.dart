import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_flicker_probe/main.dart';

void main() {
  testWidgets('home and settings probe surfaces are reachable', (tester) async {
    await tester.pumpWidget(const FlickerProbeApp());

    expect(find.text('HOME PNG HOVER TEST'), findsOneWidget);
    expect(find.text('학생부 확인'), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pump();

    expect(find.text('검증 설정'), findsOneWidget);
    expect(find.text('카드별 RepaintBoundary'), findsOneWidget);
  });
}
