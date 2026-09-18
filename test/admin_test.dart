import 'package:felipe_ambrozini/telas/admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fora da web mostra o aviso, nunca o painel', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaAdmin()));
    expect(find.text('Só na web'), findsOneWidget);
    expect(find.text('Recursos'), findsNothing);
    expect(find.text('E-mails com conversas'), findsNothing);
  });
}
