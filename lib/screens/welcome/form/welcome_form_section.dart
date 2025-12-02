import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../l10n/app_localizations.dart';
import 'location_input_field.dart';
import 'date_field.dart';
import 'time_field.dart';
import 'passengers_field.dart';
import '../carousel/vehicle/vehicle_translations.dart';

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
  final String selectedVehicleType;
  final Function(String) onVehicleTypeChanged;
  final bool isGeocoding; // Estado de carga para geocodificación

  // Callbacks
  final Function(String, String) onAddressInputChanged;
  final Function(Map<String, dynamic>, String) onSelectAddress;
  final Function(String, String)? onGeocodeAddress; // Callback opcional para geocodificar
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
    required this.selectedVehicleType,
    required this.onVehicleTypeChanged,
    this.isGeocoding = false,
    required this.onAddressInputChanged,
    required this.onSelectAddress,
    this.onGeocodeAddress,
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
            final pickupLabel = l10n?.formOrigin ?? 'Origen';
            return LocationInputField(
              label: pickupLabel,
              controller: pickupController,
              focusNode: pickupFocusNode,
              isPickup: true,
              activeInputType: activeInputType,
              autocompleteResults: autocompleteResults,
              onAddressInputChanged: onAddressInputChanged,
              onSelectAddress: onSelectAddress,
              onGeocodeAddress: onGeocodeAddress,
            );
          },
        ),
        const SizedBox(height: _kSpacing),
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            final dropoffLabel = l10n?.formDestination ?? 'Destino';
            return LocationInputField(
              label: dropoffLabel,
              controller: dropoffController,
              focusNode: dropoffFocusNode,
              isPickup: false,
              activeInputType: activeInputType,
              autocompleteResults: autocompleteResults,
              onAddressInputChanged: onAddressInputChanged,
              onSelectAddress: onSelectAddress,
              onGeocodeAddress: onGeocodeAddress,
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
        const SizedBox(height: _kSpacing),
        // Selector de tipo de vehículo
        _buildVehicleSelection(),
        const SizedBox(height: _kSpacing * 2),

        // Botón Ver precios
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isGeocoding ? null : onNavigateToRequestRide,
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
                if (isGeocoding) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(
                            l10n?.commonGettingLocation ?? 'Buscando direcciones...',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ],
                  );
                }
                final l10n = AppLocalizations.of(context);
                return Text(
                  l10n?.seePrices ?? 'Ver precios',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelection() {
    final vehicles = [
      {
        'type': 'sedan',
        'name': 'Sedan',
        'passengers': 3,
        'handLuggage': 1,
        'checkInLuggage': 0,
        'icon': Icons.directions_car,
      },
      {
        'type': 'business',
        'name': 'Business',
        'passengers': 6,
        'handLuggage': 2,
        'checkInLuggage': 2,
        'icon': Icons.airport_shuttle,
      },
      {
        'type': 'van',
        'name': 'Minivan 7pax',
        'passengers': 8,
        'handLuggage': 3,
        'checkInLuggage': 4,
        'icon': Icons.local_shipping,
      },
      {
        'type': 'luxury',
        'name': 'Minivan Luxury 6pax',
        'passengers': 6,
        'handLuggage': 2,
        'checkInLuggage': 1,
        'icon': Icons.directions_car_filled,
      },
      {
        'type': 'minibus_8pax',
        'name': 'Minibus 8pax',
        'passengers': 8,
        'handLuggage': 4,
        'checkInLuggage': 6,
        'icon': Icons.airport_shuttle,
      },
      {
        'type': 'bus_16pax',
        'name': 'Bus 16pax',
        'passengers': 16,
        'handLuggage': 8,
        'checkInLuggage': 12,
        'icon': Icons.directions_bus,
      },
      {
        'type': 'bus_19pax',
        'name': 'Bus 19pax',
        'passengers': 19,
        'handLuggage': 10,
        'checkInLuggage': 15,
        'icon': Icons.directions_bus,
      },
      {
        'type': 'bus_50pax',
        'name': 'Bus 50pax',
        'passengers': 50,
        'handLuggage': 25,
        'checkInLuggage': 30,
        'icon': Icons.directions_bus_filled,
      },
    ];

    final selectedVehicle = vehicles.firstWhere(
      (v) => v['type'] == selectedVehicleType,
      orElse: () => vehicles[0],
    );

    return Container(
      padding: const EdgeInsets.all(_kSpacing),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.directions_car, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n?.formVehicleType ?? 'Tipo de Vehículo',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: _kSpacing),
          // Vehicle selector dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: selectedVehicleType,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.transparent,
                prefixIcon: Icon(selectedVehicle['icon'] as IconData, color: Colors.white),
              ),
              dropdownColor: Colors.white.withValues(alpha: 0.65),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              isExpanded: true,
              items: vehicles
                  .map(
                    (v) => DropdownMenuItem<String>(
                      value: v['type'] as String,
                      child: Builder(
                        builder: (context) {
                          final vehicleName = VehicleTranslations.getVehicleName(
                            v['type'] as String,
                            context,
                          );
                          return Row(
                            children: [
                              Icon(v['icon'] as IconData, color: Colors.black87, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  vehicleName,
                                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  onVehicleTypeChanged(val);
                }
              },
            ),
          ),
          const SizedBox(height: _kSpacing),
          // Selected vehicle details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Row(
                  children: [
                    Expanded(
                      child: _buildVehicleDetail(
                        icon: Icons.people,
                        label: l10n?.summaryPassengers ?? 'Pasajeros',
                        value: '${selectedVehicle['passengers']}',
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3)),
                    Expanded(
                      child: _buildVehicleDetail(
                        icon: Icons.luggage,
                        label: l10n?.summaryHandLuggage ?? 'Equipaje de mano',
                        value: '${selectedVehicle['handLuggage']}',
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3)),
                    Expanded(
                      child: _buildVehicleDetail(
                        icon: Icons.luggage_outlined,
                        label: l10n?.summaryCheckInLuggage ?? 'Equipaje facturado',
                        value: '${selectedVehicle['checkInLuggage']}',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
