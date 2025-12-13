// Archivo solo para web - contiene la función JS interop
import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

// Función helper para verificar si un objeto es una Promise
bool _isPromise(dynamic obj) {
  if (obj == null) return false;
  try {
    // Para js_interop, intentar acceder a then de múltiples formas
    dynamic thenMethod;

    // Intentar acceder a then directamente
    try {
      thenMethod = obj.then;
    } catch (_) {
      // Si falla, intentar con notación de corchetes
      try {
        thenMethod = obj['then'];
      } catch (_) {
        return false;
      }
    }

    if (thenMethod == null) return false;

    // Verificar que then sea callable (puede ser Function, JSFunction, etc.)
    // En js_interop, puede ser cualquier objeto callable
    return true; // Si tiene then, asumimos que es una Promise
  } catch (e) {
    // No se puede hacer runtime check con tipos js_interop
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

      // js_interop garantiza que JSPromise es una Promise válida
      // Intentar verificar, pero si falla, continuar de todas formas
      if (!_isPromise(promiseObj)) {
        // Si no pasa la verificación, intentar de todas formas
        // porque puede ser una Promise que no se reconoce correctamente
        if (kDebugMode) {
          debugPrint(
            '[JSPromiseExtension] Advertencia: Objeto no reconocido como Promise, intentando de todas formas',
          );
        }
      }
    } catch (e) {
      // Si hay error, intentar de todas formas llamando then
      if (kDebugMode) {
        debugPrint(
          '[JSPromiseExtension] Error al verificar Promise: $e, intentando de todas formas',
        );
      }
      promiseObj = this as dynamic;
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
