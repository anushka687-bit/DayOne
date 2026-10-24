// Basic smoke test: the app should build and show the generic Welcome
// screen before any profile exists, with no network and no crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayone/main.dart';

void main() {
  testWidgets('DayOne starts on the generic Welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DayOneApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('DayOne'), findsOneWidget);
    expect(find.text('Get started (60 seconds)'), findsOneWidget);
  });
}
