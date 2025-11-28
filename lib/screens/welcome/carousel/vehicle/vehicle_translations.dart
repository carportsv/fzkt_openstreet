import 'package:flutter/material.dart';
import '../../../../../l10n/app_localizations.dart';

/// Utilidades para traducción de vehículos
/// Extraído de welcome_screen.dart
class VehicleTranslations {
  /// Obtiene el nombre traducido del vehículo
  static String getVehicleName(String key, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (key) {
      case 'sedan':
        return l10n?.vehicleSedan ?? 'Sedán';
      case 'economy':
        return l10n?.vehicleEconomy ?? 'Económica';
      case 'suv':
        return l10n?.vehicleSUV ?? 'SUV';
      case 'van':
        return l10n?.vehicleVan ?? 'Van';
      case 'luxury':
        return l10n?.vehicleLuxury ?? 'Lujo';
      default:
        return key;
    }
  }

  /// Obtiene la descripción traducida del vehículo
  static String getVehicleDescription(String key, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (key) {
      case 'sedanDesc':
        return l10n?.vehicleSedanDesc ?? 'Cómodo y confortable';
      case 'economyDesc':
        return l10n?.vehicleEconomyDesc ?? 'Ideal para viajes cortos';
      case 'suvDesc':
        return l10n?.vehicleSUVDesc ?? 'Espacioso para grupos';
      case 'vanDesc':
        return l10n?.vehicleVanDesc ?? 'Perfecto para grupos grandes';
      case 'luxuryDesc':
        return l10n?.vehicleLuxuryDesc ?? 'Experiencia premium';
      default:
        return '';
    }
  }
}
