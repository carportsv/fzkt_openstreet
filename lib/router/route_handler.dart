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
      // En web, verificar la URL actual usando Uri.base
      final path = Uri.base.path;

      if (kDebugMode) {
        debugPrint('[RouteHandler] Current path: $path');
      }

      // Si la ruta es /welcome, mostrar WelcomeScreen directamente
      if (path == '/welcome') {
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
    } else {
      // En móvil, siempre mostrar AuthGate
      return const AuthGate();
    }
  }
}
