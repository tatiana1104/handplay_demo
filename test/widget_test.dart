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
}
