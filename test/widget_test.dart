import 'package:flutter_test/flutter_test.dart';

import 'package:anant_abhyaas_ultra/main.dart';

void main() {
  testWidgets('security gate renders', (WidgetTester tester) async {
    await tester.pumpWidget(const UltraAdminApp());
    await tester.pump();

    expect(find.text('ANANT ABHYAAS ULTRA'), findsOneWidget);
  });
}