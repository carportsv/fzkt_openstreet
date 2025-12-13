import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import './login_screen.dart';
import './routing_screen.dart';
import '../screens/welcome/welcome/welcome_screen.dart';
// Importación condicional para leer hash en web
import '../router/route_handler_stub.dart'
    if (dart.library.html) '../router/route_handler_web.dart';

/// The definitive, stable AuthGate.
/// It uses a [StreamBuilder] to listen to Firebase's auth state changes.
/// It now hands off control to the [RoutingScreen] for role-based logic.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if Firebase is initialized
    try {
      // Check if Firebase apps exist
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ AuthGate: Firebase not initialized!');
          debugPrint('⚠️ Showing login screen anyway, but authentication will fail.');
        }
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error de inicialización',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Firebase no se pudo inicializar.\nRevisa la consola para más detalles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Abre la consola del navegador (F12)\npara ver los errores detallados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      // Try to get Firebase Auth instance de forma segura
      FirebaseAuth? auth;
      try {
        auth = FirebaseAuth.instance;
      } catch (e) {
        final errorMessage = e.toString();
        if (kDebugMode) {
          debugPrint('❌ AuthGate: Error obteniendo FirebaseAuth: $errorMessage');
        }
        auth = null;
      }

      if (auth == null) {
        // Si no se pudo obtener Firebase Auth, mostrar error
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error de inicialización',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Firebase no se pudo inicializar.\nRevisa la consola para más detalles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      if (kDebugMode) {
        debugPrint('✅ AuthGate: Firebase initialized, listening to auth state...');
      }

      // Usar StatefulWidget para poder verificar el estado periódicamente
      return _AuthGateContent(auth: auth);
    } catch (e, stackTrace) {
      // If Firebase is not initialized, show error screen
      // Convertir excepción a string de forma segura para Flutter Web
      final errorMessage = e.toString();
      final stackTraceMessage = stackTrace.toString();
      if (kDebugMode) {
        debugPrint('❌ AuthGate: Exception caught: $errorMessage');
        debugPrint('Stack trace: $stackTraceMessage');
      }
      // Show error screen with details
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error de inicialización',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Error: $errorMessage',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                const Text(
                  'Abre la consola del navegador (F12)\npara ver el stack trace completo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
}

class _AuthGateContent extends StatefulWidget {
  final FirebaseAuth auth;

  const _AuthGateContent({required this.auth});

  @override
  State<_AuthGateContent> createState() => _AuthGateContentState();
}

class _AuthGateContentState extends State<_AuthGateContent> {
  String? _lastKnownUserId;

  @override
  void initState() {
    super.initState();
    _lastKnownUserId = widget.auth.currentUser?.uid;
    // Verificar periódicamente el estado del usuario
    _checkAuthState();
  }

  void _checkAuthState() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final currentUser = widget.auth.currentUser;
      final currentUserId = currentUser?.uid;

      // Comparar por UID, no por referencia de objeto
      if (currentUserId != _lastKnownUserId) {
        if (kDebugMode) {
          debugPrint(
            '[AuthGate] Polling detectó cambio: ${_lastKnownUserId ?? "null"} -> ${currentUserId ?? "null"}',
          );
        }
        // CRÍTICO: Actualizar el estado ANTES de verificar si hay usuario
        setState(() {
          _lastKnownUserId = currentUserId;
        });
        // Si detectamos un usuario nuevo después de logout, forzar reconstrucción inmediata
        if (currentUserId != null) {
          if (kDebugMode) {
            debugPrint(
              '[AuthGate] Polling: Usuario detectado después de cambio, forzando reconstrucción del StreamBuilder',
            );
          }
          // Forzar una reconstrucción adicional para asegurar que el StreamBuilder se actualice
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                // Forzar reconstrucción
              });
            }
          });
        }
      }
      _checkAuthState(); // Continuar verificando
    });
  }

  @override
  Widget build(BuildContext context) {
    // Usar authStateChanges() que es más reactivo que userChanges()
    // También usar el polling como fallback
    final currentUser = widget.auth.currentUser;
    final currentUserId = currentUser?.uid;

    return StreamBuilder<User?>(
      stream: widget.auth.authStateChanges(), // Cambiar a authStateChanges() que es más confiable
      builder: (context, snapshot) {
        // Priorizar el usuario del stream, pero usar currentUser como fallback
        final streamUser = snapshot.data;
        final user = streamUser ?? currentUser;
        final userId = user?.uid;

        // Si el polling detectó un cambio diferente al del stream, usar el del polling
        // Esto es especialmente importante después de logout/login
        if (_lastKnownUserId != null && _lastKnownUserId != userId) {
          if (kDebugMode) {
            debugPrint(
              '[AuthGate] ⚠️ Polling detectó cambio diferente al stream: stream=${userId ?? "null"}, polling=$_lastKnownUserId',
            );
            debugPrint('[AuthGate] Usando usuario del polling porque el stream no se actualizó');
          }
          // Usar el usuario actual del polling
          final pollingUser = widget.auth.currentUser;
          if (pollingUser != null && pollingUser.uid == _lastKnownUserId) {
            if (kDebugMode) {
              debugPrint(
                '[AuthGate] ✅ Navegando a RoutingScreen usando usuario del polling: $_lastKnownUserId',
              );
            }
            return const RoutingScreen();
          }
        }

        // Si el polling tiene un usuario pero el stream no, usar el polling
        if (_lastKnownUserId != null && userId == null && currentUserId == _lastKnownUserId) {
          if (kDebugMode) {
            debugPrint('[AuthGate] ⚠️ Stream no tiene usuario pero polling sí: $_lastKnownUserId');
            debugPrint('[AuthGate] ✅ Navegando a RoutingScreen usando usuario del polling');
          }
          return const RoutingScreen();
        }

        if (kDebugMode) {
          debugPrint('[AuthGate] Stream state: ${snapshot.connectionState}');
          debugPrint('[AuthGate] Stream hasData: ${snapshot.hasData}');
          debugPrint('[AuthGate] Stream data: ${streamUser?.uid ?? "null"}');
          debugPrint('[AuthGate] Current user: ${currentUserId ?? "null"}');
          debugPrint('[AuthGate] Last known UID (polling): ${_lastKnownUserId ?? "null"}');
          debugPrint('[AuthGate] Final user: ${userId ?? "null"}');
        }

        // While waiting for the auth state, show a loading indicator.
        if (snapshot.connectionState == ConnectionState.waiting &&
            userId == null &&
            _lastKnownUserId == null) {
          if (kDebugMode) {
            debugPrint('[AuthGate] Mostrando loading...');
          }
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Cargando...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            ),
          );
        }

        // If there's an error, show login screen
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('⚠️ AuthGate error: ${snapshot.error}');
          }
          return const LoginScreen();
        }

        // Si hay usuario (del stream, del estado actual, o del polling), navegar a RoutingScreen
        if (userId != null || _lastKnownUserId != null) {
          final finalUserId = userId ?? _lastKnownUserId;
          if (kDebugMode) {
            debugPrint('✅ AuthGate: User logged in ($finalUserId), navigating to RoutingScreen');
          }
          return const RoutingScreen();
        }

        // If no user is logged in, en web redirigir a /welcome, en móvil mostrar LoginScreen
        if (kDebugMode) {
          debugPrint('ℹ️ AuthGate: No user logged in');
        }

        // En web, verificar la ruta actual para decidir qué mostrar
        if (kIsWeb) {
          // Verificar si estamos en la ruta /admin
          bool isAdminRoute = false;
          try {
            // Verificar el path y el fragment (hash) de la URL
            String path = Uri.base.path;
            String fragment = Uri.base.fragment;
            final fullUri = Uri.base.toString();

            // Normalizar el path removiendo el base-href si está presente (GitHub Pages)
            String normalizedPath = path;
            if (path.startsWith('/eug_consultancy')) {
              normalizedPath = path.replaceFirst('/eug_consultancy', '');
              if (normalizedPath.isEmpty) {
                normalizedPath = '/';
              }
            }

            // Si el fragmento está vacío, intentar leerlo de window.location.hash
            if (fragment.isEmpty && kIsWeb) {
              try {
                fragment = getHashFromWindow();
                if (kDebugMode && fragment.isNotEmpty) {
                  debugPrint('[AuthGate] Hash obtenido de window.location: $fragment');
                }
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('[AuthGate] Error obteniendo hash: $e');
                }
              }
            }

            // Normalizar el fragment
            String normalizedFragment = fragment;
            if (fragment.isNotEmpty) {
              if (!fragment.startsWith('/')) {
                normalizedFragment = '/$fragment';
              }
            }

            // Verificar si es ruta admin (path o hash) - considerar tanto path original como normalizado
            isAdminRoute =
                path.contains('/admin') ||
                path.endsWith('/admin') ||
                path == '/admin' ||
                normalizedPath.contains('/admin') ||
                normalizedPath.endsWith('/admin') ||
                normalizedPath == '/admin' ||
                fragment.contains('/admin') ||
                fragment == 'admin' ||
                fragment == '/admin' ||
                normalizedFragment == '/admin' ||
                normalizedFragment.contains('/admin') ||
                fullUri.contains('/admin') ||
                fullUri.contains('#/admin') ||
                fullUri.contains('index.html#/admin');

            if (kDebugMode) {
              debugPrint(
                '[AuthGate] Web - Path: $path, Fragment: $fragment, Normalized: $normalizedFragment',
              );
              debugPrint('[AuthGate] Web - Full URI: $fullUri');
              debugPrint('[AuthGate] Web - Is admin route: $isAdminRoute');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[AuthGate] Error verificando ruta: $e');
            }
          }

          // Si estamos en /admin, mostrar LoginScreen (requiere login)
          if (isAdminRoute) {
            if (kDebugMode) {
              debugPrint('[AuthGate] Web - Ruta /admin detectada, mostrando LoginScreen');
            }
            return const LoginScreen();
          }

          // Si no es /admin, redirigir a WelcomeScreen (público)
          if (kDebugMode) {
            debugPrint('[AuthGate] Web - Redirigiendo a WelcomeScreen (ruta pública)');
          }
          return const WelcomeScreen();
        }

        // En móvil, mostrar LoginScreen
        if (kDebugMode) {
          debugPrint('ℹ️ AuthGate: Mostrando LoginScreen (móvil)');
        }
        return const LoginScreen();
      },
    );
  }
}
