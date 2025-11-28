import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';
import 'time_input_formatter.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kBorderRadius = 12.0;

/// Campo de hora
/// Extraído de welcome_screen.dart
class TimeField extends StatelessWidget {
  final TextEditingController timeController;
  final VoidCallback onTap;

  const TimeField({super.key, required this.timeController, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timePlaceholder = (l10n != null && !l10n.timePlaceholder.startsWith('form.'))
        ? l10n.timePlaceholder
        : 'HH:mm (ej: 08:30)';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), // Más transparente con fondo blanco
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(
          color: timeController.text.isNotEmpty
              ? _kPrimaryColor.withValues(alpha: 0.3)
              : Colors.transparent,
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
            child: Icon(Icons.access_time, color: _kPrimaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: timeController,
              style: GoogleFonts.exo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ), // Blanco
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                TimeInputFormatter(),
              ],
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: timePlaceholder,
                hintStyle: GoogleFonts.exo(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ), // Blanco
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.access_time, color: _kPrimaryColor, size: 20),
            onPressed: onTap,
            tooltip: 'Seleccionar hora',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
