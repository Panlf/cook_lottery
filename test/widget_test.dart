import 'package:flutter_test/flutter_test.dart';
import 'package:cook_lottery/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const CookLotteryApp());
    expect(find.text('我的菜谱'), findsOneWidget);
  });
}
