import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/tournament_models.dart';

/// Presenta los campos de inscripción y delega las acciones a la pantalla.
class TeamRegistrationForm extends StatelessWidget {
  /// ES: Crea el formulario con el estado y las acciones de la pantalla.
  /// EN: Creates the form from screen-owned state and action callbacks.
  const TeamRegistrationForm({
    required this.tournament,
    required this.rejectionReason,
    required this.formKey,
    required this.teamController,
    required this.clubController,
    required this.coachController,
    required this.coachDocumentController,
    required this.phoneController,
    required this.emailController,
    required this.clubs,
    required this.officialClubs,
    required this.players,
    required this.category,
    required this.uniformColor,
    required this.accepted,
    required this.saving,
    required this.onAddClub,
    required this.onAddOfficialClub,
    required this.onRemoveClub,
    required this.onLoadExistingCoach,
    required this.onCategoryChanged,
    required this.onUniformColorChanged,
    required this.onAddPlayer,
    required this.onRemovePlayer,
    required this.onAcceptedChanged,
    required this.onSubmit,
  });

  final Tournament tournament;
  final String? rejectionReason;
  final GlobalKey<FormState> formKey;
  final TextEditingController teamController;
  final TextEditingController clubController;
  final TextEditingController coachController;
  final TextEditingController coachDocumentController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final List<String> clubs;
  final List<String> officialClubs;
  final List<Map<String, String>> players;
  final String? category;
  final String uniformColor;
  final bool accepted;
  final bool saving;
  final VoidCallback onAddClub;
  final ValueChanged<String> onAddOfficialClub;
  final ValueChanged<String> onRemoveClub;
  final VoidCallback onLoadExistingCoach;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onUniformColorChanged;
  final VoidCallback onAddPlayer;
  final ValueChanged<int> onRemovePlayer;
  final ValueChanged<bool?> onAcceptedChanged;
  final VoidCallback onSubmit;

  /// ES: Construye el formulario adaptable y sus controles de envío.
  /// EN: Builds the responsive registration form and its submit controls.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = tournament.categories.isEmpty
        ? const ['libre|mixto']
        : tournament.categories;

    return Form(
      key: formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          if (rejectionReason?.trim().isNotEmpty == true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                border: Border.all(color: theme.colorScheme.error),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Cambios solicitados:\n$rejectionReason',
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            '${tournament.name} · Liga de Balonmano del Caquetá',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          Text('Inscribe tu equipo', style: theme.textTheme.headlineSmall),
          Text(
            'Completa la solicitud. El administrador verificará los datos antes de aprobarla.',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Jugadores permitidos: ${tournament.minPlayersPerTeam} a ${tournament.maxPlayersPerTeam}',
            style: theme.textTheme.labelMedium,
          ),
          if (tournament.registrationDeadline != null)
            Text(
              'Inscripciones hasta: ${_formatDate(tournament.registrationDeadline!)}',
              style: theme.textTheme.labelMedium,
            ),
          const SizedBox(height: 16),
          _sectionCard(
            theme,
            icon: Icons.groups_rounded,
            title: 'Datos del equipo',
            children: [
              _field(teamController, 'Nombre del equipo *', 'Halcones FC'),
              Text('Clubes asociados', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (clubs.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: clubs
                      .map(
                        (club) => InputChip(
                          label: Text(club),
                          onDeleted: () => onRemoveClub(club),
                        ),
                      )
                      .toList(),
                ),
              if (officialClubs.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('official-club-picker-${clubs.length}'),
                  decoration: const InputDecoration(
                    labelText: 'Agregar club oficial',
                    prefixIcon: Icon(Icons.verified_outlined),
                  ),
                  items: officialClubs
                      .map(
                        (club) => DropdownMenuItem(
                          value: club,
                          child: Text(club, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (club) {
                    if (club != null) onAddOfficialClub(club);
                  },
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: clubController,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onAddClub(),
                decoration: InputDecoration(
                  labelText: 'Otro club asociado',
                  hintText: 'Escribe un club no incluido en el catálogo',
                  suffixIcon: IconButton(
                    onPressed: onAddClub,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Agregar club',
                  ),
                ),
              ),
            ],
          ),
          _sectionCard(
            theme,
            icon: Icons.tune_rounded,
            title: 'Configuración del torneo',
            children: [
              SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<String>(
                  value: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría *'),
                  items: categories
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value.replaceAll('|', ' · '),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<String>(
                  value: uniformColor,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Color del uniforme *',
                  ),
                  items:
                      const [
                            'Verde',
                            'Azul',
                            'Rojo',
                            'Naranja',
                            'Amarillo',
                            'Blanco',
                            'Negro',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: onUniformColorChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 8),
          _sectionCard(
            theme,
            icon: Icons.person_rounded,
            title: 'Datos del entrenador',
            children: [
              _field(
                coachController,
                'Nombre del entrenador *',
                'Carlos Herrera',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: coachDocumentController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Documento del entrenador *',
                  hintText: '1006514021',
                  prefixIcon: const Icon(Icons.credit_card_outlined),
                  suffixIcon: IconButton(
                    onPressed: onLoadExistingCoach,
                    icon: const Icon(Icons.search),
                    tooltip: 'Buscar datos',
                  ),
                ),
                onEditingComplete: onLoadExistingCoach,
                onFieldSubmitted: (_) => onLoadExistingCoach(),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe el documento'
                    : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      phoneController,
                      'Teléfono *',
                      '300 123 4567',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      emailController,
                      'Correo *',
                      'equipo@correo.com',
                      email: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Jugadores inscritos (${players.length})',
                style: theme.textTheme.titleSmall,
              ),
              TextButton.icon(
                onPressed: onAddPlayer,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
          ...players.asMap().entries.map(
            (entry) => ListTile(
              dense: true,
              leading: Text('${entry.key + 1}'),
              title: Text(entry.value['name'] ?? ''),
              subtitle: Text(
                '${entry.value['position']} · #${entry.value['number']} · Doc. ${entry.value['document']}\n'
                '${entry.value['club']!.isEmpty ? 'Club independiente' : entry.value['club']}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => onRemovePlayer(entry.key),
              ),
            ),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: accepted,
            onChanged: onAcceptedChanged,
            title: const Text(
              'Acepto el reglamento y confirmo que la información es correcta.',
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : onSubmit,
                icon: const Icon(Icons.send_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    saving ? 'Enviando...' : 'Enviar solicitud de inscripción',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ES: Da formato a una fecha del torneo para mostrarla.
  /// EN: Formats a tournament date for display in the form.
  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// ES: Agrupa campos relacionados con el estilo común de sección.
  /// EN: Groups related fields using the shared section styling.
  Widget _sectionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  /// ES: Crea un campo con validación común de requerido y correo.
  /// EN: Builds a text input with required-field and email validation.
  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool required = true,
    bool email = false,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) {
        if (!required && (value == null || value.trim().isEmpty)) return null;
        if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
        if (email &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
          return 'Escribe un correo válido';
        }
        return null;
      },
    ),
  );
}
