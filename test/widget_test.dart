// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yolo_demo/main.dart';

void main() {
  testWidgets('YOLO Demo app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(YOLODemo());

    // Verify that our app loads with the correct title
    expect(find.text('YOLO Demo con Tracking Avanzado'), findsOneWidget);

    // Verify that performance metrics are shown
    expect(find.text('FPS: 0.0'), findsOneWidget);

    // Verify that the status section is present
    expect(find.text('Estado del Tracking'), findsOneWidget);
  });
}
