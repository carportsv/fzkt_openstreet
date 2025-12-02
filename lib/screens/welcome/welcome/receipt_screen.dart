import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;
import '../../../l10n/app_localizations.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla para mostrar el recibo de pago
class ReceiptScreen extends StatelessWidget {
  final String receiptText;
  final String receiptNumber;
  final DateTime receiptDate;
  final double totalAmount;
  final String? originAddress;
  final String? destinationAddress;
  final String? vehicleType;
  final String? clientName;
  final String? clientEmail;
  final String? clientPhone;
  final double? distanceKm;
  final int? passengerCount;
  final int? childSeats;
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final String? paymentMethod;

  const ReceiptScreen({
    super.key,
    required this.receiptText,
    required this.receiptNumber,
    required this.receiptDate,
    required this.totalAmount,
    this.originAddress,
    this.destinationAddress,
    this.vehicleType,
    this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.distanceKm,
    this.passengerCount,
    this.childSeats,
    this.scheduledDate,
    this.scheduledTime,
    this.paymentMethod,
  });

  void _handlePrint() {
    if (kIsWeb) {
      // Generar HTML completo del recibo
      final htmlContent =
          '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Recibo de Pago - $receiptNumber</title>
  <style>
    @page {
      margin: 1cm;
    }
    body {
      font-family: Arial, sans-serif;
      margin: 0;
      padding: 20px;
      background: white;
      color: black;
    }
    .receipt-container {
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      background: white;
    }
    .receipt-header {
      display: flex;
      align-items: flex-start;
      margin-bottom: 30px;
    }
    .logo {
      width: 160px;
      height: 160px;
      margin-right: 20px;
    }
    .receipt-title {
      flex: 1;
    }
    .receipt-title h1 {
      font-size: 28px;
      font-weight: bold;
      color: #1D4ED8;
      margin: 0 0 8px 0;
      letter-spacing: 1.2px;
    }
    .receipt-title p {
      font-size: 16px;
      color: #666;
      margin: 0;
    }
    .receipt-number {
      padding: 10px 16px;
      background: #f0f4ff;
      border: 2px solid #1D4ED8;
      border-radius: 8px;
      text-align: right;
    }
    .receipt-number-label {
      font-size: 11px;
      font-weight: 600;
      color: #1D4ED8;
      margin-bottom: 4px;
    }
    .receipt-number-value {
      font-size: 14px;
      font-weight: bold;
      color: #1D4ED8;
    }
    .divider {
      border-top: 1px solid #ddd;
      margin: 20px 0;
    }
    .info-row {
      display: flex;
      margin-bottom: 12px;
    }
    .info-label {
      width: 140px;
      font-weight: 600;
      color: #666;
    }
    .info-value {
      flex: 1;
      color: #000;
    }
    .section-title {
      font-size: 16px;
      font-weight: bold;
      color: #1D4ED8;
      margin: 20px 0 12px 0;
      letter-spacing: 0.5px;
    }
    .success-value {
      font-weight: bold;
      color: #15803d;
    }
    .center-text {
      text-align: center;
      margin-top: 30px;
    }
    .center-text h2 {
      font-size: 18px;
      font-weight: bold;
      color: #1D4ED8;
      margin: 0 0 8px 0;
    }
    .center-text p {
      font-size: 14px;
      color: #666;
      margin: 0;
    }
  </style>
</head>
<body>
  <div class="receipt-container">
    <div class="receipt-header">
      <img src="assets/images/logo_21.png" alt="Logo" class="logo" onerror="this.style.display='none'">
      <div class="receipt-title">
        <h1>RECIBO DE PAGO</h1>
        <p>Servicio de Transporte</p>
      </div>
      <div class="receipt-number">
        <div class="receipt-number-label">Nº Recibo</div>
        <div class="receipt-number-value">$receiptNumber</div>
      </div>
    </div>
    
    <div class="divider"></div>
    
    <div class="info-row">
      <div class="info-label">Fecha:</div>
      <div class="info-value">${DateFormat('dd/MM/yyyy').format(receiptDate)}</div>
      <div class="info-label" style="margin-left: 40px;">Hora:</div>
      <div class="info-value">${DateFormat('HH:mm').format(receiptDate)}</div>
    </div>
    
    <div class="divider"></div>
    
    <div class="section-title">DETALLES DEL VIAJE</div>
    ${originAddress != null ? '<div class="info-row"><div class="info-label">Origen:</div><div class="info-value">$originAddress</div></div>' : ''}
    ${destinationAddress != null ? '<div class="info-row"><div class="info-label">Destino:</div><div class="info-value">$destinationAddress</div></div>' : ''}
    ${distanceKm != null ? '<div class="info-row"><div class="info-label">Distancia:</div><div class="info-value">${distanceKm!.toStringAsFixed(2)} km</div></div>' : ''}
    ${vehicleType != null ? '<div class="info-row"><div class="info-label">Tipo de Vehículo:</div><div class="info-value">$vehicleType</div></div>' : ''}
    ${passengerCount != null ? '<div class="info-row"><div class="info-label">Pasajeros:</div><div class="info-value">$passengerCount</div></div>' : ''}
    ${childSeats != null && childSeats! > 0 ? '<div class="info-row"><div class="info-label">Asientos para Niños:</div><div class="info-value">$childSeats</div></div>' : ''}
    ${scheduledDate != null || scheduledTime != null ? '<div class="info-row"><div class="info-label">Fecha y Hora Programada:</div><div class="info-value">${scheduledDate != null ? DateFormat('dd/MM/yyyy').format(scheduledDate!) : "N/A"} ${scheduledTime ?? ""}</div></div>' : ''}
    
    ${clientName != null || clientEmail != null || clientPhone != null ? '<div class="divider"></div><div class="section-title">INFORMACIÓN DEL CLIENTE</div>' : ''}
    ${clientName != null ? '<div class="info-row"><div class="info-label">Nombre:</div><div class="info-value">$clientName</div></div>' : ''}
    ${clientEmail != null ? '<div class="info-row"><div class="info-label">Email:</div><div class="info-value">$clientEmail</div></div>' : ''}
    ${clientPhone != null ? '<div class="info-row"><div class="info-label">Teléfono:</div><div class="info-value">$clientPhone</div></div>' : ''}
    
    <div class="divider"></div>
    
    <div class="section-title">RESUMEN DE PAGO</div>
    <div class="info-row"><div class="info-label">Subtotal:</div><div class="info-value">€${totalAmount.toStringAsFixed(2)}</div></div>
    <div class="info-row"><div class="info-label">Total:</div><div class="info-value">€${totalAmount.toStringAsFixed(2)}</div></div>
    <div class="info-row" style="margin-top: 12px;"><div class="info-label">Método de Pago:</div><div class="info-value">${_getPaymentMethodDisplay()}</div></div>
    <div class="info-row"><div class="info-label">Estado:</div><div class="info-value success-value">Pagado</div></div>
    
    <div class="divider"></div>
    
    <div class="center-text">
      <h2>¡Gracias por su compra!</h2>
      <p>Esperamos servirle nuevamente</p>
    </div>
  </div>
  
  <script>
    window.onload = function() {
      window.print();
      window.onafterprint = function() {
        window.close();
      };
    };
  </script>
</body>
</html>
        ''';

      // Usar data URI con codificación mejorada
      // Dividir el HTML en partes más pequeñas si es necesario para evitar límites de URL
      final encodedContent = Uri.encodeComponent(htmlContent);
      final dataUri = 'data:text/html;charset=utf-8,$encodedContent';

      try {
        final printWindow = web.window.open(dataUri, '_blank');
        if (printWindow != null) {
          // Esperar a que la ventana cargue completamente antes de imprimir
          Future.delayed(const Duration(milliseconds: 1000), () {
            try {
              printWindow.print();
              // Cerrar la ventana después de un tiempo
              Future.delayed(const Duration(seconds: 3), () {
                try {
                  printWindow.close();
                } catch (e) {
                  // Ignorar errores al cerrar
                }
              });
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[ReceiptScreen] Error al imprimir: $e');
              }
            }
          });
        } else {
          // Si no se puede abrir la ventana, mostrar mensaje
          if (kDebugMode) {
            debugPrint('[ReceiptScreen] No se pudo abrir la ventana de impresión');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptScreen] Error al crear ventana de impresión: $e');
        }
      }
    } else {
      // Para móvil, mostrar mensaje
      // todo: Implementar impresión nativa para móvil si es necesario
    }
  }

  void _handleEmail() {
    if (kIsWeb) {
      // Opción simple: usar mailto: para abrir el cliente de correo
      final subject = Uri.encodeComponent('Recibo de Pago - $receiptNumber');
      final body = Uri.encodeComponent(receiptText);
      final email = clientEmail ?? '';

      if (email.isNotEmpty) {
        final mailtoLink = 'mailto:$email?subject=$subject&body=$body';
        web.window.open(mailtoLink, '_blank');
      } else {
        // Si no hay email, mostrar mensaje
        // todo: Implementar backend para envío automático
        // Ver docs/EMAIL_IMPLEMENTATION.md para más detalles
        if (kIsWeb) {
          // Mostrar mensaje usando showDialog o SnackBar
          // Por ahora, solo abrimos mailto sin email específico
          final mailtoLink = 'mailto:?subject=$subject&body=$body';
          web.window.open(mailtoLink, '_blank');
        }
      }
    } else {
      // Para móvil, usar url_launcher o share_plus
      // todo: Implementar usando url_launcher o share_plus
      // Ver docs/EMAIL_IMPLEMENTATION.md para más detalles
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.close, color: _kTextColor),
          ),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: Text(
          'Recibo de Pago',
          style: GoogleFonts.exo(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextColor),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.email, color: _kPrimaryColor),
            ),
            onPressed: _handleEmail,
            tooltip: 'Enviar por correo',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.print, color: _kPrimaryColor),
            ),
            onPressed: _handlePrint,
            tooltip: 'Imprimir',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header con éxito (no se imprime)
            Container(
              key: const ValueKey('success-header'),
              padding: const EdgeInsets.all(_kSpacing * 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(_kBorderRadius),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: _kSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Pago Exitoso!',
                          style: GoogleFonts.exo(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Su pago ha sido procesado correctamente',
                          style: GoogleFonts.exo(fontSize: 14, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _kSpacing * 2),

            // Recibo profesional
            Container(
              key: const ValueKey('receipt-container'),
              padding: const EdgeInsets.all(_kSpacing * 2.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_kBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildProfessionalReceipt(),
            ),
            const SizedBox(height: _kSpacing * 2),

            // Botones de acción (no se imprimen)
            Row(
              key: const ValueKey('action-buttons'),
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: receiptText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              const Text('Recibo copiado al portapapeles'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_kBorderRadius),
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kBorderRadius),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy, color: Colors.grey.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Copiar Recibo',
                          style: GoogleFonts.exo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _kSpacing),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kBorderRadius),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.home, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Volver al Inicio',
                          style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalReceipt() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con logo y número de recibo
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo (más grande para mejor legibilidad)
            Image.asset('assets/images/logo_21.png', width: 160, height: 160, fit: BoxFit.contain),
            const SizedBox(width: _kSpacing * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECIBO DE PAGO',
                    style: GoogleFonts.exo(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _kPrimaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Servicio de Transporte',
                    style: GoogleFonts.exo(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Número de recibo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kPrimaryColor, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Nº Recibo',
                    style: GoogleFonts.exo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    receiptNumber,
                    style: GoogleFonts.exo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: _kSpacing * 2),
        Divider(color: Colors.grey.shade300, thickness: 1),
        const SizedBox(height: _kSpacing * 2),

        // Información de fecha y hora
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoItem('Fecha', dateFormat.format(receiptDate)),
            _buildInfoItem('Hora', timeFormat.format(receiptDate)),
          ],
        ),

        const SizedBox(height: _kSpacing * 2),
        Divider(color: Colors.grey.shade300, thickness: 1),
        const SizedBox(height: _kSpacing * 2),

        // Detalles del viaje
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Column(
              children: [
                _buildSectionTitle(l10n?.receiptTripDetails ?? 'DETALLES DEL VIAJE'),
                const SizedBox(height: _kSpacing),
                if (originAddress != null)
                  _buildDetailRow(l10n?.summaryOrigin ?? 'Origen', originAddress!),
                if (destinationAddress != null)
                  _buildDetailRow(l10n?.summaryDestination ?? 'Destino', destinationAddress!),
                if (distanceKm != null)
                  _buildDetailRow(
                    l10n?.summaryDistance ?? 'Distancia',
                    '${distanceKm!.toStringAsFixed(2)} km',
                  ),
                if (vehicleType != null)
                  _buildDetailRow(l10n?.formVehicleType ?? 'Tipo de Vehículo', vehicleType!),
                if (passengerCount != null)
                  _buildDetailRow(
                    l10n?.summaryPassengers ?? 'Pasajeros',
                    passengerCount.toString(),
                  ),
                if (childSeats != null && childSeats! > 0)
                  _buildDetailRow(
                    l10n?.summaryChildSeats ?? 'Asientos para Niños',
                    childSeats.toString(),
                  ),
              ],
            );
          },
        ),
        if (scheduledDate != null || scheduledTime != null) ...[
          const SizedBox(height: _kSpacing),
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return _buildDetailRow(
                l10n?.receiptScheduledDateTime ?? 'Fecha y Hora Programada',
                '${scheduledDate != null ? dateFormat.format(scheduledDate!) : "N/A"} ${scheduledTime != null ? scheduledTime! : ""}',
              );
            },
          ),
        ],

        const SizedBox(height: _kSpacing * 2),
        Divider(color: Colors.grey.shade300, thickness: 1),
        const SizedBox(height: _kSpacing * 2),

        // Información del cliente
        if (clientName != null || clientEmail != null || clientPhone != null) ...[
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Column(
                children: [
                  _buildSectionTitle(l10n?.receiptClientInfo ?? 'INFORMACIÓN DEL CLIENTE'),
                  const SizedBox(height: _kSpacing),
                  if (clientName != null)
                    _buildDetailRow(l10n?.receiptName ?? 'Nombre', clientName!),
                  if (clientEmail != null)
                    _buildDetailRow(l10n?.receiptEmail ?? 'Email', clientEmail!),
                  if (clientPhone != null)
                    _buildDetailRow(l10n?.receiptPhone ?? 'Teléfono', clientPhone!),
                ],
              );
            },
          ),
          const SizedBox(height: _kSpacing * 2),
          Divider(color: Colors.grey.shade300, thickness: 1),
          const SizedBox(height: _kSpacing * 2),
        ],

        // Resumen de pago
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Column(
              children: [
                _buildSectionTitle(l10n?.receiptPaymentSummary ?? 'RESUMEN DE PAGO'),
                const SizedBox(height: _kSpacing),
                _buildDetailRow(
                  l10n?.receiptSubtotal ?? 'Subtotal',
                  '€${totalAmount.toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  l10n?.receiptTotal ?? 'Total',
                  '€${totalAmount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: _kSpacing),
                _buildDetailRow(
                  l10n?.summaryPaymentMethod ?? 'Método de Pago',
                  _getPaymentMethodDisplay(),
                ),
                _buildDetailRow(
                  l10n?.receiptStatus ?? 'Estado',
                  l10n?.receiptPaid ?? 'Pagado',
                  isSuccess: true,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: _kSpacing * 2),
        Divider(color: Colors.grey.shade300, thickness: 1),
        const SizedBox(height: _kSpacing * 2),

        // Mensaje de agradecimiento
        Center(
          child: Column(
            children: [
              Text(
                '¡Gracias por su compra!',
                style: GoogleFonts.exo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Esperamos servirle nuevamente',
                style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.exo(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _kPrimaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: GoogleFonts.exo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.exo(
                fontSize: 14,
                fontWeight: isSuccess ? FontWeight.bold : FontWeight.normal,
                color: isSuccess ? Colors.green.shade700 : _kTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.exo(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.exo(fontSize: 14, fontWeight: FontWeight.bold, color: _kTextColor),
        ),
      ],
    );
  }

  String _getPaymentMethodDisplay() {
    if (paymentMethod == null || paymentMethod!.isEmpty) {
      return 'Tarjeta';
    }

    switch (paymentMethod!.toLowerCase()) {
      case 'card':
      case 'tarjeta':
        return 'Tarjeta';
      case 'paypal':
        return 'PayPal';
      case 'cash':
      case 'efectivo':
        return 'Efectivo';
      case 'bank_transfer':
      case 'transferencia':
        return 'Transferencia Bancaria';
      default:
        return paymentMethod!;
    }
  }
}
