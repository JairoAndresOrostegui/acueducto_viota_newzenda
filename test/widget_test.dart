import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontacueductonewzenda/app/app.dart';

void main() {
  testWidgets('shows validation errors before submitting login', (tester) async {
    await tester.pumpWidget(const AcueductoViotaApp());

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresa el correo de acceso.'), findsOneWidget);
    expect(find.text('Ingresa la clave.'), findsOneWidget);
  });

  testWidgets('allows login with demo credentials', (tester) async {
    await tester.pumpWidget(const AcueductoViotaApp());

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'admin@acueductoviota.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Agua2026*');

    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));

    expect(find.textContaining('Bienvenido,'), findsOneWidget);
    expect(find.text('Panel principal'), findsOneWidget);
  });
}
