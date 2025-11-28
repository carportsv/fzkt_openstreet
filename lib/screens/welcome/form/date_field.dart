import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kBorderRadius = 12.0;

/// Campo de fecha
/// Extraído de welcome_screen.dart
class DateField extends StatelessWidget {
  final DateTime? pickupDate;
  final VoidCallback onTap;

  const DateField({super.key, required this.pickupDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final pickupDateLabel = (l10n != null && !l10n.pickupDate.startsWith('form.'))
        ? l10n.pickupDate
        : 'Pickup date';
    final dateText = pickupDate != null
        ? DateFormat('EEE, d MMM, yyyy', locale.languageCode).format(pickupDate!)
        : pickupDateLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15), // Más transparente con fondo blanco
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(
            color: pickupDate != null ? _kPrimaryColor.withValues(alpha: 0.3) : Colors.transparent,
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
              child: Icon(Icons.calendar_today, color: _kPrimaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      final label = (l10n != null && !l10n.pickupDate.startsWith('form.'))
                          ? l10n.pickupDate
                          : 'Pickup date';
                      return Text(
                        label,
                        style: GoogleFonts.exo(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8), // Blanco
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateText,
                    style: GoogleFonts.exo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: pickupDate != null
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6), // Blanco
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (pickupDate != null) Icon(Icons.check_circle, color: _kPrimaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
