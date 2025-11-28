import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kBorderRadius = 12.0;

/// Campo de información (distancia/precio)
/// Extraído de welcome_screen.dart
class InfoField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const InfoField({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.3), width: 1.5),
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
            child: Icon(icon, color: _kPrimaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.exo(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.exo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
