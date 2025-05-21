// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:little_lambs/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LittleLambs());

    // Verify that basic elements of our app appear
    expect(find.text('Church Children Attendance'), findsOneWidget);
    expect(find.text('Today is'), findsOneWidget);

    // Look for the main buttons
    expect(find.text('Take Today\'s Attendance'), findsOneWidget);
    expect(find.text('View Reports'), findsOneWidget);
    expect(find.text('Manage Children'), findsOneWidget);
  });
}
