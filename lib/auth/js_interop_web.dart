// Archivo solo para web - contiene la función JS interop
import 'dart:async';
import 'dart:js_interop';

// Función helper para verificar si un objeto es una Promise
bool _isPromise(dynamic obj) {
  if (obj == null) return false;
  try {
    // Verificar que tenga el método then (las Promises de JavaScript siempre tienen then)
    // También verificar que then sea una función
    final thenMethod = obj.then;
    if (thenMethod == null) return false;

    // Verificar que sea una función (Function o cualquier callable)
    // También verificar que tenga 'catch' usando notación de corchetes (las Promises siempre tienen catch)
    try {
      final catchMethod = obj['catch'];
      return thenMethod is Function && (catchMethod == null || catchMethod is Function);
    } catch (_) {
      // Si no se puede acceder a catch, verificar solo then
      return thenMethod is Function;
    }
  } catch (e) {
    // Si hay error accediendo a las propiedades, no es una Promise válida
    return false;
  }
}

// Extensión para convertir JSPromise a Future
// Esta extensión debe estar disponible cuando se importa este archivo
extension JSPromiseExtension<T extends JSAny?> on JSPromise<T> {
  Future<T> get toDart {
    final completer = Completer<T>();

    // Intentar convertir directamente como dynamic primero (más flexible)
    dynamic promiseObj;
    try {
      // Intentar como dynamic primero para mayor compatibilidad
      promiseObj = this as dynamic;

      // Verificar que sea una Promise válida
      if (!_isPromise(promiseObj)) {
        completer.completeError(
          Exception(
            'El objeto retornado no es una Promise válida. Tipo: ${promiseObj.runtimeType}',
          ),
        );
        return completer.future;
      }
    } catch (e) {
      completer.completeError(Exception('Error al verificar Promise: $e. Tipo: $runtimeType'));
      return completer.future;
    }

    // Crear funciones JS para manejar resolve y reject
    final onResolve = ((JSAny? result) {
      if (!completer.isCompleted) {
        completer.complete(result as T);
      }
    }).toJS;

    final onReject = ((JSAny? error) {
      if (!completer.isCompleted) {
        try {
          final errorObj = error?.dartify();
          final errorMessage = errorObj is Map
              ? (errorObj['message'] ?? errorObj.toString())
              : (errorObj?.toString() ?? 'Unknown error');
          completer.completeError(Exception(errorMessage));
        } catch (e) {
          completer.completeError(Exception('Error al procesar el rechazo de la Promise: $e'));
        }
      }
    }).toJS;

    try {
      // Llamar then directamente usando dynamic
      promiseObj.then(onResolve, onReject);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Error al convertir JSPromise a Future: $e. Tipo: ${promiseObj.runtimeType}'),
        );
      }
    }

    return completer.future;
  }
}

// Función top-level para JS interop (solo disponible en web)
// Nota: La función JavaScript debe estar disponible en window.firebaseAuthSignInWithGoogle
@JS('firebaseAuthSignInWithGoogle')
external JSPromise<JSObject?> firebaseAuthSignInWithGoogleJS(JSObject config);

// Función para obtener el resultado del redirect cuando la página se recarga
@JS('firebaseAuthGetRedirectResult')
external JSPromise<JSObject?> firebaseAuthGetRedirectResultJS(JSObject config);

// Función alternativa para verificar si la función JS está disponible
@JS('window')
external JSObject get window;

bool isFirebaseAuthHelperAvailable() {
  try {
    // Convertir window a objeto Dart para acceder a propiedades dinámicas
    final winObj = dartify(window) as Map<String, dynamic>?;
    if (winObj == null) {
      return false;
    }
    return winObj['firebaseAuthSignInWithGoogle'] != null;
  } catch (e) {
    return false;
  }
}

// Wrapper functions para jsify y dartify
JSObject jsify(Object? object) => object.jsify() as JSObject;
Object? dartify(JSObject object) => object.dartify();
