// Archivo solo para web - contiene la función JS interop
import 'dart:async';
import 'dart:js_interop';

// Función helper externa para llamar then en una promesa
@JS('Promise.prototype.then')
external JSObject? _promiseThen(JSObject promise, JSFunction onResolve, [JSFunction? onReject]);

// Extensión para convertir JSPromise a Future
extension JSPromiseExtension<T extends JSAny?> on JSPromise<T> {
  Future<T> get toDart {
    final completer = Completer<T>();
    final promise = this as JSObject;

    // Crear funciones JS para manejar resolve y reject
    final onResolve = ((T result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }).toJS;

    final onReject = ((JSAny? error) {
      if (!completer.isCompleted) {
        final errorObj = error?.dartify();
        completer.completeError(errorObj ?? 'Unknown error');
      }
    }).toJS;

    // Llamar a then usando la función externa
    _promiseThen(promise, onResolve, onReject);

    return completer.future;
  }
}

// Función top-level para JS interop (solo disponible en web)
@JS('firebaseAuthSignInWithGoogle')
external JSPromise<JSObject?> firebaseAuthSignInWithGoogleJS(JSObject config);

// Wrapper functions para jsify y dartify
JSObject jsify(Object? object) => object.jsify() as JSObject;
Object? dartify(JSObject object) => object.dartify();
