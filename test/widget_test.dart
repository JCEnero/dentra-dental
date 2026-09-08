import 'package:flutter_test/flutter_test.dart';
import 'package:dentra_mobile/app/app.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const DentraApp());
    expect(find.byType(DentraApp), findsOneWidget);
  });
}
