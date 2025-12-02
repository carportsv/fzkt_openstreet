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
      case 'business':
        return l10n?.vehicleBusiness ?? 'Business';
      case 'minibus_8pax':
        return l10n?.vehicleMinibus8pax ?? 'Minibus 8pax';
      case 'bus_16pax':
        return l10n?.vehicleBus16pax ?? 'Bus 16pax';
      case 'bus_19pax':
        return l10n?.vehicleBus19pax ?? 'Bus 19pax';
      case 'bus_50pax':
        return l10n?.vehicleBus50pax ?? 'Bus 50pax';
      default:
        // Para tipos como 'Minivan 7pax' y 'Minivan Luxury 6pax', usar el nombre del tipo directamente
        // o buscar una traducción específica
        if (key.contains('minivan')) {
          if (key.contains('luxury')) {
            return l10n?.vehicleMinivanLuxury6pax ?? 'Minivan Luxury 6pax';
          }
          return l10n?.vehicleMinivan7pax ?? 'Minivan 7pax';
        }
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
