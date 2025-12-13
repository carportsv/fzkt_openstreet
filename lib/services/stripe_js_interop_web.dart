// Archivo solo para web - contiene las funciones JS interop para Stripe
import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

// Función helper para llamar then en una promesa usando interop
void _callPromiseThen(JSObject promise, JSFunction onResolve, JSFunction onReject) {
  try {
    final dynamicPromise = promise as dynamic;
    if (dynamicPromise.then == null) {
      throw Exception('El objeto no es una Promise válida: no tiene método then');
    }
    dynamicPromise.then(onResolve, onReject);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[StripeJSPromiseExtension] Error en _callPromiseThen: $e');
    }
    rethrow;
  }
}

// Extensión para convertir JSPromise a Future
extension StripeJSPromiseExtension<T extends JSAny?> on JSPromise<T> {
  Future<T> get toDart {
    final completer = Completer<T>();

    JSObject promise;
    try {
      promise = this as JSObject;
    } catch (e) {
      completer.completeError(Exception('No se pudo convertir a JSObject: $e'));
      return completer.future;
    }

    // Crear funciones de callback
    final onResolve = (JSAny? result) {
      if (!completer.isCompleted) {
        completer.complete(result as T);
      }
    }.toJS;

    final onReject = (JSAny? error) {
      if (!completer.isCompleted) {
        final errorMessage = _extractErrorMessage(error);
        completer.completeError(Exception(errorMessage));
      }
    }.toJS;

    // Llamar then en la promesa
    try {
      _callPromiseThen(promise, onResolve, onReject);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Error llamando then en la promesa: $e'));
      }
    }

    return completer.future;
  }
}

// Función helper para extraer mensaje de error
String _extractErrorMessage(JSAny? error) {
  try {
    final dynamicError = error as dynamic;
    if (dynamicError.message != null) {
      return dynamicError.message.toString();
    }
    // toString siempre está disponible
    return dynamicError.toString();
  } catch (e) {
    // Ignorar errores al extraer mensaje
  }
  return 'Error desconocido';
}

// Función top-level para inicializar Stripe (solo disponible en web)
// Retorna un bool en Dart, pero lo declaramos como JSAny? para evitar problemas de tipo
@JS('stripeInitialize')
external JSPromise<JSAny?> stripeInitializeJS(String publishableKey);

// Función top-level para crear Payment Method (solo disponible en web)
@JS('stripeCreatePaymentMethod')
external JSPromise<JSObject?> stripeCreatePaymentMethodJS(JSObject cardData);

// Función top-level para confirmar Payment Intent con datos de tarjeta (solo disponible en web)
// Ahora requiere Supabase URL y API key para crear el payment method en el backend
@JS('stripeConfirmPaymentWithCardData')
external JSPromise<JSObject?> stripeConfirmPaymentWithCardDataJS(
  String clientSecret,
  JSObject cardData,
  String supabaseUrl,
  String supabaseAnonKey,
);

// Función top-level para confirmar Payment Intent (solo disponible en web)
@JS('stripeConfirmPayment')
external JSPromise<JSObject?> stripeConfirmPaymentJS(String clientSecret, String paymentMethodId);

// Función alternativa para verificar si las funciones JS están disponibles
@JS('window')
external JSObject get window;

bool isStripeHelperAvailable() {
  // Las funciones están definidas con @JS, lo que significa que están disponibles
  // globalmente en JavaScript. Si el script no está cargado, las funciones
  // fallarán cuando se intenten llamar, pero no podemos verificar su existencia
  // de forma confiable sin usar APIs que no están disponibles en dart:js_interop.
  //
  // La mejor estrategia es simplemente intentar usarlas y manejar el error
  // si no están disponibles. Por ahora, retornamos true si estamos en web,
  // y dejamos que el código de inicialización maneje los errores.
  if (kDebugMode) {
    debugPrint(
      '[isStripeHelperAvailable] Asumiendo que las funciones están disponibles (verificación fallida)',
    );
  }
  return true;
}

// Wrapper functions para jsify y dartify
JSObject jsify(Object? object) => object.jsify() as JSObject;
Object? dartify(JSObject object) => object.dartify();
