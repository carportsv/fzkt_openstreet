// Archivo stub para móvil - las funciones JS interop no están disponibles
// Este archivo se usa cuando se compila para móvil (iOS/Android)

// Stubs para evitar errores de compilación en móvil
bool isStripeHelperAvailable() => false;

// Stubs para funciones top-level (nunca se llamarán en móvil)
class JSPromise<T> {
  Future<T> get toDart => throw UnsupportedError('JSPromise no disponible en móvil');
}

class JSObject {}

JSPromise<bool> stripeInitializeJS(String publishableKey) {
  throw UnsupportedError('stripeInitializeJS solo está disponible en web');
}

JSPromise<JSObject?> stripeCreatePaymentMethodJS(JSObject cardData) {
  throw UnsupportedError('stripeCreatePaymentMethodJS solo está disponible en web');
}

JSPromise<JSObject?> stripeConfirmPaymentJS(String clientSecret, String paymentMethodId) {
  throw UnsupportedError('stripeConfirmPaymentJS solo está disponible en web');
}

JSObject jsify(Object? object) {
  throw UnsupportedError('jsify() no disponible en móvil');
}

Object? dartify(JSObject object) {
  throw UnsupportedError('dartify() no disponible en móvil');
}
