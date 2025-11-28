import 'dart:async';
import 'package:flutter/material.dart';
import 'vehicle_carousel_item.dart';
import 'carousel_navigation_arrow.dart';
import 'carousel_indicator.dart';

// Constants
const _kBorderRadius = 12.0;
const _kSpacing = 16.0;

/// Carrusel de vehículos
/// Extraído de welcome_screen.dart
class VehicleCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles;

  const VehicleCarousel({super.key, required this.vehicles});

  @override
  State<VehicleCarousel> createState() => _VehicleCarouselState();
}

class _VehicleCarouselState extends State<VehicleCarousel> {
  final PageController _carouselController = PageController();
  int _currentCarIndex = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_carouselController.hasClients) return;

      if (_currentCarIndex < widget.vehicles.length - 1) {
        _currentCarIndex++;
      } else {
        _currentCarIndex = 0;
      }

      _carouselController.animateToPage(
        _currentCarIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _previousPage() {
    if (!_carouselController.hasClients) return;

    if (_currentCarIndex > 0) {
      _carouselController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Si está en la primera página, ir a la última
      _carouselController.animateToPage(
        widget.vehicles.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _startCarouselTimer();
  }

  void _nextPage() {
    if (!_carouselController.hasClients) return;

    if (_currentCarIndex < widget.vehicles.length - 1) {
      _carouselController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Si está en la última página, ir a la primera
      _carouselController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _startCarouselTimer();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Container(
      margin: EdgeInsets.all(isTablet ? 24.0 : 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kBorderRadius * 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kBorderRadius * 4),
        child: Column(
          children: [
            // Carousel con flechas de navegación
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _carouselController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentCarIndex = index;
                      });
                      // Reiniciar el timer cuando el usuario cambia manualmente
                      _startCarouselTimer();
                    },
                    itemCount: widget.vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = widget.vehicles[index];
                      return VehicleCarouselItem(vehicle: vehicle);
                    },
                  ),
                  // Flecha izquierda
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: CarouselNavigationArrow(
                        icon: Icons.chevron_left,
                        onPressed: _previousPage,
                        isLeft: true,
                      ),
                    ),
                  ),
                  // Flecha derecha
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: CarouselNavigationArrow(
                        icon: Icons.chevron_right,
                        onPressed: _nextPage,
                        isLeft: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Indicators
            Container(
              padding: const EdgeInsets.all(_kSpacing),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(_kBorderRadius * 4),
                  bottomRight: Radius.circular(_kBorderRadius * 4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.vehicles.length,
                  (index) => CarouselIndicator(isActive: index == _currentCarIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
