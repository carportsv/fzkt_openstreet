import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget para elementos de navegación con efecto hover
/// Extraído de welcome_screen.dart
class HoverableNavItem extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const HoverableNavItem({super.key, required this.text, required this.onTap});

  @override
  State<HoverableNavItem> createState() => _HoverableNavItemState();
}

class _HoverableNavItemState extends State<HoverableNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _isHovered ? Colors.white : Colors.transparent, width: 2),
            ),
          ),
          child: Text(
            widget.text,
            style: GoogleFonts.exo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
