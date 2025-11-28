import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);

/// Item de resultado de autocompletado
/// Extraído de welcome_screen.dart
class AutocompleteItem extends StatelessWidget {
  final Map<String, dynamic> result;
  final String type;
  final VoidCallback onTap;

  const AutocompleteItem({
    super.key,
    required this.result,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = result['display_name'] as String;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.location_on, color: _kPrimaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: GoogleFonts.exo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // Blanco
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
