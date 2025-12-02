import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../../l10n/app_localizations.dart';
import 'vehicle_info_chip.dart';
import 'vehicle_translations.dart';

// Constants
const _kSpacing = 16.0;

/// Item individual del carrusel de vehículos
/// Extraído de welcome_screen.dart
class VehicleCarouselItem extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const VehicleCarouselItem({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Vehicle Image - Ampliada sin fondo
          Center(
            child: Transform.scale(
              scale: 0.8,
              child: Builder(
                builder: (context) {
                  final imagePath = vehicle['image'] as String;
                  if (kDebugMode) {
                    debugPrint('[VehicleCarousel] Cargando imagen de vehículo: $imagePath');
                  }
                  return Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      // Si la imagen no existe, mostrar placeholder y loguear error
                      if (kDebugMode) {
                        debugPrint(
                          '[VehicleCarousel] ❌ Error cargando imagen de vehículo: $imagePath',
                        );
                        debugPrint('[VehicleCarousel] Error: ${error.toString()}');
                      }
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey.shade200,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car, size: 120, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                return Text(
                                  VehicleTranslations.getVehicleName(
                                    vehicle['key'] as String,
                                    context,
                                  ),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n?.imageNotAvailable ?? 'Imagen no disponible',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Vehicle Info Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(_kSpacing * 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        VehicleTranslations.getVehicleName(vehicle['key'] as String, context),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        VehicleTranslations.getVehicleDescription(
                          vehicle['descriptionKey'] as String,
                          context,
                        ),
                        style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          VehicleInfoChip(
                            icon: Icons.people,
                            text: '${vehicle['passengers']} ${l10n?.passengers ?? 'Pasajeros'}',
                          ),
                          const SizedBox(width: 12),
                          VehicleInfoChip(
                            icon: Icons.luggage,
                            text: '${vehicle['luggage']} ${l10n?.vehicleLuggage ?? 'Equipajes'}',
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
