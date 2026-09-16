import 'package:flutter/material.dart';

// Este archivo centraliza los "números mágicos" y catálogos fijos del
// dominio de Cancha, para no repetirlos sueltos por todo el código y
// para que cada valor quede trazado al requerimiento (RF) o regla de
// negocio (RN) del PRD que lo justifica.

/// Constantes generales de la aplicación Cancha.
///
/// El constructor privado `AppConstants._()` evita que alguien intente
/// hacer `AppConstants()` por error: esta clase solo sirve como
/// "espacio de nombres" para constantes estáticas, nunca se instancia.
class AppConstants {
  AppConstants._();

  static const String appName = 'HandPlay'; // Nombre de la app que se muestra en la barra de tareas y en el switcher de apps
  static const String ligaNombre = 'Liga de Balonmano del Caquetá'; // Nombre de la liga que se muestra en la pantalla de splash y en la barra superior de la app
  static const IconData appLogoIcon = Icons.sports_handball; // Icono principal de la app usado en splash y login

  // Textos principales de las pantallas de autenticación
  static const String emailLabel = 'Correo electrónico';
  static const String passwordLabel = 'Contraseña';
  static const String separatorLabel = 'o';
  static const String googleButton = 'Continuar con Google';

  /// "Web client (auto created by Google Service)" — el client_id tipo
  /// 3 (`client_type: 3`) dentro de `android/app/google-services.json`,
  /// bajo `oauth_client`. `GoogleSignIn.instance.initialize()` lo
  /// necesita como `serverClientId` para que, en Android, el idToken
  /// que devuelve `authenticate()` tenga la audiencia correcta y
  /// Firebase Auth lo acepte. Si el proyecto de Firebase cambia o se
  /// regenera `google-services.json`, este valor hay que actualizarlo
  /// (o volver a correr `flutterfire configure`, que no lo toca —
  /// este es un client_id de Google Cloud, no de Firebase).
  static const String googleServerClientId =
      '332080945965-493uad1m41ahg1c66ojcjsgonem5dv77.apps.googleusercontent.com';
}