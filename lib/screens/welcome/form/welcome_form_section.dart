import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../l10n/app_localizations.dart';
import 'location_input_field.dart';
import 'date_field.dart';
import 'time_field.dart';
import 'passengers_field.dart';
import 'info_field.dart';

// Constants
const _kBorderRadius = 12.0;
const _kSpacing = 16.0;

/// Sección del formulario de solicitud de viaje
/// Extraída del welcome_screen.dart
class WelcomeFormSection extends StatelessWidget {
  // Controllers y FocusNodes
  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final TextEditingController timeController;
  final FocusNode pickupFocusNode;
  final FocusNode dropoffFocusNode;

  // Estado del formulario
  final String? activeInputType;
  final List<Map<String, dynamic>> autocompleteResults;
  final DateTime? pickupDate;
  final int passengers;
  final int maxPassengers;
  final LatLng? originCoords;
  final LatLng? destinationCoords;
  final double? distanceKm;
  final double? estimatedPrice;

  // Callbacks
  final Function(String, String) onAddressInputChanged;
  final Function(Map<String, dynamic>, String) onSelectAddress;
  final VoidCallback onSelectPickupDate;
  final VoidCallback onSelectPickupTime;
  final Function(int) onPassengersChanged;
  final VoidCallback onNavigateToRequestRide;

  const WelcomeFormSection({
    super.key,
    required this.pickupController,
    required this.dropoffController,
    required this.timeController,
    required this.pickupFocusNode,
    required this.dropoffFocusNode,
    required this.activeInputType,
    required this.autocompleteResults,
    required this.pickupDate,
    required this.passengers,
    required this.maxPassengers,
    required this.originCoords,
    required this.destinationCoords,
    required this.distanceKm,
    required this.estimatedPrice,
    required this.onAddressInputChanged,
    required this.onSelectAddress,
    required this.onSelectPickupDate,
    required this.onSelectPickupTime,
    required this.onPassengersChanged,
    required this.onNavigateToRequestRide,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campos de ubicación
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            final pickupLabel = (l10n != null && !l10n.pickupLocation.startsWith('form.'))
                ? l10n.pickupLocation
                : 'Origen';
            return LocationInputField(
              label: pickupLabel,
              controller: pickupController,
              focusNode: pickupFocusNode,
              isPickup: true,
              activeInputType: activeInputType,
              autocompleteResults: autocompleteResults,
              onAddressInputChanged: onAddressInputChanged,
              onSelectAddress: onSelectAddress,
            );
          },
        ),
        const SizedBox(height: _kSpacing),
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            final dropoffLabel = (l10n != null && !l10n.dropoffLocation.startsWith('form.'))
                ? l10n.dropoffLocation
                : 'Destino';
            return LocationInputField(
              label: dropoffLabel,
              controller: dropoffController,
              focusNode: dropoffFocusNode,
              isPickup: false,
              activeInputType: activeInputType,
              autocompleteResults: autocompleteResults,
              onAddressInputChanged: onAddressInputChanged,
              onSelectAddress: onSelectAddress,
            );
          },
        ),
        const SizedBox(height: _kSpacing * 2),

        // Campos de fecha, hora y pasajeros
        Row(
          children: [
            // Fecha de recogida
            Expanded(
              child: DateField(pickupDate: pickupDate, onTap: onSelectPickupDate),
            ),
            const SizedBox(width: _kSpacing),
            // Hora de recogida
            Expanded(
              child: TimeField(timeController: timeController, onTap: onSelectPickupTime),
            ),
          ],
        ),
        const SizedBox(height: _kSpacing),
        // Número de pasajeros
        PassengersField(
          passengers: passengers,
          maxPassengers: maxPassengers,
          onChanged: onPassengersChanged,
        ),
        const SizedBox(height: _kSpacing * 2),

        // Campos de distancia y precio (si están disponibles)
        if (distanceKm != null || estimatedPrice != null) ...[
          Row(
            children: [
              if (distanceKm != null)
                Expanded(
                  child: InfoField(
                    label: 'Distancia',
                    value: '${distanceKm!.toStringAsFixed(2)} km',
                    icon: Icons.straighten,
                  ),
                ),
              if (distanceKm != null && estimatedPrice != null) const SizedBox(width: _kSpacing),
              if (estimatedPrice != null)
                Expanded(
                  child: InfoField(
                    label: 'Precio estimado',
                    value: '\$${estimatedPrice!.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                  ),
                ),
            ],
          ),
          const SizedBox(height: _kSpacing * 2),
        ],

        // Botón Ver precios
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onNavigateToRequestRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2), // Semi-transparente
              foregroundColor: Colors.white, // Texto blanco
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kBorderRadius),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ), // Borde blanco sutil
              ),
            ),
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                final seePricesText = (l10n != null && !l10n.seePrices.startsWith('form.'))
                    ? l10n.seePrices
                    : 'Ver precios';
                return Text(
                  seePricesText,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
