import 'package:cloud_firestore/cloud_firestore.dart';

/// ES: Representa un club oficial registrado por la liga.
/// EN: Represents an official club registered by the league.
class ClubModel {
  /// ES: Crea un club con su ID de Firestore y nombre visible.
  /// EN: Creates a club with its Firestore ID and display name.
  const ClubModel({required this.id, required this.name, this.email = '', this.coachName = '', this.coachDocument = '', this.coachEmail = '', this.assistantName = '', this.assistantDocument = '', this.assistantEmail = ''});

  final String id;
  final String name;
  final String email;
  final String coachName;
  final String coachDocument;
  final String coachEmail;
  final String assistantName;
  final String assistantDocument;
  final String assistantEmail;

  /// ES: Convierte un documento de la colección `clubs` en un modelo.
  /// EN: Converts a document from the `clubs` collection into a model.
  factory ClubModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return ClubModel(
      id: document.id,
      name: document.data()['name']?.toString() ?? '',
      email: document.data()['email']?.toString() ?? '',
      coachName: document.data()['coachName']?.toString() ?? '',
      coachDocument: document.data()['coachDocument']?.toString() ?? '',
      coachEmail: document.data()['coachEmail']?.toString() ?? '',
      assistantName: document.data()['assistantName']?.toString() ?? '',
      assistantDocument: document.data()['assistantDocument']?.toString() ?? '', document.data()['assistantName']?.toString() ?? '',
      assistantEmail: document.data()['assistantEmail']?.toString() ?? '',
    );
  }
}
