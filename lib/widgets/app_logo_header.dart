import 'package:flutter/material.dart';

/// Widget reutilizable que muestra el logo flotante y transparente
/// que se sobrepone sobre el contenido
class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -60.0,
      left: 16.0,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.0), // Completamente transparente
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Image.asset(
          'assets/images/logo_21.png',
          height: 225,
          width: 225,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Si el logo no se encuentra, mostrar un icono de respaldo
            return Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Icon(Icons.local_taxi, size: 209, color: Color(0xFF1D4ED8)),
            );
          },
        ),
      ),
    );
  }
}
