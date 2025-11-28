import 'package:latlong2/latlong.dart';

/// Servicio para calcular distancia y precio estimado del viaje
/// Extraído de welcome_screen.dart
class RideCalculationService {
  /// Calcula la distancia en kilómetros entre dos coordenadas
  static double? calculateDistance(LatLng origin, LatLng destination) {
    try {
      const distance = Distance();
      return distance.as(LengthUnit.Kilometer, origin, destination);
    } catch (e) {
      return null;
    }
  }

  /// Calcula el precio estimado basado en la distancia
  /// Precio: $0.50 por km (puede ser configurable)
  static double? calculateEstimatedPrice(double distanceKm, {double pricePerKm = 0.5}) {
    try {
      return distanceKm * pricePerKm;
    } catch (e) {
      return null;
    }
  }

  /// Calcula distancia y precio en una sola llamada
  static Map<String, double?> calculateDistanceAndPrice(
    LatLng? origin,
    LatLng? destination, {
    double pricePerKm = 0.5,
  }) {
    if (origin == null || destination == null) {
      return {'distance': null, 'price': null};
    }

    final distance = calculateDistance(origin, destination);
    final price = distance != null
        ? calculateEstimatedPrice(distance, pricePerKm: pricePerKm)
        : null;

    return {'distance': distance, 'price': price};
  }
}
