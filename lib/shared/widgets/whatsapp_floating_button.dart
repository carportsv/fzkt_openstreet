import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Widget reutilizable para el botón flotante de WhatsApp
/// que aparece en todas las pantallas principales
class WhatsAppFloatingButton extends StatelessWidget {
  /// Mensaje pre-cargado opcional para enviar por WhatsApp
  final String? prefilledMessage;

  const WhatsAppFloatingButton({super.key, this.prefilledMessage});

  /// Abre WhatsApp con el número configurado en env
  Future<void> _openWhatsApp(BuildContext context) async {
    try {
      // Verificar si dotenv está cargado
      if (dotenv.env.isEmpty) {
        if (context.mounted) {
          _showError(
            context,
            'Variables de entorno no cargadas. Asegúrate de tener el archivo "env" en la raíz del proyecto.',
          );
        }
        return;
      }

      // Obtener el número de WhatsApp desde variables de entorno
      final whatsappNumber = dotenv.env['WHATSAPP_NUMBER'] ?? '';

      if (whatsappNumber.isEmpty) {
        if (context.mounted) {
          _showError(
            context,
            'Número de WhatsApp no configurado en el archivo "env". Por favor, configura WHATSAPP_NUMBER.',
          );
        }
        return;
      }

      // Mensaje por defecto si no se proporciona uno
      final message = prefilledMessage ?? 'Hola, necesito información sobre mis reservas';

      // Construir la URL de WhatsApp
      // Formato: https://wa.me/NUMERO?text=MENSAJE
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$whatsappNumber?text=$encodedMessage';

      final uri = Uri.parse(whatsappUrl);

      // Verificar si se puede abrir la URL
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Abre en app externa
        );
      } else {
        if (context.mounted) {
          _showError(context, 'No se pudo abrir WhatsApp');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Error al abrir WhatsApp: $e');
      }
    }
  }

  /// Muestra un mensaje de error al usuario
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _openWhatsApp(context),
      backgroundColor: const Color(0xFF25D366), // Color verde oficial de WhatsApp
      elevation: 6,
      tooltip: 'Contactar por WhatsApp',
      child: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 28),
    );
  }
}
