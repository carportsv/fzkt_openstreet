// Stub para móvil - esta función nunca se llamará en móvil
// pero necesitamos declararla para que el código compile

class JSObject {}

class JSPromise<T> {
  Future<T> get toDart => throw UnsupportedError('js_interop no disponible en esta plataforma');
}

// Función stub que nunca se llamará en móvil
JSPromise<JSObject> firebaseAuthSignInWithGoogleJS(JSObject config) {
  throw UnsupportedError('Esta función solo está disponible en web');
}

// Función stub para obtener resultado de redirect (nunca se llamará en móvil)
JSPromise<JSObject?> firebaseAuthGetRedirectResultJS(JSObject config) {
  throw UnsupportedError('Esta función solo está disponible en web');
}

// Función top-level stub para jsify (nunca se llamará en móvil)
JSObject jsify(Map<String, String> map) {
  throw UnsupportedError('jsify() no disponible en esta plataforma');
}

// Función top-level stub para dartify (nunca se llamará en móvil)
Map? dartify(JSObject obj) {
  throw UnsupportedError('dartify() no disponible en esta plataforma');
}
