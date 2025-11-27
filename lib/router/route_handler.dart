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

        // Normalizar el path removiendo el base-href si está presente
        String normalizedPath = path;
        if (path.startsWith('/fzkt_openstreet')) {
          normalizedPath = path.replaceFirst('/fzkt_openstreet', '');
          if (normalizedPath.isEmpty) {
            normalizedPath = '/';
          }
        }

        // Normalizar el fragment - puede venir como "/welcome" o "welcome"
        String normalizedFragment = fragment;
        if (fragment.isNotEmpty) {
          if (!fragment.startsWith('/')) {
            normalizedFragment = '/$fragment';
          }
        }

        // Verificar si la ruta o el fragmento contiene /welcome
        final hasWelcomeInUrl = fullUri.contains('/welcome') || fullUri.contains('#/welcome');
        final isWelcomePath = normalizedPath.endsWith('/welcome') || normalizedPath == '/welcome';
        final isWelcomeFragment =
            normalizedFragment == '/welcome' ||
            normalizedFragment == '/welcome/' ||
            normalizedFragment.contains('/welcome') ||
            fragment == 'welcome' ||
            fragment == '/welcome';

        if (kDebugMode) {
          debugPrint('[RouteHandler] Normalized path: $normalizedPath');
          debugPrint('[RouteHandler] Normalized fragment: $normalizedFragment');
          debugPrint('[RouteHandler] isWelcomePath: $isWelcomePath');
          debugPrint('[RouteHandler] isWelcomeFragment: $isWelcomeFragment');
          debugPrint('[RouteHandler] hasWelcomeInUrl: $hasWelcomeInUrl');
        }

        // Mostrar WelcomeScreen SOLO si es específicamente /welcome
        if (isWelcomePath || isWelcomeFragment || hasWelcomeInUrl) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] Showing WelcomeScreen');
          }
          return const WelcomeScreen();
        }

        // Para cualquier otra ruta, mostrar AuthGate
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
