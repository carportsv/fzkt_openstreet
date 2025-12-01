import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_gate.dart';
import '../auth/user_service.dart';
import '../screens/welcome/welcome/welcome_screen.dart';
import '../screens/welcome/welcome/company_screen.dart';
import '../screens/welcome/welcome/destinations_screen.dart';
import '../screens/welcome/welcome/contacts_screen.dart';

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
        final fragment = Uri.base.fragment;
        // Obtener la URL completa para verificar el hash
        final fullUri = Uri.base.toString();

        if (kDebugMode) {
          debugPrint('[RouteHandler] Current path: $path');
          debugPrint('[RouteHandler] Current fragment: $fragment');
          debugPrint('[RouteHandler] Full URI: $fullUri');
        }

        // Normalizar el path removiendo el base-href si está presente
        String normalizedPath = path;
        if (path.startsWith('/fzkt_openstreet')) {
          normalizedPath = path.replaceFirst('/fzkt_openstreet', '');
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

        // Mostrar WelcomeScreen SOLO si es /welcome (no en la raíz)
        if (isWelcomePath || isWelcomeFragment || hasWelcomeInUrl) {
          if (kDebugMode) {
            debugPrint('[RouteHandler] Showing WelcomeScreen (public for users)');
          }
          return const WelcomeScreen();
        }

        // Para la ruta raíz (/) o cualquier otra ruta, mostrar AuthGate
        // Esto redirige a Admin si es admin, o a login si no está autenticado
        if (kDebugMode) {
          if (isRootPath) {
            debugPrint('[RouteHandler] Root path (/) - Showing AuthGate (will redirect to Admin)');
          } else {
            debugPrint('[RouteHandler] Other path - Showing AuthGate');
          }
        }
        return const AuthGate();
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
