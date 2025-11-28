import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kBorderRadius = 12.0;

/// Selector de pasajeros
/// Extraído de welcome_screen.dart
class PassengersField extends StatelessWidget {
  final int passengers;
  final int maxPassengers;
  final Function(int) onChanged;

  const PassengersField({
    super.key,
    required this.passengers,
    required this.maxPassengers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final passengersLabel = (l10n != null && !l10n.passengers.startsWith('form.'))
        ? l10n.passengers
        : 'Passengers';
    final passengerSingular = (l10n != null && !l10n.passenger.startsWith('form.'))
        ? l10n.passenger
        : 'pasajero';
    final passengerPlural = (l10n != null && !l10n.passengers.startsWith('form.'))
        ? l10n.passengers
        : 'pasajeros';
    final passengerText = passengers == 1 ? passengerSingular : passengerPlural;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), // Más transparente con fondo blanco
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(
          color: passengers > 0 ? _kPrimaryColor.withValues(alpha: 0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.people, color: _kPrimaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                passengersLabel,
                style: GoogleFonts.exo(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8), // Blanco
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$passengers $passengerText',
                style: GoogleFonts.exo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // Blanco
                ),
              ),
            ],
          ),
          const Spacer(),
          // Botón menos
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: passengers > 1 ? () => onChanged(passengers - 1) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: passengers > 1
                      ? _kPrimaryColor.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: passengers > 1
                        ? _kPrimaryColor.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.remove,
                  color: passengers > 1
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5), // Blanco
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Número de pasajeros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$passengers',
              style: GoogleFonts.exo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Blanco
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Botón más
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: passengers < maxPassengers ? () => onChanged(passengers + 1) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: passengers < maxPassengers
                      ? _kPrimaryColor.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: passengers < maxPassengers
                        ? _kPrimaryColor.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  color: passengers < maxPassengers
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5), // Blanco
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
