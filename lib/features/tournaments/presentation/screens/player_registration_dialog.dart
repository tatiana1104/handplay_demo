import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'player_registration_form.dart';

/// ES: Administra el alta de un jugador y devuelve sus datos al equipo.
/// EN: Handles player entry and returns the player's details to the team form.
class PlayerRegistrationDialog extends StatefulWidget {
  /// ES: Crea el diálogo con dorsales ocupados y rama del torneo.
  /// EN: Creates the dialog with used shirt numbers and tournament branch.
  const PlayerRegistrationDialog({
    required this.usedNumbers,
    required this.tournamentBranch,
  });

  final Set<int> usedNumbers;
  final String tournamentBranch;

  /// ES: Crea el estado que gestiona datos y validación del jugador.
  /// EN: Creates the state that manages player data and validation.
  @override
  State<PlayerRegistrationDialog> createState() =>
      _PlayerRegistrationDialogState();
}

class _PlayerRegistrationDialogState extends State<PlayerRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _document = TextEditingController();
  final _number = TextEditingController();
  final _position = TextEditingController();
  final _selectedPositions = <String>[];
  final _club = TextEditingController();
  String? _gender;

  /// ES: Libera los controladores del formulario de jugador.
  /// EN: Releases the player form controllers.
  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _number.dispose();
    _position.dispose();
    _club.dispose();
    super.dispose();
  }

  /// ES: Busca el jugador por documento y completa los campos disponibles.
  /// EN: Looks up the player by identity document and fills available fields.
  Future<void> _loadExistingPlayer() async {
    final existing = await _findProfile(_document.text.trim());
    if (!mounted) return;
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró un perfil con ese documento.'),
        ),
      );
      return;
    }
    setState(() {
      final name = _firstValue(existing, [
        'name',
        'displayName',
        'nombre',
        'fullName',
      ]);
      final playerData = existing['player'] is Map
          ? Map<String, dynamic>.from(existing['player'] as Map)
          : <String, dynamic>{};
      final number = _firstValue(
        {...existing, ...playerData},
        [
          'number',
          'shirtNumber',
          'shirt_number',
          'numeroCamiseta',
          'jerseyNumber',
          'numero',
          'camiseta',
          'numero_de_camiseta',
        ],
      );
      final position = _firstValue(
        {...existing, ...playerData},
        [
          'position',
          'player_position',
          'playerPosition',
          'posicion',
          'posicionJugador',
          'positionName',
        ],
      );
      final gender = _firstValue(existing, ['gender', 'genero', 'sex', 'sexo']);
      final club = _firstValue(existing, [
        'club',
        'clubName',
        'club al que pertenece',
        'club_name',
        'clubes',
      ]);
      if (name != null) _name.text = name;
      if (number != null) _number.text = number;
      if (position != null && _position.text.trim().isEmpty) {
        final loadedPositions = position
            .split(RegExp(r'[,/|]'))
            .map((item) => _normalizePosition(item))
            .whereType<String>()
            .toSet()
            .toList();
        _selectedPositions
          ..clear()
          ..addAll(loadedPositions.take(2));
        _position.text = _selectedPositions.join(', ');
      }
      if (gender != null) _gender = _normalizeGender(gender);
      if (club != null) _club.text = club;
      if (number == null || position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Perfil encontrado. Completa los datos deportivos faltantes.',
            ),
          ),
        );
      }
    });
  }

  /// ES: Valida los datos y devuelve el jugador a la pantalla del equipo.
  /// EN: Validates the data and returns the player to the team screen.
  Future<void> _submit() async {
    if (_number.text.trim().isEmpty || _position.text.trim().isEmpty) {
      await _loadExistingPlayer();
    }
    if (!_formKey.currentState!.validate()) return;
    final number = int.parse(_number.text.trim());
    if (widget.usedNumbers.contains(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese número de camiseta ya está asignado.'),
        ),
      );
      return;
    }
    final document = _document.text.trim();
    final existing = await _findProfile(document);
    final selectedGender =
        (_gender ??
                _firstValue(existing ?? {}, [
                  'gender',
                  'genero',
                  'sex',
                  'sexo',
                ]) ??
                '')
            .trim();
    if (selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El género del jugador es obligatorio para calcular las tablas de goleadores.',
          ),
        ),
      );
      return;
    }
    final playerResult = <String, String>{
      'name': _name.text.trim().isNotEmpty
          ? _name.text.trim()
          : (existing?['name']?.toString() ?? ''),
      'document': document,
      'number': _number.text.trim().isNotEmpty
          ? _number.text.trim()
          : (_firstValue(existing ?? {}, [
                  'number',
                  'shirtNumber',
                  'numeroCamiseta',
                  'jerseyNumber',
                ]) ??
                ''),
      'position': _position.text.trim().isNotEmpty
          ? _position.text.trim()
          : (_firstValue(existing ?? {}, ['position', 'posicion']) ?? ''),
      'gender':
          _gender ??
          _firstValue(existing ?? {}, ['gender', 'genero', 'sex', 'sexo']) ??
          '',
      'club': _club.text.trim().isNotEmpty
          ? _club.text.trim()
          : (_firstValue(existing ?? {}, [
                  'club',
                  'clubName',
                  'club al que pertenece',
                  'club_name',
                ]) ??
                ''),
    };
    Navigator.of(context).pop<Map<String, String>>(playerResult);
  }

  /// ES: Traduce alias de posición a una posición admitida por la app.
  /// EN: Maps position aliases to a position supported by the app.
  String? _normalizePosition(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    const aliases = <String, String>{
      'portero': 'Portero',
      'arquero': 'Portero',
      'guardameta': 'Portero',
      'extremo': 'Extremo',
      'ala': 'Extremo',
      'lateral': 'Lateral',
      'defensa lateral': 'Lateral',
      'central': 'Central',
      'defensa central': 'Central',
      'defensor': 'Central',
      'defensa': 'Central',
      'pivote': 'Pivote',
      'pivot': 'Pivote',
      'medio': 'Pivote',
      'mediocampista': 'Pivote',
      'volante': 'Pivote',
    };
    if (aliases.containsKey(normalized)) return aliases[normalized];
    for (final entry in aliases.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return playerPositions
            .firstWhere(
              (item) => item.toLowerCase() == normalized,
              orElse: () => '',
            )
            .isEmpty
        ? null
        : playerPositions.firstWhere(
            (item) => item.toLowerCase() == normalized,
          );
  }

  /// ES: Normaliza el género almacenado a femenino o masculino.
  /// EN: Normalizes stored gender values to female or male.
  String _normalizeGender(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('f') || normalized == 'female'
        ? 'femenino'
        : 'masculino';
  }

  /// ES: Devuelve el primer campo no vacío entre las claves indicadas.
  /// EN: Returns the first non-empty value among the supplied keys.
  String? _firstValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// ES: Busca perfiles por documento en los directorios compatibles.
  /// EN: Searches supported profile directories by identity document.
  Future<Map<String, dynamic>?> _findProfile(String document) async {
    final firestore = FirebaseFirestore.instance;
    final merged = <String, dynamic>{};
    var found = false;
    for (final collection in [
      firestore.collection('profile_directory'),
      firestore.collection('users'),
      firestore.collection('referees'),
    ]) {
      try {
        final documentValues = <dynamic>{
          document,
          int.tryParse(document),
        }.where((value) => value != null).toList();
        final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
          for (final field in [
            'document',
            'documentNumber',
            'numeroDocumento',
            'numero_documento',
            'cedula',
          ])
            for (final value in documentValues)
              collection.where(field, isEqualTo: value).limit(5).get(),
        ];
        for (final snapshot in await Future.wait(queries)) {
          if (snapshot.docs.isEmpty) continue;
          found = true;
          for (final entry in snapshot.docs.first.data().entries) {
            final value = entry.value?.toString().trim();
            if (value != null && value.isNotEmpty)
              merged[entry.key] = entry.value;
          }
        }
      } on FirebaseException {
        continue;
      }
    }
    return found ? merged : null;
  }

  /// ES: Conecta el formulario de jugador con sus acciones de diálogo.
  /// EN: Connects the player form to the dialog's actions.
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Agregar jugador'),
      leading: const BackButton(),
    ),
    body: PlayerRegistrationForm(
      formKey: _formKey,
      nameController: _name,
      documentController: _document,
      numberController: _number,
      positionController: _position,
      clubController: _club,
      selectedPositions: _selectedPositions,
      usedNumbers: widget.usedNumbers,
      tournamentBranch: widget.tournamentBranch,
      gender: _gender,
      onGenderChanged: (value) => setState(() => _gender = value),
      onSearchExisting: _loadExistingPlayer,
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Agregar jugador'),
            ),
          ),
        ],
      ),
    ),
  );
}
