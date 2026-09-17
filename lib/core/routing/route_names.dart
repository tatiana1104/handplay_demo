// Guardamos cada "path" (la parte de la URL/ruta, ej. '/login') como
// constante en vez de escribirlo directo donde se usa. Así, si algún
// día cambiamos '/login' por '/iniciar-sesion', se edita en un solo
// lugar y no hay que buscar el string por todo el proyecto.
//
// Los segmentos que empiezan con ":" (ej. ":torneoId") son parámetros
// de ruta: go_router los reemplaza por el valor real en tiempo de
// ejecución (ej. '/torneo/abc123') y permite leerlos de vuelta con
// `state.pathParameters['torneoId']` (ver app_router.dart).

/// Nombres y paths de ruta de Cancha, organizados según el mapa de
/// navegación del PRD. Cada ruta se define como una constante estática de la clase
class RouteNames {
  RouteNames._();

  static const String splash = '/'; // Ruta de la pantalla de splash (pantalla inicial que se muestra al abrir la app)
  static const String home = '/torneos'; // Ruta de la pantalla de inicio (lista de torneos)
  static const String profile = '/perfil'; // Perfil de la cuenta autenticada
  static const String createTournament = '/torneos/nuevo'; // Alta de torneo para admin de liga
  static const String login = '/login'; // Ruta de la pantalla de login
  static const String register = '/register'; // Ruta de la pantalla de registro
  static const String recoverPassword = '/recover-password'; // Ruta de la pantalla de recuperación de contraseña
}
