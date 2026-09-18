import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RefereesScreen extends StatelessWidget {
  const RefereesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final referees = FirebaseFirestore.instance
        .collection('users')
        .where('roles', arrayContains: 'arbitro')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Listado de árbitros')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: referees,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudieron cargar los árbitros.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No hay árbitros registrados.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final name = data['displayName']?.toString() ?? data['nombre']?.toString() ?? 'Árbitro sin nombre';
              final email = data['email']?.toString() ?? '';
              final phone = data['phone']?.toString() ?? data['telefono']?.toString() ?? '';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(name.substring(0, 1).toUpperCase())),
                  title: Text(name),
                  subtitle: Text([email, phone].where((value) => value.isNotEmpty).join(' · ')),
                  trailing: const Icon(Icons.sports_handball_outlined),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
