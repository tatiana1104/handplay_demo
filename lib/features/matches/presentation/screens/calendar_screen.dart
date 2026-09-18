import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final matches = FirebaseFirestore.instance.collectionGroup('matches').snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: matches,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No se pudo cargar el calendario. Publica las reglas de Firestore y verifica que el usuario haya iniciado sesión.', textAlign: TextAlign.center)));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = [...snapshot.data!.docs]..sort((a, b) => _dateValue(a.data()['date']).compareTo(_dateValue(b.data()['date'])));
          if (docs.isEmpty) return const Center(child: Text('No hay partidos programados.'));
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final doc in docs) {
            final data = doc.data();
            grouped.putIfAbsent(_dateLabel(data['date']), () => []).add(data);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: grouped.entries
                .map((entry) => _CalendarDay(title: entry.key, matches: entry.value))
                .toList(),
          );
        },
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.title, required this.matches});
  final String title;
  final List<Map<String, dynamic>> matches;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7, top: 4),
            child: Text(title, style: Theme.of(context).textTheme.labelMedium),
          ),
          ...matches.map((match) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(child: _Team(name: _name(match, true), color: _color(match['homeTeamColor'], Colors.green))),
                        Column(children: [
                          Text(_time(match['date']), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(match['venue']?.toString() ?? 'Sede por definir', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                        ]),
                        Expanded(child: Align(alignment: Alignment.centerRight, child: _Team(name: _name(match, false), color: _color(match['awayTeamColor'], Colors.deepOrange)))),
                      ]),
                      const SizedBox(height: 7),
                      Align(alignment: Alignment.centerLeft, child: DecoratedBox(decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(5)), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text('Cargar resultado', style: TextStyle(color: Colors.white, fontSize: 11))))),
                    ],
                  ),
                ),
              )),
        ],
      );

  String _name(Map<String, dynamic> match, bool home) => match[home ? 'homeTeamName' : 'awayTeamName']?.toString() ?? match[home ? 'homeTeam' : 'awayTeam']?.toString() ?? (home ? 'Equipo local' : 'Equipo visitante');
  Color _color(dynamic value, Color fallback) => value is int ? Color(value) : fallback;
}

DateTime _dateValue(dynamic value) => value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '') ?? DateTime(9999);

String _dateLabel(dynamic value) {
  final date = value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Fecha por definir';
  const weekdays = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  const months = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  return '${weekdays[date.weekday]} ${date.day} de ${months[date.month]}';
}

String _time(dynamic value) {
  final date = value is Timestamp ? value.toDate() : DateTime.tryParse(value?.toString() ?? '');
  return date == null ? 'Hora por definir' : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _Team extends StatelessWidget {
  const _Team({required this.name, required this.color});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))]);
}
