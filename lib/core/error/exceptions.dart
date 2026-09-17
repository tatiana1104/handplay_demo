/// Excepción interna de la capa `data`. Nunca debería llegar a la UI
/// directamente: cada `XxxRepositoryImpl` la atrapa y la convierte en
/// un `Either<Failure, T>` (ver `failures.dart`), que es el contrato
/// que usan el dominio y el BLoC.
class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}
