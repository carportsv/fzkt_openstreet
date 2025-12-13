import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_gate.dart';
import '../auth/user_service.dart';
import '../screens/welcome/welcome/welcome_screen.dart';
import '../screens/welcome/welcome/menus/company_screen.dart';
import '../screens/welcome/welcome/menus/destinations_screen.dart';
import '../screens/welcome/welcome/menus/contacts_screen.dart';
import '../screens/welcome/booking/stripe_return_screen.dart';
import '../screens/admin/admin_home_screen.dart';

/// Widget que maneja las rutas basándose en la URL actual
class RouteHandler extends StatelessWidget {
  const RouteHandler({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      try {
        // En web, verificar la URL actual usando Uri.base
        // Normalizar el path para eliminar dobles barras y prevenir SecurityError
        String path = Uri.base.path.replaceAll(RegExp(r'/+'), '/');
        if (path.length > 1 && path.endsWith('/')) {
          path = path.substring(0, path.length - 1);
        }
        // Si el path está vacío o es solo '/', mantenerlo como '/'
        if (path.isEmpty) {
          path = '/';
        }

        // También verificar el fragmento (hash) de la URL para rutas como /#/welcome
        // En GitHub Pages, las rutas se convierten a hash: /admin -> #/admin
        final fragment = Uri.base.fragment;
        // Obtener la URL completa para verificar el hash
        final fullUri = Uri.base.toString();

        // Extraer el fragmento sin el # si está presente
        String cleanFragment = fragment;
        if (cleanFragment.startsWith('#')) {
          cleanFragment = cleanFragment.substring(1);
        }
        if (cleanFragment.startsWith('/')) {
          cleanFragment = cleanFragment;
        } else if (cleanFragment.isNotEmpty) {
          cleanFragment = '/$cleanFragment';
        }

        if (kDebugMode) {
          debugPrint('[RouteHandler] Current path: $path');
          debugPrint('[RouteHandler] Current fragment: $fragment');
          debugPrint('[RouteHandler] Full URI: $fullUri');
        }

        // Normalizar el path removiendo el base-href si está presente
        // Soporta tanto /fzkt_openstreet como /eug_consultancy para compatibilidad
        String normalizedPath = path;
        if (path.startsWith('/fzkt_openstreet')) {
          normalizedPath = path.replaceFirst('/fzkt_openstreet', '');
          if (normalizedPath.isEmpty) {
            normalizedPath = '/';
          }
        } else if (path.startsWith('/eug_consultancy')) {
          normalizedPath = path.replaceFirst('/eug_consultancy', '');
          if (normalizedPath.isEmpty) {
            normalizedPath = '/';
          }
        }

        // Normalizar el fragment - puede venir como "/welcome" o "welcome"
        String normalizedFragment = fragment;
        if (fragment.isNotEmpty) {
          if (!fragment.startsWith('/')) {
            normalizedFragment = '/$fragment';
          }
        }

        // CRÍTICO: Verificar /admin PRIMERO, antes de cualquier otra verificación
        // Esto es especialmente importante en GitHub Pages donde /admin se convierte a #/admin
        final hasAdminInUrl =
            fullUri.contains('/admin') ||
            fullUri.contains('#/admin') ||
            fullUri.contains('index.html#/admin') ||
            fullUri.contains('admin');
        final isAdminPath =
            normalizedPath.endsWith('/admin') ||
            normalizedPath == '/admin' ||
            normalizedPath.contains('/admin/');
        final isAdminFragment =
            normalizedFragment == '/admin' ||
            normalizedFragment == '/admin/' ||
            normalizedFragment.contains('/admin') ||
            cleanFragment == '/admin' ||
            cleanFragment.startsWith('/admin') ||
            fragment == 'admin' ||
            fragment == '/admin' ||
            fragment.startsWith('/admin') ||
            fragment.startsWith('admin') ||
            fragment.contains('/admin');

        if (isAdminPath || isAdminFragment || hasAdminInUrl) {
          if (kDebugMode) {
            debugPrint(
              '[RouteHandler] ✅ Admin route detected FIRST, checking authentication and role...',
            );
            debugPrint('[RouteHandler] Admin - Path: $normalizedPath');
            debugPrint('[RouteHandler] Admin - Fragment: $fragment');
            debugPrint('[RouteHandler] Admin - Clean Fragment: $cleanFragment');
            debugPrint('[RouteHandler] Admin - Normalized Fragment: $normalizedFragment');
            debugPrint('[RouteHandler] Admin - Full URI: $fullUri');
            debugPrint('[RouteHandler] Admin - isAdminPath: $isAdminPath');
            debugPrint('[RouteHandler] Admin - isAdminFragment: $isAdminFragment');
            debugPrint('[RouteHandler] Admin - hasAdminInUrl: $hasAdminInUrl');
          }
          // Verificar autenticación y rol para admin
          return _AdminRouteHandler();
        }

        // Verificar si la ruta o el fragmento contiene /welcome
        final hasWelcomeInUrl = fullUri.contains('/welcome') || fullUri.contains('#/welcome');
        final isWelcomePath = normalizedPath.endsWith('/welcome') || normalizedPath == '/welcome';
        final isWelcomeFragment =
            normalizedFragment == '/welcome' ||
            normalizedFragment == '/welcome/' ||
            normalizedFragment.contains('/welcome') ||
            fragment == 'welcome' ||
            fragment == '/welcome';
        // Verificar si es la ruta de empresa
        final hasCompanyInUrl =
            fullUri.contains('/empresa') ||
            fullUri.contains('/company') ||
            fullUri.contains('#/empresa') ||
            fullUri.contains('#/company');
        final isCompanyPath =
            normalizedPath.endsWith('/empresa') ||
            normalizedPath == '/empresa' ||
            normalizedPath.endsWith('/company') ||
            normalizedPath == '/company';
        final isCompanyFragment =
            normalizedFragment == '/empresa' ||
            normalizedFragment == '/empresa/' ||
            normalizedFragment == '/company' ||
            normalizedFragment == '/company/' ||
            normalizedFragment.contains('/empresa') ||
            normalizedFragment.contains('/company') ||
            fragment == 'empresa' ||
            fragment == '/empresa' ||
            fragment == 'company' ||
            fragment == '/company';
        // Verificar si es la ruta raíz (/) - esta va a Admin
        final isRootPath = normalizedPath == '/' || normalizedPath.isEmpty;

        if (kDebugMode) {
          debugPrint('[RouteHandler] Normalized path: $normalizedPath');
          debugPrint('[RouteHandler] Normalized fragment: $normalizedFragment');
          debugPrint('[RouteHandler] isWelcomePath: $isWelcomePath');
          debugPrint('[RouteHandler] isWelcomeFragment: $isWelcomeFragment');
          debugPrint('[RouteHandler] hasWelcomeInUrl: $hasWelcomeInUrl');
          debugPrint('[RouteHandler] isCompanyPath: $isCompanyPath');
          debugPrint('[RouteHandler] isCompanyFragment: $isCompanyFragment');
          debugPrint('[RouteHandler] hasCompanyInUrl: $hasCompanyInUrl');
          debugPrint('[RouteHandler] isRootPath: $isRootPath');
        }

        // Verificar si es la ruta de destinos
        final hasDestinationInUrl =
            fullUri.contains('/destino') ||
            fullUri.contains('/destination') ||
            fullUri.contains('/destinos') ||
            fullUri.contains('#/destino') ||
            fullUri.contains('#/destination') ||
            fullUri.contains('#/destinos');
        final isDestinationPath =
            normalizedPath.endsWith('/destino') ||
            normalizedPath == '/destino' ||
            normalizedPath.endsWith('/destination') ||
            normalizedPath == '/destination' ||
            normalizedPath.endsWith('/destinos') ||
            normalizedPath == '/destinos';
        final isDestinationFragment =
            normalizedFragment == '/destino' ||
            normalizedFragment == '/destino/' ||
            normalizedFragment == '/destination' ||
            normalizedFragment == '/destination/' ||
            normalizedFragment == '/destinos' ||
            normalizedFragment == '/destinos/' ||
            normalizedFragment.contains('/destino') ||
            normalizedFragment.contains('/destination') ||
            normalizedFragment.contains('/destinos') ||
            fragment == 'destino' ||
            fragment == '/destino' ||
            fragment == 'destination' ||
            fragment == '/destination' ||
            fragment == 'destinos' ||
            fragment == '/destinos';

        // Mostrar CompanyScreen si es /empresa o /company
        if (isCompanyPath || isCompanyFragment || hasCompanyInUrl) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] Showing CompanyScreen (public for users)');
          }
          return const CompanyScreen();
        }

        // Verificar si es la ruta de contactos
        final hasContactsInUrl =
            fullUri.contains('/contactos') ||
            fullUri.contains('/contacts') ||
            fullUri.contains('/contacto') ||
            fullUri.contains('#/contactos') ||
            fullUri.contains('#/contacts') ||
            fullUri.contains('#/contacto');
        final isContactsPath =
            normalizedPath.endsWith('/contactos') ||
            normalizedPath == '/contactos' ||
            normalizedPath.endsWith('/contacts') ||
            normalizedPath == '/contacts' ||
            normalizedPath.endsWith('/contacto') ||
            normalizedPath == '/contacto';
        final isContactsFragment =
            normalizedFragment == '/contactos' ||
            normalizedFragment == '/contactos/' ||
            normalizedFragment == '/contacts' ||
            normalizedFragment == '/contacts/' ||
            normalizedFragment == '/contacto' ||
            normalizedFragment == '/contacto/' ||
            normalizedFragment.contains('/contactos') ||
            normalizedFragment.contains('/contacts') ||
            normalizedFragment.contains('/contacto') ||
            fragment == 'contactos' ||
            fragment == '/contactos' ||
            fragment == 'contacts' ||
            fragment == '/contacts' ||
            fragment == 'contacto' ||
            fragment == '/contacto';

        // Mostrar DestinationsScreen si es /destino, /destination o /destinos
        if (isDestinationPath || isDestinationFragment || hasDestinationInUrl) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] Showing DestinationsScreen (public for users)');
          }
          return const DestinationsScreen();
        }

        // Mostrar ContactsScreen si es /contactos, /contacts o /contacto
        if (isContactsPath || isContactsFragment || hasContactsInUrl) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] Showing ContactsScreen (public for users)');
          }
          return const ContactsScreen();
        }

        // Manejar retorno de Stripe Checkout
        final hasPaymentSuccessInUrl =
            fullUri.contains('/payment/success') || normalizedPath.contains('/payment/success');
        final hasPaymentCancelInUrl =
            fullUri.contains('/payment/cancel') || normalizedPath.contains('/payment/cancel');

        if (hasPaymentSuccessInUrl || hasPaymentCancelInUrl) {
          if (kDebugMode) {
            debugPrint(
              '[RouteHandler] Stripe Checkout return detected: ${hasPaymentSuccessInUrl ? "success" : "cancel"}',
            );
          }
          // Importar dinámicamente para evitar dependencias circulares
          return StripeReturnScreen(isSuccess: hasPaymentSuccessInUrl);
        }

        // Verificar si es la ruta de user (/user) - alias de /welcome
        // Soporta tanto path directo (/user) como hash routing (#/user) para GitHub Pages
        final hasUserInUrl =
            fullUri.contains('/user') || fullUri.contains('#/user') || fullUri.contains('user');
        final isUserPath =
            normalizedPath.endsWith('/user') ||
            normalizedPath == '/user' ||
            normalizedPath.contains('/user/');
        final isUserFragment =
            normalizedFragment == '/user' ||
            normalizedFragment == '/user/' ||
            normalizedFragment.contains('/user') ||
            fragment == 'user' ||
            fragment == '/user' ||
            fragment.startsWith('/user') ||
            fragment.startsWith('user');

        if (isUserPath || isUserFragment || hasUserInUrl) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] User route detected (/user), showing WelcomeScreen');
            debugPrint('[RouteHandler] User - Path: $normalizedPath, Fragment: $fragment');
          }
          // /user es un alias de /welcome, mostrar WelcomeScreen directamente
          return const WelcomeScreen();
        }

        // La ruta raíz (/) siempre muestra WelcomeScreen (user normal)
        // /admin tiene su propio handler que verifica autenticación y rol
        if (isRootPath) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] Root path (/) - Showing WelcomeScreen (user normal)');
          }
          return const WelcomeScreen();
        }

        // Mostrar WelcomeScreen si es /welcome
        if (isWelcomePath || isWelcomeFragment || hasWelcomeInUrl) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] Showing WelcomeScreen (public for users)');
          }
          return const WelcomeScreen();
        }

        // Para cualquier otra ruta no reconocida, mostrar WelcomeScreen como fallback
        // (en lugar de AuthGate, ya que la raíz es para users normales)
        if (kDebugMode) {
          debugPrint('[RouteHandler] Unknown path - Showing WelcomeScreen (fallback)');
        }
        return const WelcomeScreen();
      } catch (e) {
        // Si hay un error al procesar la URL (como SecurityError),
        // mostrar AuthGate como fallback
        if (kDebugMode) {
          debugPrint('[RouteHandler] Error procesando URL: $e');
          debugPrint('[RouteHandler] Mostrando AuthGate como fallback');
        }
        return const AuthGate();
      }
    } else {
      // En móvil, detectar tipo de usuario
      return const _MobileRouteHandler();
    }
  }
}

/// Widget que maneja las rutas en móvil detectando el tipo de usuario
class _MobileRouteHandler extends StatefulWidget {
  const _MobileRouteHandler();

  @override
  State<_MobileRouteHandler> createState() => _MobileRouteHandlerState();
}

class _MobileRouteHandlerState extends State<_MobileRouteHandler> {
  final UserService _userService = UserService();
  bool _isChecking = true;
  Widget? _initialRoute;

  @override
  void initState() {
    super.initState();
    _checkUserType();
  }

  Future<void> _checkUserType() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // No hay usuario autenticado → WelcomeScreen (público para users)
        if (mounted) {
          setState(() {
            _initialRoute = const WelcomeScreen();
            _isChecking = false;
          });
        }
        if (kDebugMode) {
          debugPrint('[RouteHandler Mobile] No hay usuario autenticado → WelcomeScreen (público)');
        }
        return;
      }

      // Hay usuario autenticado → verificar su rol
      try {
        final role = await _userService
            .getUserRole(user.uid)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                if (kDebugMode) {
                  debugPrint(
                    '[RouteHandler Mobile] Timeout obteniendo rol, usando "user" por defecto',
                  );
                }
                return 'user';
              },
            );

        if (mounted) {
          setState(() {
            if (role == 'admin' || role == 'driver') {
              // Driver/Admin → AuthGate (login obligatorio o redirige según rol)
              _initialRoute = const AuthGate();
              if (kDebugMode) {
                debugPrint('[RouteHandler Mobile] Usuario es $role → AuthGate');
              }
            } else {
              // User → WelcomeScreen (público, puede usar sin login adicional)
              _initialRoute = const WelcomeScreen();
              if (kDebugMode) {
                debugPrint('[RouteHandler Mobile] Usuario es user → WelcomeScreen (público)');
              }
            }
            _isChecking = false;
          });
        }
      } catch (e) {
        // Error obteniendo rol → asumir user y mostrar WelcomeScreen
        if (mounted) {
          setState(() {
            _initialRoute = const WelcomeScreen();
            _isChecking = false;
          });
        }
        if (kDebugMode) {
          debugPrint('[RouteHandler Mobile] Error obteniendo rol: $e → WelcomeScreen (público)');
        }
      }
    } catch (e) {
      // Error general → mostrar WelcomeScreen como fallback
      if (mounted) {
        setState(() {
          _initialRoute = const WelcomeScreen();
          _isChecking = false;
        });
      }
      if (kDebugMode) {
        debugPrint('[RouteHandler Mobile] Error general: $e → WelcomeScreen (fallback)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Mostrar loading mientras verifica
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Retornar la ruta determinada
    return _initialRoute ?? const WelcomeScreen();
  }
}

/// Widget que maneja la ruta /admin verificando autenticación y rol
class _AdminRouteHandler extends StatefulWidget {
  const _AdminRouteHandler();

  @override
  State<_AdminRouteHandler> createState() => _AdminRouteHandlerState();
}

class _AdminRouteHandlerState extends State<_AdminRouteHandler> {
  final UserService _userService = UserService();
  bool _isChecking = true;
  Widget? _route;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // No hay usuario autenticado → mostrar login
        if (mounted) {
          setState(() {
            _route = const AuthGate();
            _isChecking = false;
          });
        }
        if (kDebugMode) {
          debugPrint('[AdminRouteHandler] No hay usuario autenticado → AuthGate');
        }
        return;
      }

      // Hay usuario autenticado → verificar si es admin
      try {
        final role = await _userService
            .getUserRole(user.uid)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                if (kDebugMode) {
                  debugPrint('[AdminRouteHandler] Timeout obteniendo rol, denegando acceso');
                }
                return 'user';
              },
            );

        if (mounted) {
          setState(() {
            if (role == 'admin') {
              // Es admin → mostrar AdminHomeScreen
              _route = const AdminHomeScreen();
              if (kDebugMode) {
                debugPrint('[AdminRouteHandler] Usuario es admin → AdminHomeScreen');
              }
            } else {
              // No es admin → mostrar mensaje de acceso denegado
              _route = _AccessDeniedScreen();
              if (kDebugMode) {
                debugPrint(
                  '[AdminRouteHandler] Usuario no es admin (rol: $role) → Acceso denegado',
                );
              }
            }
            _isChecking = false;
          });
        }
      } catch (e) {
        // Error obteniendo rol → denegar acceso
        if (mounted) {
          setState(() {
            _route = _AccessDeniedScreen();
            _isChecking = false;
          });
        }
        if (kDebugMode) {
          debugPrint('[AdminRouteHandler] Error obteniendo rol: $e → Acceso denegado');
        }
      }
    } catch (e) {
      // Error general → mostrar mensaje de error
      if (mounted) {
        setState(() {
          _route = _AccessDeniedScreen();
          _isChecking = false;
        });
      }
      if (kDebugMode) {
        debugPrint('[AdminRouteHandler] Error general: $e → Acceso denegado');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verificando acceso...'),
            ],
          ),
        ),
      );
    }

    return _route ?? const AuthGate();
  }
}

/// Pantalla que muestra mensaje de acceso denegado para /admin
class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Denegado'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Acceso Denegado',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'No tienes permisos para acceder al panel de administración.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Redirigir a WelcomeScreen
                  Navigator.of(
                    context,
                  ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
                },
                icon: const Icon(Icons.home),
                label: const Text('Ir a Inicio'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
