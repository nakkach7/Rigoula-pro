import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dht11_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Vérifier que l'app se lance sans crash
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}