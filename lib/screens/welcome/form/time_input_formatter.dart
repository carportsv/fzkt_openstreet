import 'package:flutter/services.dart';

/// Formatter para input de hora (HH:mm)
/// Extraído de welcome_screen.dart
class TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    // Si está vacío, permitir
    if (text.isEmpty) {
      return newValue;
    }

    // Remover todo excepto números y dos puntos
    final cleaned = text.replaceAll(RegExp(r'[^0-9:]'), '');

    // Limitar a 5 caracteres (HH:mm)
    if (cleaned.length > 5) {
      return oldValue;
    }

    // Si solo hay números, formatear automáticamente
    if (!cleaned.contains(':')) {
      if (cleaned.length <= 2) {
        // Solo horas
        return TextEditingValue(
          text: cleaned,
          selection: TextSelection.collapsed(offset: cleaned.length),
        );
      } else if (cleaned.length <= 4) {
        // Horas y minutos sin dos puntos
        final hours = cleaned.substring(0, 2);
        final minutes = cleaned.substring(2);
        return TextEditingValue(
          text: '$hours:$minutes',
          selection: TextSelection.collapsed(offset: '$hours:$minutes'.length),
        );
      }
    }

    // Si ya tiene dos puntos, validar formato
    if (cleaned.contains(':')) {
      final parts = cleaned.split(':');
      if (parts.length > 2) {
        // Más de un dos puntos, mantener el valor anterior
        return oldValue;
      }

      String hours = parts[0];
      String minutes = parts.length > 1 ? parts[1] : '';

      // Validar horas (00-23)
      if (hours.isNotEmpty) {
        final hourInt = int.tryParse(hours);
        if (hourInt != null) {
          if (hourInt > 23) {
            hours = '23';
          } else if (hours.length > 2) {
            hours = hours.substring(0, 2);
          }
        } else {
          hours = '';
        }
      }

      // Validar minutos (00-59)
      if (minutes.isNotEmpty) {
        final minuteInt = int.tryParse(minutes);
        if (minuteInt != null) {
          if (minuteInt > 59) {
            minutes = '59';
          } else if (minutes.length > 2) {
            minutes = minutes.substring(0, 2);
          }
        } else {
          minutes = '';
        }
      }

      final formatted = minutes.isEmpty ? hours : '$hours:$minutes';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}
