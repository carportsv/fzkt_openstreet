import 'package:flutter/material.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);

/// Indicador del carrusel
/// Extraído de welcome_screen.dart
class CarouselIndicator extends StatelessWidget {
  final bool isActive;

  const CarouselIndicator({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? _kPrimaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12), // Más ovalado
      ),
    );
  }
}
