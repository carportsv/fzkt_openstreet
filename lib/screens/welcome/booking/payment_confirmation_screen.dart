import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart' as qr;
import '../../../auth/login_screen.dart';
import '../../../services/ride_service.dart';
import '../../../services/paypal_service.dart';
import '../../../services/stripe_service.dart';
import '../../../l10n/app_localizations.dart';
import 'receipt_screen.dart';
import '../../../shared/widgets/whatsapp_floating_button.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/web_redirect_helper.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla para confirmar datos de tarjeta y procesar el pago
class PaymentConfirmationScreen extends StatefulWidget {
  final String originAddress;
  final String destinationAddress;
  final String? flightNumber;
  final double price;
  final double? distanceKm;
  final String clientName;
  final String? clientEmail;
  final String? clientPhone;
  final LatLng? originCoords;
  final LatLng? destinationCoords;
  final String priority;
  final String vehicleType;
  final int passengerCount;
  final int childSeats;
  final int handLuggage;
  final int checkInLuggage;
  final String? notes;
  final DateTime? scheduledDateTime;

  const PaymentConfirmationScreen({
    super.key,
    required this.originAddress,
    required this.destinationAddress,
    this.flightNumber,
    required this.price,
    this.distanceKm,
    required this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.originCoords,
    this.destinationCoords,
    required this.priority,
    required this.vehicleType,
    required this.passengerCount,
    this.childSeats = 0,
    this.handLuggage = 0,
    this.checkInLuggage = 0,
    this.notes,
    this.scheduledDateTime,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Card Controllers
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardNameController = TextEditingController();

  // State
  bool _isProcessing = false;
  String? _paymentError;
  StreamSubscription<User?>? _authSubscription;

  // Estado de PayPal
  String? _paypalApprovalUrl;
  String _selectedPaymentMethod = 'card'; // 'card', 'paypal', 'apple_pay', 'google_pay'
  String? _cardType; // 'visa', 'mastercard', null

  final RideService _rideService = RideService();

  @override
  void initState() {
    super.initState();
    // Manejar retorno de Stripe Checkout (solo en web)
    if (kIsWeb) {
      _handleStripeReturn();
    }
  }

  /// Maneja el retorno de Stripe Checkout
  void _handleStripeReturn() {
    // Detectar si el usuario regresó de Stripe Checkout
    final uri = Uri.base;

    if (uri.path.contains('/payment/success') || uri.queryParameters.containsKey('session_id')) {
      final sessionId = uri.queryParameters['session_id'];
      if (sessionId != null && sessionId.isNotEmpty) {
        // Verificar el pago en segundo plano
        _verifyStripePayment(sessionId);
      }
    } else if (uri.path.contains('/payment/cancel')) {
      // Usuario canceló el pago
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago cancelado. Puedes intentar nuevamente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardNameController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius * 2)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(_kBorderRadius * 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(_kSpacing * 2),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _kPrimaryColor.withValues(alpha: 0.15),
                      _kPrimaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2), width: 2),
                ),
                child: Icon(Icons.person_add_alt_1, size: 40, color: _kPrimaryColor),
              ),
              const SizedBox(height: _kSpacing * 2),
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n?.accountRequired ?? 'Cuenta requerida',
                    style: GoogleFonts.exo(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _kTextColor,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: _kSpacing),
              Text(
                'Necesitas iniciar sesión o crear una cuenta para procesar el pago.',
                style: GoogleFonts.exo(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _kSpacing * 2.5),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_kBorderRadius),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                      ),
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(
                            l10n?.cancel ?? 'Cancelar',
                            style: GoogleFonts.exo(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: _kSpacing),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _navigateToLogin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: _kPrimaryColor.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_kBorderRadius),
                        ),
                      ),
                      child: Text(
                        'Iniciar sesión / Crear cuenta',
                        style: GoogleFonts.exo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (kDebugMode) {
      debugPrint('[PaymentConfirmationScreen] 💳 Iniciando procesamiento de pago...');
      debugPrint('[PaymentConfirmationScreen] Método seleccionado: $_selectedPaymentMethod');
      debugPrint('[PaymentConfirmationScreen] Es web: $kIsWeb');
    }

    // Validar formulario solo si se selecciona tarjeta Y estamos en móvil
    // En web, no hay campos del formulario, así que no validamos
    if (_selectedPaymentMethod == 'card' && !kIsWeb) {
      if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
        if (kDebugMode) {
          debugPrint('[PaymentConfirmationScreen] ❌ Validación del formulario falló');
        }
        return;
      }
    }

    // Verificar autenticación
    User? firebaseUser;
    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PaymentConfirmationScreen] ⚠️ Error obteniendo usuario: $e');
      }
      firebaseUser = null;
    }

    if (firebaseUser == null) {
      _showAuthRequiredDialog();
      return;
    }

    setState(() {
      _isProcessing = true;
      _paymentError = null;
    });

    try {
      // Preparar datos del viaje
      final rideData = CreateRideData(
        originAddress: widget.originAddress,
        destinationAddress: widget.destinationAddress,
        price: widget.price,
        clientName: widget.clientName,
        originCoords: widget.originCoords,
        destinationCoords: widget.destinationCoords,
        distanceKm: widget.distanceKm,
        priority: widget.priority,
        vehicleType: widget.vehicleType,
        passengerCount: widget.passengerCount,
        childSeats: widget.childSeats,
        handLuggage: widget.handLuggage,
        checkInLuggage: widget.checkInLuggage,
        paymentMethod:
            (_selectedPaymentMethod == 'apple_pay' || _selectedPaymentMethod == 'google_pay')
            ? 'wallet'
            : _selectedPaymentMethod,
        clientEmail: widget.clientEmail,
        clientPhone: widget.clientPhone,
        notes: widget.notes,
        scheduledDateTime: widget.scheduledDateTime,
        // En web con Stripe Checkout, no tenemos datos de tarjeta (el usuario los ingresará en Stripe)
        // En móvil, sí necesitamos los datos para Payment Sheet
        cardNumber: (_selectedPaymentMethod == 'card' && !kIsWeb)
            ? _cardNumberController.text.trim()
            : '',
        cardExpiry: (_selectedPaymentMethod == 'card' && !kIsWeb)
            ? _cardExpiryController.text.trim()
            : '',
        cardName: (_selectedPaymentMethod == 'card' && !kIsWeb)
            ? _cardNameController.text.trim()
            : '',
      );

      // Procesar pago con Stripe si es tarjeta
      String? paymentIntentId;
      if (_selectedPaymentMethod == 'card') {
        // En web, usar Stripe Checkout (NO requiere Raw Card Data APIs)
        // En móvil, usar Payment Sheet (ya funciona)
        if (kIsWeb) {
          // Usar Stripe Checkout para web
          await _processStripeCheckout(rideData);
          return; // El método maneja la redirección, no continuamos aquí
        } else {
          // En móvil, usar el método actual con Payment Sheet
          // (Este código ya funciona y no necesita cambios)
        }

        // Validar datos de tarjeta (solo para móvil, web no necesita)
        if (!kIsWeb) {
          final cardValidation = StripeService.validateCardData(
            number: _cardNumberController.text.trim(),
            expMonth: _cardExpiryController.text.split('/').isNotEmpty
                ? _cardExpiryController.text.split('/')[0].trim()
                : '',
            expYear: _cardExpiryController.text.split('/').length > 1
                ? '20${_cardExpiryController.text.split('/')[1].trim()}'
                : '',
            cvc: _cardCvvController.text.trim(),
          );

          if (!(cardValidation['isValid'] as bool)) {
            final errors = cardValidation['errors'] as List<dynamic>;
            setState(() {
              _isProcessing = false;
              _paymentError = errors.join(', ');
            });
            return;
          }
        }

        // Crear el viaje primero para obtener el rideId
        String rideId;
        try {
          rideId = await _rideService.createRideRequest(rideData);
        } catch (e) {
          setState(() {
            _isProcessing = false;
            _paymentError = 'Error al crear el viaje: ${e.toString()}';
          });
          return;
        }

        // Crear Payment Intent (HOLD - autorización)
        final paymentIntent = await StripeService.createPaymentIntent(
          rideId: rideId,
          amount: widget.price,
          currency: 'usd',
        );

        if (paymentIntent == null) {
          setState(() {
            _isProcessing = false;
            _paymentError = 'Error al procesar el pago. Verifica tus datos e intenta nuevamente.';
          });
          return;
        }

        // Confirmar Payment Intent usando Payment Sheet (móvil)
        // En web, esto no se ejecuta porque usamos Checkout
        final confirmationResult = await StripeService.confirmPaymentIntentWithCard(
          clientSecret: paymentIntent.clientSecret,
          currency: paymentIntent.currency,
          cardholderName: _cardNameController.text.trim().isNotEmpty
              ? _cardNameController.text.trim()
              : null,
          // Datos de tarjeta para móvil (Payment Sheet los maneja internamente)
          cardNumber: _cardNumberController.text.trim(),
          expMonth: _cardExpiryController.text.split('/').isNotEmpty
              ? _cardExpiryController.text.split('/')[0].trim()
              : null,
          expYear: _cardExpiryController.text.split('/').length > 1
              ? '20${_cardExpiryController.text.split('/')[1].trim()}'
              : null,
          cvc: _cardCvvController.text.trim(),
        );

        if (!(confirmationResult['success'] as bool)) {
          final errorMessage = confirmationResult['error'] as String?;
          final status = confirmationResult['status'] as String?;

          if (kDebugMode) {
            debugPrint('[PaymentConfirmationScreen] ❌ Error confirmando pago:');
            debugPrint('  - Mensaje: $errorMessage');
            debugPrint('  - Estado: $status');
          }

          setState(() {
            _isProcessing = false;
            _paymentError = errorMessage ?? 'Error al procesar el pago. Intenta nuevamente.';
          });
          return;
        }

        paymentIntentId = paymentIntent.id;

        if (kDebugMode) {
          debugPrint('[PaymentConfirmationScreen] ✅ Payment Intent confirmado: $paymentIntentId');
          debugPrint('[PaymentConfirmationScreen] 📊 Estado: ${confirmationResult['status']}');
          debugPrint('[PaymentConfirmationScreen] 💡 El pago se procesará al finalizar el viaje');
        }

        // Actualizar el viaje con el payment_intent_id y estado 'authorized'
        try {
          await _rideService.updateRidePaymentStatus(
            rideId: rideId,
            paymentIntentId: paymentIntentId,
            paymentStatus: 'authorized',
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PaymentConfirmationScreen] ⚠️ Error actualizando estado de pago: $e');
          }
          // No bloquear el flujo si falla la actualización
        }
      } else {
        // Para otros métodos de pago (PayPal, efectivo, etc.), crear el viaje normalmente
        await _rideService.createRideRequest(rideData);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Generar recibo
        final l10n = AppLocalizations.of(context);
        final receipt = _generateReceiptText(l10n);
        final receiptNumber = 'REC-${DateTime.now().millisecondsSinceEpoch}';
        final now = DateTime.now();

        // Navegar a la pantalla de recibo
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ReceiptScreen(
                receiptText: receipt,
                receiptNumber: receiptNumber,
                receiptDate: now,
                totalAmount: widget.price,
                originAddress: widget.originAddress,
                destinationAddress: widget.destinationAddress,
                flightNumber: widget.flightNumber,
                vehicleType: widget.vehicleType,
                clientName: widget.clientName,
                clientEmail: widget.clientEmail,
                clientPhone: widget.clientPhone,
                distanceKm: widget.distanceKm,
                passengerCount: widget.passengerCount,
                childSeats: widget.childSeats,
                handLuggage: widget.handLuggage,
                checkInLuggage: widget.checkInLuggage,
                scheduledDate: widget.scheduledDateTime,
                scheduledTime: widget.scheduledDateTime != null
                    ? DateFormat('HH:mm').format(widget.scheduledDateTime!)
                    : null,
                paymentMethod:
                    (_selectedPaymentMethod == 'apple_pay' ||
                        _selectedPaymentMethod == 'google_pay')
                    ? 'wallet'
                    : _selectedPaymentMethod,
                notes: widget.notes,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PaymentConfirmationScreen] Error procesando pago: $e');
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
          final l10n = AppLocalizations.of(context);
          _paymentError = e is Exception
              ? e.toString().replaceAll('Exception: ', '')
              : l10n?.paymentUnknownError ?? 'Error desconocido al procesar el pago';
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n?.paymentProcessingError ?? 'Error al procesar el pago'}: ${_paymentError ?? l10n?.paymentUnknownError ?? 'Error desconocido'}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _generateReceiptText(AppLocalizations? l10n) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();
    final receiptNumber = 'REC-${now.millisecondsSinceEpoch}';

    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('          ${l10n?.paymentTripSummary ?? 'RECIBO DE PAGO'}');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('${l10n?.receiptNumber ?? 'Número de Recibo'}: $receiptNumber');
    buffer.writeln('${l10n?.receiptDate ?? 'Fecha'}: ${dateFormat.format(now)}');
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('          ${l10n?.receiptTripDetails ?? 'DETALLES DEL VIAJE'}');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('${l10n?.summaryOrigin ?? 'Origen'}: ${widget.originAddress}');
    buffer.writeln('${l10n?.summaryDestination ?? 'Destino'}: ${widget.destinationAddress}');
    if (widget.flightNumber != null && widget.flightNumber!.isNotEmpty) {
      buffer.writeln('${l10n?.summaryFlightNumber ?? 'Número de vuelo'}: ${widget.flightNumber}');
    }
    if (widget.distanceKm != null) {
      buffer.writeln(
        '${l10n?.summaryDistance ?? 'Distancia'}: ${widget.distanceKm!.toStringAsFixed(2)} km',
      );
    }
    buffer.writeln('${l10n?.formVehicleType ?? 'Tipo de Vehículo'}: ${widget.vehicleType}');
    buffer.writeln('${l10n?.summaryPassengers ?? 'Pasajeros'}: ${widget.passengerCount}');
    if (widget.childSeats > 0) {
      buffer.writeln('${l10n?.summaryChildSeats ?? 'Asientos para niños'}: ${widget.childSeats}');
    }
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('          ${l10n?.receiptClientInfo ?? 'INFORMACIÓN DEL CLIENTE'}');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('${l10n?.receiptName ?? 'Nombre'}: ${widget.clientName}');
    if (widget.clientEmail != null && widget.clientEmail!.isNotEmpty) {
      buffer.writeln('${l10n?.receiptEmail ?? 'Email'}: ${widget.clientEmail}');
    }
    if (widget.clientPhone != null && widget.clientPhone!.isNotEmpty) {
      buffer.writeln('${l10n?.receiptPhone ?? 'Teléfono'}: ${widget.clientPhone}');
    }
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('          ${l10n?.receiptPaymentSummary ?? 'RESUMEN DE PAGO'}');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('${l10n?.receiptSubtotal ?? 'Subtotal'}: \$${widget.price.toStringAsFixed(2)}');
    buffer.writeln('${l10n?.receiptTotal ?? 'Total'}: \$${widget.price.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln(
      '${l10n?.summaryPaymentMethod ?? 'Método de Pago'}: ${l10n?.paymentCard ?? 'Tarjeta'}',
    );
    buffer.writeln('${l10n?.receiptStatus ?? 'Estado'}: ${l10n?.receiptPaid ?? 'Pagado'}');
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('          ${l10n?.receiptThankYou ?? '¡Gracias por su compra!'}');
    buffer.writeln('═══════════════════════════════════════');

    return buffer.toString();
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
            child: Icon(Icons.arrow_back, color: _kTextColor),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Text(
              l10n?.paymentConfirmPayment ?? 'Confirmar Pago',
              style: GoogleFonts.exo(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextColor),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: _kSpacing * 2),
            // Resumen del viaje
            _buildTripSummary(),
            const SizedBox(height: _kSpacing * 2),
            // Selector de método de pago
            _buildPaymentMethodSelector(),
            const SizedBox(height: _kSpacing * 2),
            // Formulario de tarjeta (solo si se selecciona tarjeta)
            if (_selectedPaymentMethod == 'card') _buildCardForm(),
            // Información PayPal (solo si se selecciona PayPal)
            if (_selectedPaymentMethod == 'paypal') _buildPayPalInfo(),
            // Información Apple Pay / Google Pay (solo si se selecciona)
            if (_selectedPaymentMethod == 'apple_pay' || _selectedPaymentMethod == 'google_pay')
              _buildWalletInfo(),
            if (_paymentError != null) ...[const SizedBox(height: _kSpacing), _buildErrorBanner()],
            const SizedBox(height: _kSpacing * 2),
            // Botones de acción
            _buildActionButtons(),
          ],
        ),
      ),
      floatingActionButton: WhatsAppFloatingButton(prefilledMessage: _buildWhatsAppMessage()),
    );
  }

  /// Construye un mensaje personalizado para WhatsApp con info del viaje
  String _buildWhatsAppMessage() {
    final l10n = AppLocalizations.of(context);
    return '${l10n?.whatsappMessagePaymentHelp ?? "Hola, necesito ayuda con mi pago"}:\n'
        '${l10n?.whatsappLabelOrigin ?? "Origen"}: ${widget.originAddress}\n'
        '${l10n?.whatsappLabelDestination ?? "Destino"}: ${widget.destinationAddress}\n'
        '${l10n?.whatsappLabelAmount ?? "Precio"}: €${widget.price.toStringAsFixed(2)}';
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(_kSpacing * 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.payment, color: _kPrimaryColor, size: 28),
          ),
          const SizedBox(width: _kSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n?.paymentConfirmPayment ?? 'Confirmar Pago',
                      style: GoogleFonts.exo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _kTextColor,
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n?.paymentEnterCardDetails ??
                          'Ingrese los datos de su tarjeta para completar el pago',
                      style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSummary() {
    // Obtener información detallada del vehículo
    final vehicleInfo = _getVehicleInfo(widget.vehicleType);

    // Formatear fecha y hora
    String? formattedDateTime;
    if (widget.scheduledDateTime != null) {
      formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(widget.scheduledDateTime!);
    }

    return Container(
      padding: const EdgeInsets.all(_kSpacing * 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Text(
                l10n?.paymentTripSummary ?? 'Resumen del Viaje',
                style: GoogleFonts.exo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kTextColor,
                ),
              );
            },
          ),
          const SizedBox(height: _kSpacing),
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Column(
                children: [
                  _buildSummaryRow(l10n?.summaryOrigin ?? 'Origen', widget.originAddress),
                  _buildSummaryRow(
                    l10n?.summaryDestination ?? 'Destino',
                    widget.destinationAddress,
                  ),
                  if (widget.flightNumber != null && widget.flightNumber!.isNotEmpty)
                    _buildSummaryRow(
                      l10n?.summaryFlightNumber ?? 'Número de vuelo',
                      widget.flightNumber!,
                    ),
                  if (widget.distanceKm != null)
                    _buildSummaryRow(
                      l10n?.summaryDistance ?? 'Distancia',
                      '${widget.distanceKm!.toStringAsFixed(2)} km',
                    ),
                ],
              );
            },
          ),
          // Tipo de Vehículo en una sola fila con información detallada
          Padding(
            padding: const EdgeInsets.only(bottom: _kSpacing / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 180,
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.formVehicleType ?? 'Tipo de Vehículo',
                        style: GoogleFonts.exo(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          vehicleInfo['name'] ?? widget.vehicleType,
                          style: GoogleFonts.exo(
                            fontSize: 14,
                            color: _kTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${vehicleInfo['passengers']}',
                            style: GoogleFonts.exo(fontSize: 13, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.luggage, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${vehicleInfo['handLuggage']}',
                            style: GoogleFonts.exo(fontSize: 13, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.luggage_outlined, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${vehicleInfo['checkInLuggage']}',
                            style: GoogleFonts.exo(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Column(
                children: [
                  _buildSummaryRow(
                    l10n?.summaryPassengers ?? 'Pasajeros',
                    widget.passengerCount.toString(),
                  ),
                  if (widget.childSeats > 0)
                    _buildSummaryRow(
                      l10n?.summaryChildSeats ?? 'Asientos para Niños',
                      widget.childSeats.toString(),
                    ),
                  if (widget.handLuggage > 0)
                    _buildSummaryRow(
                      l10n?.summaryHandLuggage ?? 'Equipaje de Mano',
                      widget.handLuggage.toString(),
                    ),
                  if (widget.checkInLuggage > 0)
                    _buildSummaryRow(
                      l10n?.summaryCheckInLuggage ?? 'Equipaje de Bodega',
                      widget.checkInLuggage.toString(),
                    ),
                  const Divider(height: _kSpacing * 2),
                  // Información del pasajero
                  _buildSummaryRow(
                    l10n?.summaryPassengerName ?? 'Nombre del Pasajero',
                    widget.clientName,
                  ),
                ],
              );
            },
          ),
          if (widget.clientPhone != null && widget.clientPhone!.isNotEmpty)
            _buildSummaryRow('Número de Contacto', widget.clientPhone!),
          if (formattedDateTime != null) _buildSummaryRow('Fecha y Hora', formattedDateTime),
          const Divider(height: _kSpacing * 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total a Pagar',
                style: GoogleFonts.exo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kTextColor,
                ),
              ),
              Text(
                '\$${widget.price.toStringAsFixed(2)}',
                style: GoogleFonts.exo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _kPrimaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getVehicleInfo(String vehicleType) {
    final vehicles = {
      'sedan': {'name': 'Sedan', 'passengers': 3, 'handLuggage': 1, 'checkInLuggage': 0},
      'business': {'name': 'Business', 'passengers': 6, 'handLuggage': 2, 'checkInLuggage': 2},
      'van': {'name': 'Minivan 7pax', 'passengers': 8, 'handLuggage': 3, 'checkInLuggage': 4},
      'luxury': {
        'name': 'Minivan Luxury 6pax',
        'passengers': 6,
        'handLuggage': 2,
        'checkInLuggage': 1,
      },
      'minibus_8pax': {
        'name': 'Minibus 8pax',
        'passengers': 8,
        'handLuggage': 4,
        'checkInLuggage': 6,
      },
      'bus_16pax': {'name': 'Bus 16pax', 'passengers': 16, 'handLuggage': 8, 'checkInLuggage': 12},
      'bus_19pax': {'name': 'Bus 19pax', 'passengers': 19, 'handLuggage': 10, 'checkInLuggage': 15},
      'bus_50pax': {'name': 'Bus 50pax', 'passengers': 50, 'handLuggage': 25, 'checkInLuggage': 30},
    };

    return vehicles[vehicleType] ??
        {'name': vehicleType, 'passengers': 0, 'handLuggage': 0, 'checkInLuggage': 0};
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: GoogleFonts.exo(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.exo(fontSize: 14, color: _kTextColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(_kSpacing * 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(
                  l10n?.summaryPaymentMethod ?? 'Método de Pago *',
                  style: GoogleFonts.exo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kTextColor,
                  ),
                );
              },
            ),
            const SizedBox(height: _kSpacing),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return _buildPaymentMethodOption(
                        'card',
                        l10n?.paymentCard ?? 'Tarjeta',
                        Icons.credit_card,
                        _selectedPaymentMethod == 'card',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildPaymentMethodOption(
                    'paypal',
                    'PayPal',
                    Icons.payment,
                    _selectedPaymentMethod == 'paypal',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildPaymentMethodOption(
                    'apple_pay',
                    'Apple',
                    Icons.apple,
                    _selectedPaymentMethod == 'apple_pay',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildPaymentMethodOption(
                    'google_pay',
                    'Google',
                    Icons.account_balance_wallet,
                    _selectedPaymentMethod == 'google_pay',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption(String value, String label, IconData icon, bool isSelected) {
    // Determinar el logo/icono según el método de pago
    Widget? paymentLogo;
    String displayLabel = label;

    if (value == 'paypal') {
      // Logo de PayPal (usando texto estilizado como fallback)
      paymentLogo = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF003087),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'PayPal',
          style: GoogleFonts.exo(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      );
    } else if (value == 'apple_pay') {
      // Logo de Apple Pay
      paymentLogo = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, color: Colors.white, size: 14),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                'Pay',
                style: GoogleFonts.exo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (value == 'google_pay') {
      // Logo de Google Pay
      paymentLogo = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF4285F4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'G',
              style: GoogleFonts.exo(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                'Pay',
                style: GoogleFonts.exo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (value == 'card') {
      // Icono de tarjeta de crédito
      paymentLogo = Icon(icon, color: isSelected ? _kPrimaryColor : Colors.grey.shade600, size: 26);
    } else {
      // Icono por defecto
      paymentLogo = Icon(icon, color: isSelected ? _kPrimaryColor : Colors.grey.shade600, size: 26);
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(_kBorderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimaryColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(
            color: isSelected ? _kPrimaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 28, child: Center(child: paymentLogo)),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                displayLabel,
                style: GoogleFonts.exo(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _kPrimaryColor : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    // En web, mostrar solo botón de Stripe Checkout
    if (kDebugMode) {
      debugPrint('[PaymentConfirmationScreen] _buildCardForm - kIsWeb: $kIsWeb');
    }
    if (kIsWeb) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(_kSpacing * 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(_kBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Pago con Tarjeta',
                style: GoogleFonts.exo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kTextColor,
                ),
              ),
              const SizedBox(height: _kSpacing * 2),
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kPrimaryColor, _kPrimaryColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(_kBorderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          // En web, no validar formulario porque no hay campos
                          // Solo llamar directamente a _processPayment
                          _processPayment();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kBorderRadius),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payment, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Pagar con Stripe',
                        style: GoogleFonts.exo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _kSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Serás redirigido a Stripe para completar el pago de forma segura',
                      style: GoogleFonts.exo(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // En móvil, mostrar formulario completo (Payment Sheet se usa internamente)
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(_kSpacing * 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos de la Tarjeta',
                style: GoogleFonts.exo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kTextColor,
                ),
              ),
              const SizedBox(height: _kSpacing),
              _buildTextFormField(
                label: 'Número de Tarjeta *',
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                validator: _validateCardNumber,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                  _CardNumberFormatter(
                    onCardTypeDetected: (cardType) {
                      setState(() {
                        _cardType = cardType;
                      });
                    },
                  ),
                ],
                suffix: _cardType != null
                    ? Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _cardType == 'visa' ? Colors.blue.shade900 : Colors.red.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _cardType == 'visa' ? 'VISA' : 'MC',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      label: 'Vencimiento (MM/YY) *',
                      controller: _cardExpiryController,
                      keyboardType: TextInputType.number,
                      validator: _validateCardExpiry,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _CardExpiryFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: _kSpacing),
                  Expanded(
                    child: _buildTextFormField(
                      label: 'CVV *',
                      controller: _cardCvvController,
                      keyboardType: TextInputType.number,
                      validator: _validateCardCvv,
                      maxLength: 4,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                    ),
                  ),
                ],
              ),
              _buildTextFormField(
                label: 'Nombre en la Tarjeta *',
                controller: _cardNameController,
                validator: _validateRequiredField,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletInfo() {
    final isApplePay = _selectedPaymentMethod == 'apple_pay';
    final walletName = isApplePay ? 'Apple Pay' : 'Google Pay';
    final walletIcon = isApplePay ? Icons.apple : Icons.account_balance_wallet;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(_kSpacing * 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(walletIcon, color: _kPrimaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Pago con $walletName',
                  style: GoogleFonts.exo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: _kSpacing * 2),
            Container(
              padding: const EdgeInsets.all(_kSpacing * 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(_kBorderRadius),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 48),
                  const SizedBox(height: _kSpacing),
                  Text(
                    'Pendiente de Configuración',
                    style: GoogleFonts.exo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: _kSpacing),
                  Text(
                    '$walletName está disponible solo desde dispositivos móviles. La integración requiere configuración del backend y certificados específicos.',
                    style: GoogleFonts.exo(
                      fontSize: 14,
                      color: Colors.orange.shade800,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayPalInfo() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(_kSpacing * 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo de PayPal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF003087),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'PayPal',
                style: GoogleFonts.exo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: _kSpacing * 3),
            // Ícono
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.account_balance_wallet, size: 40, color: Color(0xFF003087)),
            ),
            const SizedBox(height: _kSpacing * 2),
            // Texto informativo
            Text(
              'Pago seguro con PayPal',
              style: GoogleFonts.exo(fontSize: 18, fontWeight: FontWeight.bold, color: _kTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _kSpacing),
            Text(
              'Serás redirigido a PayPal para completar el pago de forma segura',
              style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _kSpacing * 3),

            // Mostrar QR si ya se generó la orden
            if (_paypalApprovalUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(_kSpacing * 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_kBorderRadius),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.paymentScanWithMobile ?? 'Escanea con tu móvil',
                          style: GoogleFonts.exo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _kTextColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: _kSpacing),
                    qr.QrImageView(
                      data: _paypalApprovalUrl!,
                      version: qr.QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const qr.QrEyeStyle(
                        eyeShape: qr.QrEyeShape.square,
                        color: Color(0xFF003087),
                      ),
                      dataModuleStyle: const qr.QrDataModuleStyle(
                        dataModuleShape: qr.QrDataModuleShape.square,
                        color: Color(0xFF003087),
                      ),
                    ),
                    const SizedBox(height: _kSpacing),
                    Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.paymentLinkOpenedInNewWindow ??
                              'El link de pago también se abrió en una nueva ventana',
                          style: GoogleFonts.exo(fontSize: 12, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _kSpacing * 2),
            ],

            // Botón para procesar pago
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _processPayPalPayment,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.payment, size: 24),
                label: Text(
                  _paypalApprovalUrl != null
                      ? 'Abrir PayPal nuevamente'
                      : (_isProcessing ? 'Generando orden...' : 'Continuar con PayPal'),
                  style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0070BA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kSpacing * 3,
                    vertical: _kSpacing * 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kBorderRadius),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inicia el proceso de pago con Stripe Checkout (solo web)
  Future<void> _processStripeCheckout(CreateRideData rideData) async {
    if (kDebugMode) {
      debugPrint('[PaymentConfirmationScreen] 🚀 Iniciando proceso de Stripe Checkout...');
    }

    try {
      // Crear el viaje primero para obtener el rideId
      String rideId;
      try {
        if (kDebugMode) {
          debugPrint('[PaymentConfirmationScreen] 📝 Creando viaje...');
        }
        rideId = await _rideService.createRideRequest(rideData);
        if (kDebugMode) {
          debugPrint('[PaymentConfirmationScreen] ✅ Viaje creado con ID: $rideId');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PaymentConfirmationScreen] ❌ Error creando viaje: $e');
        }
        setState(() {
          _isProcessing = false;
          _paymentError = 'Error al crear el viaje: ${e.toString()}';
        });
        return;
      }

      // Construir URLs de retorno
      final currentUrl = Uri.base;
      final baseUrl =
          '${currentUrl.scheme}://${currentUrl.host}${currentUrl.hasPort ? ':${currentUrl.port}' : ''}';
      final successUrl = '$baseUrl/payment/success?session_id={CHECKOUT_SESSION_ID}';
      final cancelUrl = '$baseUrl/payment/cancel';

      if (kDebugMode) {
        debugPrint('[PaymentConfirmationScreen] 🛒 Creando Checkout Session...');
        debugPrint('[PaymentConfirmationScreen] Success URL: $successUrl');
        debugPrint('[PaymentConfirmationScreen] Cancel URL: $cancelUrl');
      }

      // Crear Checkout Session
      final checkoutSession = await StripeService.createCheckoutSession(
        rideId: rideId,
        amount: widget.price,
        currency: 'usd',
        originAddress: widget.originAddress,
        destinationAddress: widget.destinationAddress,
        clientEmail: widget.clientEmail,
        clientName: widget.clientName,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );

      if (checkoutSession == null) {
        setState(() {
          _isProcessing = false;
          _paymentError = 'Error al crear la sesión de pago. Intenta nuevamente.';
        });
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '[PaymentConfirmationScreen] ✅ Checkout Session creada: ${checkoutSession.sessionId}',
        );
        debugPrint('[PaymentConfirmationScreen] 🔗 Redirigiendo a: ${checkoutSession.checkoutUrl}');
      }

      // Redirigir al usuario a Stripe Checkout
      final uri = Uri.parse(checkoutSession.checkoutUrl);

      if (kDebugMode) {
        debugPrint(
          '[PaymentConfirmationScreen] 🔗 Intentando abrir URL: ${checkoutSession.checkoutUrl}',
        );
      }

      try {
        // En web, redirigir en la misma pestaña para evitar múltiples pestañas
        // En móvil, abrir en aplicación externa
        if (kIsWeb) {
          // Redirigir en la misma pestaña usando helper (evita dart:html deprecado)
          redirectToUrl(checkoutSession.checkoutUrl);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Redirigiendo a Stripe para completar el pago...'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          }

          // Resetear estado de procesamiento (el usuario salió de la app)
          setState(() {
            _isProcessing = false;
          });
        } else {
          // En móvil, usar LaunchMode.externalApplication
          final launchMode = LaunchMode.externalApplication;

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: launchMode);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Serás redirigido a Stripe para completar el pago.'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 3),
                ),
              );
            }

            // Resetear estado de procesamiento (el usuario salió de la app)
            setState(() {
              _isProcessing = false;
            });
          } else {
            // Si canLaunchUrl falla, intentar de todas formas
            if (kDebugMode) {
              debugPrint(
                '[PaymentConfirmationScreen] ⚠️ canLaunchUrl retornó false, intentando de todas formas...',
              );
            }

            try {
              await launchUrl(uri, mode: launchMode);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Serás redirigido a Stripe para completar el pago.'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 3),
                  ),
                );
              }

              setState(() {
                _isProcessing = false;
              });
            } catch (e2) {
              if (kDebugMode) {
                debugPrint('[PaymentConfirmationScreen] ❌ Error al abrir URL: $e2');
              }
              setState(() {
                _isProcessing = false;
                _paymentError = 'No se pudo abrir la página de pago. Verifica tu conexión.';
              });
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PaymentConfirmationScreen] ❌ Error abriendo URL: $e');
        }
        setState(() {
          _isProcessing = false;
          _paymentError = 'Error al abrir la página de pago: ${e.toString()}';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PaymentConfirmationScreen] ❌ Error en Stripe Checkout: $e');
      }
      setState(() {
        _isProcessing = false;
        _paymentError = 'Error al procesar el pago: ${e.toString()}';
      });
    }
  }

  /// Verifica el pago después de que el usuario regresa de Stripe Checkout
  Future<void> _verifyStripePayment(String sessionId) async {
    if (kDebugMode) {
      debugPrint('[PaymentConfirmationScreen] 🔍 Verificando pago con session_id: $sessionId');
    }

    setState(() {
      _isProcessing = true;
      _paymentError = null;
    });

    try {
      // Verificar el pago
      final result = await StripeService.verifyCheckoutSession(sessionId: sessionId);

      if (result['success'] == true && result['payment_status'] == 'paid') {
        // Pago exitoso
        final paymentIntentId = result['payment_intent_id'] as String?;
        final rideId = result['ride_id'] as String?;

        if (kDebugMode) {
          debugPrint('[PaymentConfirmationScreen] ✅ Pago verificado exitosamente');
          debugPrint('[PaymentConfirmationScreen] Payment Intent ID: $paymentIntentId');
          debugPrint('[PaymentConfirmationScreen] Ride ID: $rideId');
        }

        // Actualizar el viaje si es necesario (la Edge Function ya lo hace, pero por si acaso)
        if (rideId != null && paymentIntentId != null) {
          try {
            await _rideService.updateRidePaymentStatus(
              rideId: rideId,
              paymentIntentId: paymentIntentId,
              paymentStatus: 'authorized',
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[PaymentConfirmationScreen] ⚠️ Error actualizando estado: $e');
            }
            // No bloquear el flujo
          }
        }

        // Navegar a la pantalla de recibo
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });

          // Generar recibo
          final l10n = AppLocalizations.of(context);
          final receipt = _generateReceiptText(l10n);
          final receiptNumber = 'REC-${DateTime.now().millisecondsSinceEpoch}';
          final now = DateTime.now();

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ReceiptScreen(
                receiptText: receipt,
                receiptNumber: receiptNumber,
                receiptDate: now,
                totalAmount: widget.price,
                originAddress: widget.originAddress,
                destinationAddress: widget.destinationAddress,
                flightNumber: widget.flightNumber,
                vehicleType: widget.vehicleType,
                clientName: widget.clientName,
                clientEmail: widget.clientEmail,
                clientPhone: widget.clientPhone,
                distanceKm: widget.distanceKm,
                passengerCount: widget.passengerCount,
                childSeats: widget.childSeats,
                handLuggage: widget.handLuggage,
                checkInLuggage: widget.checkInLuggage,
                scheduledDate: widget.scheduledDateTime,
                scheduledTime: widget.scheduledDateTime != null
                    ? DateFormat('HH:mm').format(widget.scheduledDateTime!)
                    : null,
                paymentMethod: 'card',
                notes: widget.notes,
              ),
            ),
          );
        }
      } else {
        // Pago no exitoso o cancelado
        final error = result['error'] as String?;
        setState(() {
          _isProcessing = false;
          _paymentError = error ?? 'El pago no fue completado. Intenta nuevamente.';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error ?? 'El pago no fue completado.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PaymentConfirmationScreen] ❌ Error verificando pago: $e');
      }
      setState(() {
        _isProcessing = false;
        _paymentError = 'Error al verificar el pago: ${e.toString()}';
      });
    }
  }

  /// Inicia el proceso de pago con PayPal
  Future<void> _processPayPalPayment() async {
    // Si ya existe una orden, solo volver a abrir el link
    if (_paypalApprovalUrl != null) {
      final uri = Uri.parse(_paypalApprovalUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _paymentError = null;
    });

    try {
      final receiptNumber = 'REC-${DateTime.now().millisecondsSinceEpoch}';

      // URLs de retorno (debes ajustarlas según tu dominio)
      final currentUrl = Uri.base.toString();
      final returnUrl = '$currentUrl?payment=success&receipt=$receiptNumber';
      final cancelUrl = '$currentUrl?payment=cancelled';

      // Crear orden en PayPal
      final order = await PayPalService.createOrder(
        amount: widget.price,
        currency: 'EUR',
        description: 'Viaje de taxi: ${widget.originAddress} → ${widget.destinationAddress}',
        returnUrl: returnUrl,
        cancelUrl: cancelUrl,
      );

      if (order != null && order['approval_url'] != null) {
        final approvalUrl = order['approval_url'] as String;

        // Guardar en el estado para mostrar QR
        setState(() {
          _paypalApprovalUrl = approvalUrl;
        });

        // Abrir PayPal en nueva pestaña
        final uri = Uri.parse(approvalUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Se abrió PayPal. Complete el pago en la nueva ventana o escanee el QR.',
                ),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          throw Exception('No se pudo abrir PayPal');
        }
      } else {
        throw Exception('No se pudo crear la orden de PayPal');
      }
    } catch (e) {
      setState(() {
        _paymentError = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar pago con PayPal: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Widget _buildTextFormField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool isNumeric = false,
    bool readOnly = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType:
            keyboardType ??
            (isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
        maxLines: maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: GoogleFonts.exo(fontSize: 16, color: _kTextColor, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.exo(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: _kPrimaryColor, width: 2),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          prefixIcon: icon != null ? Icon(icon, color: _kPrimaryColor) : null,
          suffix: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(_kSpacing),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: _kSpacing),
          Expanded(
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(
                  _paymentError ?? l10n?.paymentUnknownError ?? 'Error desconocido',
                  style: GoogleFonts.exo(
                    fontSize: 14,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: _kSpacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(
                  l10n?.cancel ?? 'Cancelar',
                  style: GoogleFonts.exo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: _kSpacing),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius)),
              elevation: 3,
              shadowColor: _kPrimaryColor.withValues(alpha: 0.4),
            ),
            onPressed: _isProcessing ? null : _processPayment,
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payment, size: 20),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(
                            l10n?.paymentProcessPayment ?? 'Procesar Pago',
                            style: GoogleFonts.exo(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Validators
  String? _validateRequiredField(String? value) {
    if (value == null || value.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return l10n?.commonThisFieldIsRequired ?? 'Este campo es requerido';
    }
    return null;
  }

  String? _validateCardNumber(String? value) {
    // Solo validar si el método de pago es tarjeta
    if (_selectedPaymentMethod != 'card') {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n?.paymentCardNumberRequired ?? 'El número de tarjeta es requerido';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.length < 13 || cleaned.length > 19) {
      return l10n?.paymentInvalidCardNumber ?? 'Número de tarjeta inválido';
    }
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return l10n?.paymentOnlyNumbersAllowed ?? 'Solo se permiten números';
    }
    return null;
  }

  String? _validateCardExpiry(String? value) {
    // Solo validar si el método de pago es tarjeta
    if (_selectedPaymentMethod != 'card') {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n?.paymentExpiryDateRequired ?? 'La fecha de expiración es requerida';
    }
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
      return l10n?.paymentExpiryFormat ?? 'Formato: MM/YY';
    }
    final parts = value.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null || month < 1 || month > 12) {
      return l10n?.paymentInvalidDate ?? 'Fecha inválida';
    }
    return null;
  }

  String? _validateCardCvv(String? value) {
    // Solo validar si el método de pago es tarjeta
    if (_selectedPaymentMethod != 'card') {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n?.paymentCvvRequired ?? 'El CVV es requerido';
    }
    if (value.length < 3 || value.length > 4) {
      return l10n?.paymentCvvInvalid ?? 'CVV debe tener 3 o 4 dígitos';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return l10n?.paymentOnlyNumbersAllowed ?? 'Solo se permiten números';
    }
    return null;
  }
}

// Custom formatters
class _CardNumberFormatter extends TextInputFormatter {
  final Function(String?)? onCardTypeDetected;

  _CardNumberFormatter({this.onCardTypeDetected});

  String? _detectCardType(String digits) {
    if (digits.isEmpty) {
      return null;
    }

    // Visa: empieza con 4, 13 o 16 dígitos
    if (digits.startsWith('4')) {
      return 'visa';
    }

    // Mastercard: empieza con 51-55 o 2221-2720, 16 dígitos
    if (digits.length >= 2) {
      final firstTwo = int.tryParse(digits.substring(0, 2));
      if (firstTwo != null) {
        if (firstTwo >= 51 && firstTwo <= 55) {
          return 'mastercard';
        }
      }
    }
    if (digits.length >= 4) {
      final firstFour = int.tryParse(digits.substring(0, 4));
      if (firstFour != null) {
        if (firstFour >= 2221 && firstFour <= 2720) {
          return 'mastercard';
        }
      }
    }

    return null;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) {
      onCardTypeDetected?.call(null);
      return newValue;
    }
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');

    // Detectar tipo de tarjeta
    final cardType = _detectCardType(digitsOnly);
    onCardTypeDetected?.call(cardType);

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    final limited = digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;
    String formatted = limited;
    if (limited.length >= 2) {
      formatted = '${limited.substring(0, 2)}/${limited.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
