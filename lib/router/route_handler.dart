import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../auth/auth_gate.dart';
import '../screens/welcome/welcome_screen.dart';

/// Widget que maneja las rutas basándose en la URL actual
class RouteHandler extends StatelessWidget {
  const RouteHandler({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      try {
        // En web, verificar la URL actual usando Uri.base
        // Normalizar el path para eliminar dobles barras y prevenir SecurityError
        String path = Uri.base.path.replaceAll(RegExp(r'/+'), '/');
        if (path.length > 1 && path.endsWith('/')) {
          path = path.substring(0, path.length - 1);
        }
        // Si el path está vacío o es solo '/', mantenerlo como '/'
        if (path.isEmpty) {
          path = '/';
        }

        // También verificar el fragmento (hash) de la URL para rutas como /#/welcome
        final fragment = Uri.base.fragment;
        // Obtener la URL completa para verificar el hash
        final fullUri = Uri.base.toString();

        if (kDebugMode) {
          debugPrint('[RouteHandler] Current path: $path');
          debugPrint('[RouteHandler] Current fragment: $fragment');
          debugPrint('[RouteHandler] Full URI: $fullUri');
        }

        // Verificar si la ruta o el fragmento contiene /welcome
        // El fragmento puede venir como "/welcome" o "welcome" dependiendo de cómo se acceda
        // También verificar en la URL completa por si el hash no se captura en el fragmento
        final normalizedFragment = fragment.startsWith('/') ? fragment : '/$fragment';
        final hasWelcomeInUrl = fullUri.contains('/welcome') || fullUri.contains('#/welcome');

        final isWelcomePath = path.endsWith('/welcome') || path == '/welcome';
        final isWelcomeFragment =
            normalizedFragment.contains('/welcome') ||
            normalizedFragment == '/welcome' ||
            normalizedFragment == '/welcome/' ||
            fragment == 'welcome';

        if (isWelcomePath || isWelcomeFragment || hasWelcomeInUrl) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] Showing WelcomeScreen');
          }
          return const WelcomeScreen();
        }

        // Para cualquier otra ruta (incluyendo /), mostrar AuthGate
        if (kDebugMode) {
          debugPrint('[RouteHandler] Showing AuthGate');
        }
        return const AuthGate();
      } catch (e) {
        // Si hay un error al procesar la URL (como SecurityError),
        // mostrar AuthGate como fallback
        if (kDebugMode) {
          debugPrint('[RouteHandler] Error procesando URL: $e');
          debugPrint('[RouteHandler] Mostrando AuthGate como fallback');
        }
        return const AuthGate();
      }
    } else {
      // En móvil, siempre mostrar AuthGate
      return const AuthGate();
    }
  }
}
