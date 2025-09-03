// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/main.dart';

void main() {
  testWidgets('La app muestra el título en la pantalla de autenticación', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Verifica que el título principal aparece
    expect(find.text('Gestor de Contraseñas Pro'), findsOneWidget);

    // Verifica que el icono de seguridad aparece
    expect(find.byIcon(Icons.security), findsOneWidget);
  });
}
