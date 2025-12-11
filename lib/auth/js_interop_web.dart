// Archivo solo para web - contiene la función JS interop
import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

// Función helper para verificar si un objeto es una Promise
bool _isPromise(JSAny? obj) {
  if (obj == null) return false;
  try {
    final dynamicObj = obj as dynamic;
    // Verificar que tenga el método then (las Promises de JavaScript siempre tienen then)
    // No podemos verificar el tipo en tiempo de ejecución de manera segura en Dart,
    // así que solo verificamos que exista el método
    return dynamicObj.then != null;
  } catch (e) {
    return false;
  }
}

// Función helper para llamar then en una promesa usando interop
void _callPromiseThen(JSObject promise, JSFunction onResolve, JSFunction onReject) {
  try {
    // Acceder al método then de la promesa usando dynamic
    // Esto es necesario porque JSObject no expone directamente el método then
    final dynamicPromise = promise as dynamic;

    // Verificar que tenga el método then
    if (dynamicPromise.then == null) {
      throw Exception('El objeto no es una Promise válida: no tiene método then');
    }

    // Llamar then directamente usando dynamic
    // En JavaScript: promise.then(onResolve, onReject)
    dynamicPromise.then(onResolve, onReject);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[JSPromiseExtension] Error en _callPromiseThen: $e');
      debugPrint('[JSPromiseExtension] Promise type: ${promise.runtimeType}');
    }
    rethrow;
  }
}

// Extensión para convertir JSPromise a Future
// Esta extensión debe estar disponible cuando se importa este archivo
extension JSPromiseExtension<T extends JSAny?> on JSPromise<T> {
  Future<T> get toDart {
    final completer = Completer<T>();

    // Convertir a JSObject
    JSObject promise;
    try {
      promise = this as JSObject;
    } catch (e) {
      // Si no se puede convertir a JSObject, intentar como dynamic
      try {
        final dynamicObj = this as dynamic;
        // Si es una Promise nativa de JavaScript, usar directamente
        if (_isPromise(dynamicObj)) {
          promise = dynamicObj as JSObject;
        } else {
          completer.completeError(
            Exception('El objeto retornado no es una Promise válida. Tipo: $runtimeType'),
          );
          return completer.future;
        }
      } catch (e2) {
        completer.completeError(Exception('Error al convertir a JSObject: $e, $e2'));
        return completer.future;
      }
    }

    // Verificar que sea una promesa válida
    if (!_isPromise(promise)) {
      completer.completeError(
        Exception('El objeto retornado no es una Promise válida. Tipo: ${promise.runtimeType}'),
      );
      return completer.future;
    }

    // Crear funciones JS para manejar resolve y reject
    final onResolve = ((T result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }).toJS;

    final onReject = ((JSAny? error) {
      if (!completer.isCompleted) {
        try {
          final errorObj = error?.dartify();
          completer.completeError(errorObj ?? 'Unknown error');
        } catch (e) {
          completer.completeError('Error al procesar el rechazo de la Promise: $e');
        }
      }
    }).toJS;

    try {
      // Llamar a then usando la función helper
      _callPromiseThen(promise, onResolve, onReject);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Error al convertir JSPromise a Future: $e'));
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
