import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/tournament_repository.dart';
import '../../domain/models/tournament_models.dart';
import 'create_tournament_screen.dart';
import 'pending_registrations_screen.dart';
import 'team_registration_screen.dart';
import 'tournament_detail_screen.dart';

/// Home público y panel de torneos de la liga de balonmano.
/// Solo el custom claim `rol: admin_liga` habilita la creación de torneos.
/// EN: Public home and tournament list; the league-admin claim enables management actions.
class TorneosScreen extends StatelessWidget {
  /// ES: Crea la pantalla principal de torneos.
  /// EN: Creates the main tournaments screen.
  const TorneosScreen({super.key});

  /// ES: Carga los torneos y presenta acciones según la sesión y el rol.
  /// EN: Loads tournaments and shows actions based on session and role.
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return FutureBuilder<IdTokenResult?>(
      future: FirebaseAuth.instance.currentUser?.getIdTokenResult(),
      builder: (context, roleSnapshot) {
        final isAdmin = _hasAdminRole(roleSnapshot.data?.claims);
        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liga de Balonmano del Caquetá',
                  style: TextStyle(fontSize: 12),
                ),
                Text('Mis torneos'),
              ],
            ),
            actions: [
              if (user != null) _CreateTournamentAction(userId: user.uid),
            ],
          ),
          bottomNavigationBar: AppBottomNavigationBar(
            selectedIndex: 0,
            isAuthenticated: user != null,
            isAdmin: isAdmin,
          ),
          body: _PublicTournamentList(
            isAdmin: isAdmin,
            adminId: user?.uid,
            coachEmail: user?.email,
          ),
        );
      },
    );
  }
}

/// ES: Muestra el acceso para crear torneos solo a administradores.
/// EN: Shows the tournament creation action only to administrators.
class _CreateTournamentAction extends StatelessWidget {
  /// ES: Crea la acción de alta asociada al usuario actual.
  /// EN: Creates the add action for the current user.
  const _CreateTournamentAction({required this.userId});

  final String userId;

  /// ES: Comprueba permisos y muestra el botón de creación.
  /// EN: Checks permissions and renders the create button.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdTokenResult>(
      future: FirebaseAuth.instance.currentUser?.getIdTokenResult(),
      builder: (context, snapshot) {
        if (!_hasAdminRole(snapshot.data?.claims))
          return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () => context.push('/torneos/nuevo', extra: userId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo torneo'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ES: Verifica permisos de administración en claims actuales y heredados.
/// EN: Checks administrator permissions in current and legacy claims.
bool _hasAdminRole(Map<String, dynamic>? claims) {
  final roles =
      (claims?['roles'] as List?)?.whereType<String>().toSet() ?? <String>{};
  final legacyRole = claims?['rol'];
  return roles.contains('admin') ||
      roles.contains('admin_liga') ||
      legacyRole == 'admin' ||
      legacyRole == 'admin_liga';
}

/// ES: Estados disponibles para filtrar la lista de torneos.
/// EN: Available states for filtering the tournament list.
enum _TournamentFilter { all, upcoming, playing, finished }

/// ES: Parámetros de la lista pública de torneos y permisos del usuario.
/// EN: Public tournament list parameters and current user permissions.
class _PublicTournamentList extends StatefulWidget {
  /// ES: Crea la lista con filtros y datos opcionales del usuario.
  /// EN: Creates the list with filters and optional user details.
  const _PublicTournamentList({
    required this.isAdmin,
    this.adminId,
    this.coachEmail,
  });

  final bool isAdmin;
  final String? adminId;
  final String? coachEmail;

  /// ES: Crea el estado que controla el filtro seleccionado.
  /// EN: Creates the state that controls the selected filter.
  @override
  State<_PublicTournamentList> createState() => _PublicTournamentListState();
}

class _PublicTournamentListState extends State<_PublicTournamentList> {
  _TournamentFilter _filter = _TournamentFilter.all;

  /// ES: Observa torneos, aplica el filtro y construye la lista ordenada.
  /// EN: Watches tournaments, applies the filter, and builds the sorted list.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tournament>>(
      stream: TournamentRepository().watchPublicTournaments(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _MessageCard(
            icon: Icons.lock_outline_rounded,
            message: 'No se pudieron cargar tus torneos.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allTournaments = [...?snapshot.data];
        final visibleTournaments =
            allTournaments
                .where((tournament) => _matchesFilter(tournament, _filter))
                .toList()
              ..sort(_compareTournaments);

        return Column(
          children: [
            _FilterBar(
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
            Expanded(
              child: visibleTournaments.isEmpty
                  ? const _EmptyFilteredTournaments()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: visibleTournaments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _TournamentCard(
                        tournament: visibleTournaments[index],
                        // ES: La pantalla valida el rol; no exige adminId en torneos antiguos.
                        // EN: The screen validates the role; older tournaments may lack adminId.
                        isAdmin: widget.isAdmin,
                        onTap: () => context.go(
                          RouteNames.tournamentDetail,
                          extra: visibleTournaments[index],
                        ),
                        onEdit: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateTournamentScreen(
                              adminId: widget.adminId!,
                              tournament: visibleTournaments[index],
                            ),
                          ),
                        ),
                        onRequests: () => context.push(
                          RouteNames.internal,
                          extra: PendingRegistrationsScreen(
                            tournamentId: visibleTournaments[index].id,
                            tournamentName: visibleTournaments[index].name,
                          ),
                        ),
                        onDelete: () => _deleteTournament(
                          context,
                          visibleTournaments[index],
                        ),
                        coachEmail: widget.coachEmail,
                        coachUid: widget.adminId == null
                            ? null
                            : FirebaseAuth.instance.currentUser?.uid,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// ES: Confirma y elimina el torneo seleccionado.
  /// EN: Confirms and deletes the selected tournament.
  Future<void> _deleteTournament(
    BuildContext context,
    Tournament tournament,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar torneo'),
        content: Text(
          '¿Eliminar "${tournament.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await TournamentRepository().deleteTournament(tournament.id);
  }

  /// ES: Decide si un torneo pertenece al filtro elegido.
  /// EN: Determines whether a tournament belongs to the selected filter.
  bool _matchesFilter(Tournament tournament, _TournamentFilter filter) {
    switch (filter) {
      case _TournamentFilter.all:
        return true;
      case _TournamentFilter.upcoming:
        return _statusOf(tournament) == _TournamentStatus.upcoming;
      case _TournamentFilter.playing:
        return _statusOf(tournament) == _TournamentStatus.playing;
      case _TournamentFilter.finished:
        return _statusOf(tournament) == _TournamentStatus.finished;
    }
  }

  /// ES: Ordena primero por estado y luego por fecha de inicio.
  /// EN: Sorts by status first and start date second.
  int _compareTournaments(Tournament a, Tournament b) {
    final priority = {
      _TournamentStatus.upcoming: 0,
      _TournamentStatus.playing: 1,
      _TournamentStatus.finished: 2,
    };
    final statusComparison = priority[_statusOf(a)]!.compareTo(
      priority[_statusOf(b)]!,
    );
    if (statusComparison != 0) return statusComparison;
    return (a.startDate ?? DateTime(9999)).compareTo(
      b.startDate ?? DateTime(9999),
    );
  }
}

/// ES: Clasificación normalizada del estado de un torneo.
/// EN: Normalized classification of a tournament's status.
enum _TournamentStatus { upcoming, playing, finished }

/// ES: Convierte distintos valores guardados al estado normalizado.
/// EN: Converts supported stored values into a normalized status.
_TournamentStatus _statusOf(Tournament tournament) {
  final status = tournament.status.trim().toLowerCase();
  if (status == 'finished' || status == 'finalizado' || status == 'completed') {
    return _TournamentStatus.finished;
  }
  if (status == 'active' ||
      status == 'playing' ||
      status == 'jugando' ||
      status == 'en_curso') {
    return _TournamentStatus.playing;
  }
  return _TournamentStatus.upcoming;
}

/// ES: Presenta las opciones para filtrar torneos por estado.
/// EN: Presents options for filtering tournaments by status.
class _FilterBar extends StatelessWidget {
  /// ES: Crea la barra con el filtro actual y su callback.
  /// EN: Creates the bar with the current filter and callback.
  const _FilterBar({required this.selected, required this.onChanged});

  final _TournamentFilter selected;
  final ValueChanged<_TournamentFilter> onChanged;

  /// ES: Construye los botones de filtro horizontales.
  /// EN: Builds the horizontal filter controls.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'Todos',
            selected: selected == _TournamentFilter.all,
            onTap: () => onChanged(_TournamentFilter.all),
          ),
          _FilterChip(
            label: 'Por iniciar',
            selected: selected == _TournamentFilter.upcoming,
            onTap: () => onChanged(_TournamentFilter.upcoming),
          ),
          _FilterChip(
            label: 'Jugando',
            selected: selected == _TournamentFilter.playing,
            onTap: () => onChanged(_TournamentFilter.playing),
          ),
          _FilterChip(
            label: 'Terminados',
            selected: selected == _TournamentFilter.finished,
            onTap: () => onChanged(_TournamentFilter.finished),
          ),
        ],
      ),
    );
  }
}

/// ES: Botón compacto que representa una opción de filtro.
/// EN: Compact button representing one filter option.
class _FilterChip extends StatelessWidget {
  /// ES: Crea una opción con etiqueta y estado seleccionado.
  /// EN: Creates an option with a label and selected state.
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// ES: Construye la opción con el estilo del estado seleccionado.
  /// EN: Builds the option with selected-state styling.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colors.primary.withValues(alpha: .22),
        checkmarkColor: colors.primary,
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
    );
  }
}

/// ES: Contenido informativo que se muestra a visitantes públicos.
/// EN: Informational content shown to public visitors.
class _PublicHomeContent extends StatelessWidget {
  /// ES: Crea el contenido público de inicio.
  /// EN: Creates the public home content.
  const _PublicHomeContent();

  /// ES: Construye la presentación informativa de la liga.
  /// EN: Builds the league's informational introduction.
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.sports_handball_rounded, size: 72),
        const SizedBox(height: 20),
        Text('Gestiona tu liga de balonmano', style: textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          'Consulta torneos, equipos, partidos y resultados desde un solo lugar.',
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

/// ES: Mensaje que indica que el filtro no encontró torneos.
/// EN: Message shown when the selected filter returns no tournaments.
class _EmptyFilteredTournaments extends StatelessWidget {
  /// ES: Crea el estado vacío de la lista filtrada.
  /// EN: Creates the empty state for the filtered list.
  const _EmptyFilteredTournaments();

  /// ES: Muestra el mensaje de lista vacía centrado.
  /// EN: Displays the empty-list message in the center.
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('No hay torneos en este estado.'),
    ),
  );
}

/// ES: Tarjeta de torneo con estado, fecha y acciones permitidas.
/// EN: Tournament card showing status, date, and permitted actions.
class _TournamentCard extends StatelessWidget {
  /// ES: Crea la tarjeta y recibe callbacks para sus acciones.
  /// EN: Creates the card and receives callbacks for its actions.
  const _TournamentCard({
    required this.tournament,
    required this.onTap,
    required this.isAdmin,
    required this.onEdit,
    required this.onRequests,
    required this.onDelete,
    this.coachEmail,
    this.coachUid,
  });

  final Tournament tournament;
  final VoidCallback onTap;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onRequests;
  final VoidCallback onDelete;
  final String? coachEmail;
  final String? coachUid;

  /// ES: Construye la tarjeta y sus acciones de usuario.
  /// EN: Builds the card and its user actions.
  @override
  Widget build(BuildContext context) {
  final registrationStream = coachUid == null
      ? null
      : FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournament.id)
          .collection('registrations')
          .where('coachUid', isEqualTo: coachUid)
          .limit(20)
          .snapshots();
    final status = _statusOf(tournament);
    final isPlaying = status == _TournamentStatus.playing;
    final isFinished = status == _TournamentStatus.finished;
    final label = isFinished
        ? 'terminado'
        : isPlaying
        ? 'jugando'
        : 'por iniciar';
    final progress = isFinished
        ? 1.0
        : isPlaying
        ? .45
        : .05;
    final dateLabel = tournament.startDate == null
        ? 'Fecha de inicio pendiente'
        : '${isFinished ? 'Finalizó' : 'Inicia'}: ${tournament.startDate!.day.toString().padLeft(2, '0')}/${tournament.startDate!.month.toString().padLeft(2, '0')}/${tournament.startDate!.year}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPlaying ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tournament.name.isEmpty
                          ? 'Torneo sin nombre'
                          : tournament.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusPill(label: label, status: status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${tournament.format} · ${tournament.teamLimit} equipos',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
              if (!isAdmin && registrationStream != null)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: registrationStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final docs = [...snapshot.data!.docs]
                      ..sort((a, b) {
                        final aDate =
                            (a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final bDate =
                            (b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return bDate.compareTo(aDate);
                      });
                    final data = docs.first.data();
                    final requestStatus = data['status']?.toString();
                    final rejectedReason = data['rejectionReason']?.toString();
                    final isRejected = requestStatus == 'rejected';
                    final isApproved = requestStatus == 'approved';
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              (isRejected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.errorContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer)
                                  .withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isApproved
                                  ? 'Solicitud aprobada'
                                  : isRejected
                                  ? 'Solicitud rechazada'
                                  : 'Solicitud pendiente',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isRejected) ...[
                              const SizedBox(height: 4),
                              Text(
                                rejectedReason?.isNotEmpty == true
                                    ? rejectedReason!
                                    : 'Revisa la información y vuelve a enviar la inscripción.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Puedes editar los datos indicados y volver a enviar la solicitud.',
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () => context.push(
                                  RouteNames.internal,
                                  extra: TeamRegistrationScreen(
                                    tournament: tournament,
                                    registrationId: docs.first.id,
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar solicitud'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (isAdmin) ...[
                const Divider(height: 20),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Editar'),
                    ),
                    TextButton.icon(
                      onPressed: onRequests,
                      icon: const Icon(Icons.fact_check_outlined, size: 17),
                      label: const Text('Solicitudes'),
                    ),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ES: Etiqueta visual para el estado actual del torneo.
/// EN: Visual label for the tournament's current status.
class _StatusPill extends StatelessWidget {
  /// ES: Crea la etiqueta con texto y estado.
  /// EN: Creates the label with its text and status.
  const _StatusPill({required this.label, required this.status});

  final String label;
  final _TournamentStatus status;

  /// ES: Construye la etiqueta con el color semántico correspondiente.
  /// EN: Builds the label using its semantic status color.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = status == _TournamentStatus.playing
        ? (Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandDark
              : AppColors.brandLight)
        : status == _TournamentStatus.finished
        ? colors.onSurfaceVariant
        : (Theme.of(context).brightness == Brightness.dark
              ? AppColors.amberDark
              : AppColors.amberLight);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// ES: Presenta un mensaje centrado con su icono contextual.
/// EN: Presents a centered message with its contextual icon.
class _MessageCard extends StatelessWidget {
  /// ES: Crea la tarjeta informativa.
  /// EN: Creates the information card.
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  /// ES: Construye el icono y el mensaje centrados.
  /// EN: Builds the centered icon and message.
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
