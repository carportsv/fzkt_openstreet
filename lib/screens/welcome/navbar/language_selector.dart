import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Constants (copiadas de welcome_screen.dart)
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);

/// Widget para selector de idioma con banderas
/// Extraído de welcome_screen.dart
class LanguageSelectorWidget extends StatefulWidget {
  final String selectedLanguage;
  final Function(String) onLanguageChanged;

  const LanguageSelectorWidget({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<LanguageSelectorWidget> createState() => _LanguageSelectorWidgetState();
}

class _LanguageSelectorWidgetState extends State<LanguageSelectorWidget> {
  bool _isOpen = false;

  final Map<String, Map<String, String>> _languages = {
    'it': {'name': 'Italiano', 'flag': '🇮🇹'},
    'es': {'name': 'Español', 'flag': '🇪🇸'},
    'en': {'name': 'English', 'flag': '🇬🇧'},
    'de': {'name': 'Deutsch', 'flag': '🇩🇪'},
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isOpen) {
          setState(() => _isOpen = false);
        } else {
          _showLanguageMenu(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _languages[widget.selectedLanguage]!['flag']!,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  void _showLanguageMenu(BuildContext context) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        screenWidth - 200, // Posición desde la derecha
        offset.dy + size.height + 8,
        screenWidth - 20, // Ancho del menú
        offset.dy + size.height + 8 + 200, // Altura estimada
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 20,
      color: Colors.white,
      items: _languages.entries.map((entry) {
        final isSelected = entry.key == widget.selectedLanguage;
        return PopupMenuItem<String>(
          value: entry.key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(entry.value['flag']!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.value['name']!,
                  style: GoogleFonts.exo(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: _kTextColor,
                  ),
                ),
              ),
              if (isSelected) Icon(Icons.check, color: _kPrimaryColor, size: 18),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        widget.onLanguageChanged(value);
      }
    });
  }
}
