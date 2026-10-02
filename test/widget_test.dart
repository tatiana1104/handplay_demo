import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:handplay_demo/features/tournaments/presentation/screens/player_registration_form.dart';

void main() {
  testWidgets('El club del jugador usa la misma lista que los clubes asociados', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: 'Juan Pérez');
    final documentController = TextEditingController(text: '123456');
    final numberController = TextEditingController(text: '10');
    final positionController = TextEditingController(text: 'Pivot');
    final clubController = TextEditingController(text: 'Atlético');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerRegistrationForm(
            formKey: formKey,
            nameController: nameController,
            documentController: documentController,
            numberController: numberController,
            positionController: positionController,
            clubController: clubController,
            selectedPositions: const ['Pivote'],
            usedNumbers: const <int>{},
            tournamentBranch: 'mixto',
            gender: 'masculino',
            associatedClubs: const ['Atlético', 'Real Caquetá', 'Unión'],
            onGenderChanged: (_) {},
            onSearchExisting: () {},
          ),
        ),
      ),
    );

    expect(find.text('Atlético'), findsOneWidget);
    expect(find.text('Real Caquetá'), findsOneWidget);
    expect(find.text('Unión'), findsOneWidget);
  });

  testWidgets('El formulario del jugador no desborda el ancho en pantallas estrechas', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 800)),
          child: Scaffold(
            body: PlayerRegistrationForm(
              formKey: formKey,
              nameController: TextEditingController(text: 'Juan Pérez'),
              documentController: TextEditingController(text: '123456'),
              numberController: TextEditingController(text: '10'),
              positionController: TextEditingController(text: 'Pivote'),
              clubController: TextEditingController(text: 'Club Deportivo Real Caquetá'),
              selectedPositions: const ['Pivote'],
              usedNumbers: const <int>{},
              tournamentBranch: 'mixto',
              gender: 'masculino',
              associatedClubs: const [
                'Club Deportivo Real Caquetá',
                'Atlético Nacional',
                'Club Unión de la Sierra',
              ],
              onGenderChanged: (_) {},
              onSearchExisting: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
