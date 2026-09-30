import 'package:cloud_firestore/cloud_firestore.dart';

/// ES: Representa un club oficial registrado por la liga.
/// EN: Represents an official club registered by the league.
class ClubModel {
  /// ES: Crea un club con su ID de Firestore y nombre visible.
  /// EN: Creates a club with its Firestore ID and display name.
  const ClubModel({required this.id, required this.name});

  final String id;
  final String name;

  /// ES: Convierte un documento de la colección `clubs` en un modelo.
  /// EN: Converts a document from the `clubs` collection into a model.
  factory ClubModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return ClubModel(
      id: document.id,
      name: document.data()['name']?.toString() ?? '',
    );
  }
}
