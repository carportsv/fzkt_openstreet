import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de Stripe para la aplicación
class StripeConfig {
  // Clave pública de Stripe (segura para el frontend)
  static String get publishableKey =>
      dotenv.env['EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY'] ?? '';

  // Configuración de la aplicación
  static const String merchantIdentifier = 'merchant.com.carposv.taxizkt'; // Para Apple Pay

  // Configuración de pagos
  static const Map<String, bool> paymentMethods = {
    'card': true,
    'applePay': false, // Habilitar cuando esté listo
    'googlePay': false, // Habilitar cuando esté listo
  };

  // Configuración de moneda
  static const String defaultCurrency = 'usd';

  // Configuración de comisiones
  static const double platformCommission = 0.20; // 20% para la plataforma
  static const double driverCommission = 0.80; // 80% para el conductor
}

/// Tarjetas de prueba de Stripe para desarrollo
class StripeTestCards {
  // Pagos exitosos
  static const Map<String, String> success = {
    'number': '4242424242424242',
    'cvv': '123',
    'expMonth': '12',
    'expYear': '2025',
    'description': 'Pago procesado exitosamente',
  };

  // Pagos fallidos
  static const Map<String, String> declined = {
    'number': '4000000000000002',
    'cvv': '123',
    'expMonth': '12',
    'expYear': '2025',
    'description': 'Tarjeta declinada',
  };

  // Requiere autenticación
  static const Map<String, String> requiresAuth = {
    'number': '4000002500003155',
    'cvv': '123',
    'expMonth': '12',
    'expYear': '2025',
    'description': 'Requiere autenticación 3D Secure',
  };

  // Fondos insuficientes
  static const Map<String, String> insufficientFunds = {
    'number': '4000000000009995',
    'cvv': '123',
    'expMonth': '12',
    'expYear': '2025',
    'description': 'Fondos insuficientes',
  };

  // Tarjeta robada
  static const Map<String, String> stolen = {
    'number': '4000000000009987',
    'cvv': '123',
    'expMonth': '12',
    'expYear': '2025',
    'description': 'Tarjeta reportada como robada',
  };

  // Tarjeta expirada
  static const Map<String, String> expired = {
    'number': '4000000000000069',
    'cvv': '123',
    'expMonth': '12',
    'expYear': '2020',
    'description': 'Tarjeta expirada',
  };

  // CVV incorrecto
  static const Map<String, String> incorrectCvv = {
    'number': '4000000000000127',
    'cvv': '999',
    'expMonth': '12',
    'expYear': '2025',
    'description': 'CVV incorrecto',
  };

  /// Obtener todas las tarjetas de prueba
  static List<Map<String, String>> get allCards => [
        success,
        declined,
        requiresAuth,
        insufficientFunds,
        stolen,
        expired,
        incorrectCvv,
      ];

  /// Validar si es una tarjeta de prueba
  static bool isTestCard(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\s'), '');
    return allCards.any((card) => card['number'] == cleanNumber);
  }
}

/// Mensajes de error de Stripe en español
class StripeErrorMessages {
  static const Map<String, String> messages = {
    'card_declined': 'Tarjeta declinada. Verifica los datos e intenta nuevamente.',
    'expired_card': 'Tarjeta expirada. Usa una tarjeta válida.',
    'incorrect_cvc': 'CVV incorrecto. Verifica el código de seguridad.',
    'insufficient_funds': 'Fondos insuficientes en la tarjeta.',
    'invalid_expiry_month': 'Mes de vencimiento inválido.',
    'invalid_expiry_year': 'Año de vencimiento inválido.',
    'invalid_number': 'Número de tarjeta inválido.',
    'processing_error': 'Error procesando el pago. Intenta nuevamente.',
    'rate_limit': 'Demasiados intentos. Espera un momento.',
    'authentication_required': 'Autenticación requerida. Completa la verificación.',
    'generic_decline': 'Pago rechazado. Contacta tu banco.',
    'do_not_honor': 'Pago rechazado por el banco.',
    'lost_card': 'Tarjeta reportada como perdida.',
    'stolen_card': 'Tarjeta reportada como robada.',
    'fraudulent': 'Pago marcado como fraudulento.',
    'pickup_card': 'Tarjeta retenida por el banco.',
    'incorrect_number': 'Número de tarjeta incorrecto.',
    'incorrect_zip': 'Código postal incorrecto.',
    'invalid_cvc': 'Código de seguridad inválido.',
    'card_not_supported': 'Tipo de tarjeta no soportado.',
    'currency_not_supported': 'Moneda no soportada.',
    'duplicate_transaction': 'Transacción duplicada.',
    'incorrect_address': 'Dirección incorrecta.',
    'invalid_swipe_data': 'Datos de tarjeta inválidos.',
    'invalid_zip': 'Código postal inválido.',
    'merchant_blacklist': 'Comercio en lista negra.',
    'new_account_information_available': 'Nueva información de cuenta disponible.',
    'no_action_taken': 'No se tomó ninguna acción.',
    'not_permitted': 'Operación no permitida.',
    'restricted_card': 'Tarjeta restringida.',
    'revocation_of_all_authorizations': 'Revocación de todas las autorizaciones.',
    'revocation_of_authorization': 'Revocación de autorización.',
    'security_violation': 'Violación de seguridad.',
    'service_not_allowed': 'Servicio no permitido.',
    'stop_payment_order': 'Orden de detener pago.',
    'testmode_decline': 'Rechazo en modo de prueba.',
    'transaction_not_allowed': 'Transacción no permitida.',
    'try_again_later': 'Intenta nuevamente más tarde.',
    'withdrawal_count_limit_exceeded': 'Límite de retiros excedido.',
  };

  /// Obtener mensaje de error amigable
  static String getErrorMessage(String errorCode) {
    return messages[errorCode] ?? 'Error de pago. Intenta nuevamente.';
  }
}

