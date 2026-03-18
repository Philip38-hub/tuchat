import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tuchat/screens/home_screen.dart';

void main() {
  testWidgets('Home screen renders welcome copy', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(find.text('Welcome to TuChat!'), findsOneWidget);
    expect(find.text('Your secure messaging app'), findsOneWidget);
  });
}
