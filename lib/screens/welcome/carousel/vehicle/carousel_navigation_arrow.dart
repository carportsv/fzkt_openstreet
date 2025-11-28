import 'package:flutter/material.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);

/// Flecha de navegación del carrusel
/// Extraído de welcome_screen.dart
class CarouselNavigationArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLeft;

  const CarouselNavigationArrow({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(icon, color: _kPrimaryColor, size: 28),
        ),
      ),
    );
  }
}
