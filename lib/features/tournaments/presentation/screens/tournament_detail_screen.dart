import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

import '../../../../core/routing/route_names.dart';
import '../../domain/models/tournament_models.dart';
import '../../data/tournament_phase_service.dart';
import '../../../teams/domain/team_stats_calculator.dart' show formatCategory;
import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../../shared/widgets/compact_action_card.dart';
import '../../../../shared/widgets/info_badge.dart';
import '../../../../shared/widgets/section_title_action.dart';
import 'team_registration_screen.dart';
import 'approved_teams_screen.dart';
import 'tournament_match_form_screen.dart';
import '../widgets/tournament_match_section.dart';
import '../widgets/tournament_standings_section.dart';
import '../widgets/tournament_highlights_section.dart';

/// Resumen responsive del torneo seleccionado.
/// El ListView permite que la información crezca sin desbordarse.
/// EN: Responsive overview of the selected tournament and its live information.
/// ES: Resume el torneo seleccionado con información adaptable y en vivo.

/// ES: Normaliza nombres de roles para comparar variantes con y sin tilde.
/// EN: Normalizes role names so accented and unaccented variants match.
String _normalizeRole(String role) => role
    .trim()
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

class TournamentDetailScreen extends StatelessWidget {
  /// ES: Crea la vista de detalle del torneo.
  /// EN: Creates the tournament detail view.
  const TournamentDetailScreen({required this.tournament, super.key});

  final Tournament tournament;

  /// ES: Calcula permisos y compone los datos y acciones del torneo.
  /// EN: Resolves permissions and builds tournament data and actions.
  @override
  Widget build(BuildContext context) {
    final status = tournament.status.toLowerCase();
    final registrationClosed =
        tournament.registrationDeadline != null &&
        DateTime.now().isAfter(tournament.registrationDeadline!);
    final colors = Theme.of(context).colorScheme;
    final authState = context.watch<AuthBloc>().state;
    final roles = authState is AuthAuthenticated
        ? authState.user.roles.map(_normalizeRole).toSet()
        : const <String>{};
    // Jugador o entrenador tienen prioridad y pueden inscribir equipo,
    // aunque también tengan el rol de árbitro.
    final hasPlayerOrCoachRole = roles.any(
      (role) =>
          role == 'jugador' ||
          role == 'player' ||
          role == 'entrenador' ||
          role == 'coach',
    );
    final hasBlockedRole = roles.any(
      (role) =>
          role == 'admin' ||
          role == 'admin_liga' ||
          role == 'administrador' ||
          role == 'arbitro',
    );
    final canRegisterTeam = hasPlayerOrCoachRole || !hasBlockedRole;
    final isTournamentAdmin =
        FirebaseAuth.instance.currentUser?.uid == tournament.adminId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a torneos',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.home),
        ),
        title: Text(
          tournament.name.isEmpty ? 'Detalle del torneo' : tournament.name,
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(selectedIndex: 0),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'LIGA DE BALONMANO DEL CAQUETÁ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tournament.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Seguimiento en tiempo real del torneo',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TournamentLiveStatus(
                tournament: tournament,
                fallbackStatus: tournament.effectiveStatus,
              ),
              InfoBadge(
                label: _formatLabel(tournament.format),
                color: colors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatsGrid(tournament: tournament),
          const SizedBox(height: 18),
          SectionTitleAction(
            title: 'Tabla de posiciones',
            action: 'Ver completa',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TournamentStandingsFullScreen(tournament: tournament),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TournamentStandingsSummary(tournament: tournament),
          const SizedBox(height: 18),
          const SectionTitleAction(title: 'Destacados'),
          const SizedBox(height: 8),
          TournamentHighlightsSection(tournament: tournament),
          const SizedBox(height: 18),
          const SectionTitleAction(title: 'Información del torneo'),
          const SizedBox(height: 8),
          _DetailsCard(tournament: tournament),
          const SizedBox(height: 18),
          if (isTournamentAdmin &&
              tournament.registrationDeadline != null &&
              registrationClosed)
            OutlinedButton.icon(
              onPressed: () async {
                await TournamentPhaseService().assignPhaseOne(tournament);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fase 1 asignada y jornadas generadas.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                tournament.format == 'por_grupos'
                    ? 'Asignar grupos y generar fase 1'
                    : 'Generar jornadas fase 1',
              ),
            ),
          if (tournament.publicRegistration && canRegisterTeam)
            FilledButton.icon(
              onPressed: registrationClosed
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TeamRegistrationScreen(tournament: tournament),
                      ),
                    ),
              icon: Icon(
                registrationClosed
                    ? Icons.lock_clock_outlined
                    : Icons.group_add_rounded,
              ),
              label: Text(
                registrationClosed
                    ? 'Inscripciones cerradas'
                    : 'Inscribir mi equipo',
              ),
            ),
          if (registrationClosed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'La fecha límite de inscripción ya pasó. Las solicitudes enviadas todavía pueden modificarse.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// ES: Muestra conteos de equipos y jornadas obtenidos en vivo.
/// EN: Shows live counts of approved teams and match rounds.
class _StatsGrid extends StatelessWidget {
  /// ES: Crea la cuadrícula de métricas del torneo.
  /// EN: Creates the tournament metrics grid.
  const _StatsGrid({required this.tournament});
  final Tournament tournament;

  /// ES: Suscribe los conteos y permite abrir sus listas detalladas.
  /// EN: Subscribes to counts and opens their detailed lists.
  @override
  Widget build(BuildContext context) {
    final approvedTeams = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id)
        .collection('registrations')
        .where('status', isEqualTo: 'approved')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: approvedTeams,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final hasError = snapshot.hasError;
        return GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 104,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            CompactActionCard(
              icon: Icons.groups_2_outlined,
              title: 'Equipos',
              subtitle: 'Total aprobados',
              value: hasError ? '—' : '$count',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ApprovedTeamsScreen(tournament: tournament),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .doc(tournament.id)
                  .collection('matches')
                  .snapshots(),
              builder: (context, matchesSnapshot) {
                final matches = matchesSnapshot.data?.docs ?? const [];
                final roundValues = matches.map((doc) {
                  final raw = doc.data()['jornada'] ?? doc.data()['round'] ?? 1;
                  return _safeInt(raw, fallback: 0);
                }).toList();
                final rounds = roundValues.toSet().length;
                final currentRound = roundValues.isEmpty
                    ? 0
                    : roundValues.reduce((a, b) => a > b ? a : b);
                return CompactActionCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'Jornada',
                  subtitle: 'Partidos activos',
                  value: rounds == 0 ? '0 / 0' : '$currentRound / $rounds',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _MatchesScreen(tournament: tournament),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// ES: Contenedor de jornadas y partidos del torneo.
/// EN: Container for the tournament's rounds and matches.
class _MatchesScreen extends StatelessWidget {
  /// ES: Crea la pantalla de partidos y jornadas.
  /// EN: Creates the rounds and matches screen.
  const _MatchesScreen({required this.tournament});
  final Tournament tournament;

  /// ES: Construye la lista de partidos y la acción de alta para el admin.
  /// EN: Builds the match list and the administrator's add action.
  @override
  Widget build(BuildContext context) {
    final isAdmin =
        FirebaseAuth.instance.currentUser?.uid == tournament.adminId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jornadas y partidos'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Nuevo partido',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      TournamentMatchFormScreen(tournament: tournament),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [TournamentMatchSection(tournament: tournament)],
      ),
    );
  }
}

/// ES: Elige el color semántico que corresponde al estado del torneo.
/// EN: Selects the semantic color for the tournament's status.
Color _tournamentStatusColor(String? status) {
  final value = status?.trim().toLowerCase();
  if (value == 'active' ||
      value == 'playing' ||
      value == 'jugando' ||
      value == 'en_curso')
    return Colors.green.shade700;
  if (value == 'finished' || value == 'finalizado') return Colors.blueGrey;
  return Colors.amber.shade700;
}

/// ES: Presenta categorías, ramas y fechas principales del torneo.
/// EN: Presents the tournament's categories, branches, and key dates.
class _DetailsCard extends StatelessWidget {
  /// ES: Crea la tarjeta de información del torneo.
  /// EN: Creates the tournament details card.
  const _DetailsCard({required this.tournament});
  final Tournament tournament;

  /// ES: Construye los datos descriptivos del torneo.
  /// EN: Builds the tournament's descriptive details.
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categorías y ramas',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tournament.categories
                .map((category) => Chip(label: Text(formatCategory(category))))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Inscripción pública: ${tournament.publicRegistration ? 'Sí' : 'No'}',
          ),
          Text(
            'Fecha de inicio: ${tournament.startDate == null ? 'Pendiente' : _date(tournament.startDate!)}',
          ),
          Text(
            'Fecha de finalización: ${tournament.endDate == null ? 'No definida' : _date(tournament.endDate!)}',
          ),
        ],
      ),
    ),
  );

  /// ES: Da formato día/mes/año a una fecha.
  /// EN: Formats a date as day/month/year.
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

/// ES: Combina el estado del torneo con los partidos activos en tiempo real.
/// EN: Combines tournament status with live match activity.
class _TournamentLiveStatus extends StatelessWidget {
  /// ES: Crea el indicador con el estado alternativo del torneo.
  /// EN: Creates the indicator with the tournament's fallback status.
  const _TournamentLiveStatus({
    required this.tournament,
    required this.fallbackStatus,
  });
  final Tournament tournament;
  final String fallbackStatus;

  /// ES: Observa partidos y muestra el estado actual del torneo.
  /// EN: Watches matches and displays the tournament's current status.
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id)
        .collection('matches')
        .snapshots(),
    builder: (context, snapshot) {
      final statuses =
          snapshot.data?.docs
              .map(
                (doc) => (doc.data()['status'] ?? '').toString().toLowerCase(),
              )
              .toList() ??
          const <String>[];
      final hasLive = statuses.any(
        (value) => [
          'active',
          'playing',
          'jugando',
          'en_curso',
          'live',
          'tiempo_muerto',
        ].contains(value),
      );
      // ES: El estado del torneo manda; terminar un partido no finaliza el torneo.
      // EN: Tournament status is authoritative; finishing one match does not end it.
      final status = hasLive
          ? 'En curso'
          : _formatTournamentStatus(fallbackStatus);
      return InfoBadge(
        label: status,
        color: _tournamentStatusColor(status.toLowerCase()),
      );
    },
  );
}

/// ES: Convierte estados internos del torneo en etiquetas visibles.
/// EN: Converts internal tournament statuses into display labels.
String _formatTournamentStatus(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'active' ||
      normalized == 'playing' ||
      normalized == 'jugando' ||
      normalized == 'en_curso' ||
      normalized == 'en curso')
    return 'En curso';
  if (normalized == 'finished' ||
      normalized == 'finalized' ||
      normalized == 'finalizado' ||
      normalized == 'finalizada')
    return 'Finalizado';
  return 'Por iniciar';
}

/// ES: Convierte identificadores de formato en etiquetas legibles.
/// EN: Converts format identifiers into readable labels.
String _formatLabel(String value) => value == 'todos_contra_todos'
    ? 'Todos contra todos'
    : value == 'por_grupos'
    ? 'Por grupos'
    : value;

int _safeInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return fallback;
}
