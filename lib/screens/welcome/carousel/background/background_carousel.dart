import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'background_data.dart';

/// Carrusel de imágenes de fondo
/// Extraído de welcome_screen.dart
class BackgroundCarousel extends StatefulWidget {
  const BackgroundCarousel({super.key});

  @override
  State<BackgroundCarousel> createState() => _BackgroundCarouselState();
}

class _BackgroundCarouselState extends State<BackgroundCarousel> {
  final PageController _backgroundCarouselController = PageController();
  int _currentBackgroundIndex = 0;
  Timer? _backgroundCarouselTimer;

  @override
  void initState() {
    super.initState();
    // Iniciar el carrusel de fondo automático después de que el widget esté construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundCarouselTimer();
    });
  }

  @override
  void dispose() {
    _backgroundCarouselTimer?.cancel();
    _backgroundCarouselController.dispose();
    super.dispose();
  }

  void _startBackgroundCarouselTimer() {
    _backgroundCarouselTimer?.cancel();
    _backgroundCarouselTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted || !_backgroundCarouselController.hasClients) return;

      if (_currentBackgroundIndex < BackgroundData.images.length - 1) {
        _currentBackgroundIndex++;
      } else {
        _currentBackgroundIndex = 0;
      }

      _backgroundCarouselController.animateToPage(
        _currentBackgroundIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _backgroundCarouselController,
      itemCount: BackgroundData.images.length,
      itemBuilder: (context, index) {
        final imagePath = BackgroundData.images[index];
        if (kDebugMode) {
          debugPrint('[BackgroundCarousel] Cargando imagen de fondo $index: $imagePath');
        }
        return Image.asset(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 1920, // Limitar ancho para evitar distorsión
          cacheHeight: 1080, // Limitar alto para evitar distorsión
          filterQuality: FilterQuality.medium, // Balance entre calidad y rendimiento
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              debugPrint('[BackgroundCarousel] ❌ Error cargando imagen de fondo: $imagePath');
              debugPrint('[BackgroundCarousel] Error: ${error.toString()}');
            }
            // Mostrar un placeholder si falla
            return Container(
              color: Colors.grey.shade800,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, color: Colors.grey.shade600, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Imagen no disponible',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      onPageChanged: (index) {
        if (kDebugMode) {
          debugPrint(
            '[BackgroundCarousel] Cambiando a imagen de fondo: $index (${BackgroundData.images[index]})',
          );
        }
        setState(() {
          _currentBackgroundIndex = index;
        });
      },
    );
  }
}
