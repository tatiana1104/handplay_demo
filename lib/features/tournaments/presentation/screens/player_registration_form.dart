import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ES: Posiciones de balonmano que se pueden asignar a un jugador.
/// EN: Handball positions that can be assigned to a player.
const playerPositions = ['Portero', 'Extremo', 'Lateral', 'Central', 'Pivote'];

/// ES: Construye los campos y validaciones visuales del jugador.
/// EN: Builds the player's input fields and visual validation.
class PlayerRegistrationForm extends StatelessWidget {
  /// ES: Crea el formulario con valores y acciones controlados por el diálogo.
  /// EN: Creates the form with values and actions controlled by the dialog.
  const PlayerRegistrationForm({
    required this.formKey,
    required this.nameController,
    required this.documentController,
    required this.numberController,
    required this.positionController,
    required this.clubController,
    required this.selectedPositions,
    required this.usedNumbers,
    required this.tournamentBranch,
    required this.gender,
    required this.onGenderChanged,
    required this.onSearchExisting,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController documentController;
  final TextEditingController numberController;
  final TextEditingController positionController;
  final TextEditingController clubController;
  final List<String> selectedPositions;
  final Set<int> usedNumbers;
  final String tournamentBranch;
  final String? gender;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onSearchExisting;

  /// ES: Dibuja los datos personales y deportivos que se pueden registrar.
  /// EN: Renders the personal and sports details collected for a player.
  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Datos del jugador',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo *',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe el nombre completo'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: documentController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Número de documento *',
              prefixIcon: const Icon(Icons.credit_card_outlined),
              suffixIcon: IconButton(
                onPressed: onSearchExisting,
                icon: const Icon(Icons.search),
                tooltip: 'Buscar datos',
              ),
            ),
            onEditingComplete: onSearchExisting,
            onFieldSubmitted: (_) => onSearchExisting(),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe el documento'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: numberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Número de camiseta *',
              hintText: '1 al 99',
            ),
            validator: (value) {
              final number = int.tryParse(value?.trim() ?? '');
              if (number == null || number < 1 || number > 99) {
                return 'Usa un número entre 1 y 99';
              }
              if (usedNumbers.contains(number)) {
                return 'Este número ya está asignado';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          FormField<List<String>>(
            initialValue: selectedPositions,
            validator: (_) =>
                selectedPositions.isEmpty ? 'Selecciona una posición' : null,
            builder: (field) => InputDecorator(
              decoration: InputDecoration(
                labelText: 'Posición * (máximo 2)',
                prefixIcon: const Icon(Icons.sports_handball_outlined),
                errorText: field.errorText,
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: playerPositions
                    .map(
                      (position) => FilterChip(
                        label: Text(position),
                        selected: selectedPositions.contains(position),
                        onSelected: (selected) {
                          if (selected && selectedPositions.length < 2) {
                            selectedPositions.add(position);
                          }
                          if (!selected) selectedPositions.remove(position);
                          positionController.text = selectedPositions.join(
                            ', ',
                          );
                          field.didChange(selectedPositions);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: gender,
            decoration: const InputDecoration(
              labelText: 'Género *',
              prefixIcon: Icon(Icons.wc_outlined),
            ),
            validator: (value) => value == null || value.isEmpty
                ? 'Selecciona el género del jugador'
                : null,
            items:
                (tournamentBranch == 'masculino'
                        ? const ['masculino']
                        : tournamentBranch == 'femenino'
                        ? const ['femenino']
                        : const ['masculino', 'femenino'])
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == 'masculino' ? 'Masculino' : 'Femenino',
                        ),
                      ),
                    )
                    .toList(),
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: clubController,
            decoration: const InputDecoration(
              labelText: 'Club al que pertenece',
              prefixIcon: Icon(Icons.shield_outlined),
            ),
          ),
        ],
      ),
    ),
  );
}
