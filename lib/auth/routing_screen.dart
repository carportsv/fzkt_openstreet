import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import other screens from their correct locations
import 'package:fzkt_openstreet/screens/admin/admin_home_screen.dart';
import 'package:fzkt_openstreet/screens/driver/driver_home_screen.dart';
import 'package:fzkt_openstreet/screens/welcome/welcome/welcome_screen.dart';

// Import local auth files
import './login_screen.dart';
import 'user_service.dart';

class RoutingScreen extends StatefulWidget {
  const RoutingScreen({super.key});

  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  // Instantiate the service directly. No Provider needed.
  final UserService _userService = UserService();
  String? _lastProcessedUserId; // Track del último usuario procesado
  StreamSubscription<User?>? _authSubscription; // Suscripción para cancelar en dispose

  @override
  void initState() {
    super.initState();
    _redirectUser();
    // Escuchar cambios de autenticación para re-ejecutar cuando cambie el usuario
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      final currentUserId = user?.uid;
      // Si el usuario cambió, re-ejecutar la redirección
      if (currentUserId != _lastProcessedUserId) {
        if (mounted) {
          _redirectUser();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _redirectUser() async {
    // Pequeño delay para asegurar que el contexto esté listo
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Actualizar el último usuario procesado a null
      _lastProcessedUserId = null;
      if (mounted) {
        // En web, después de logout, redirigir a WelcomeScreen
        // En móvil, redirigir a LoginScreen
        if (kIsWeb) {
          if (kDebugMode) {
            debugPrint('[RoutingScreen] Web - Usuario null, redirigiendo a WelcomeScreen');
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        } else {
          if (kDebugMode) {
            debugPrint('[RoutingScreen] Móvil - Usuario null, redirigiendo a LoginScreen');
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
      return;
    }

    // Navegar inmediatamente con rol por defecto, luego actualizar si es necesario
    // Los usuarios regulares van a WelcomeScreen (pantalla pública)
    Widget destination = const WelcomeScreen();

    // CRÍTICO: Sincronizar PRIMERO para asegurar que el usuario existe en Supabase
    // Esto es especialmente importante en web donde puede ser la primera vez
    try {
      debugPrint('[RoutingScreen] Sincronizando usuario con Supabase primero...');
      debugPrint('[RoutingScreen] UID del usuario: ${user.uid}, Email: ${user.email}');
      final syncResult = await _userService.syncUserWithSupabase();
      debugPrint('[RoutingScreen] Sincronización completada: $syncResult');
      // Esperar un poco para asegurar que la sincronización se complete en la BD
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[RoutingScreen] Error en sincronización: $e. Continuando...');
    }

    // Intentar obtener el rol con múltiples intentos para evitar confusión
    String role = 'user'; // Valor por defecto
    int maxAttempts = 3;
    int attempt = 0;
    bool roleObtained = false;

    while (!roleObtained && attempt < maxAttempts) {
      attempt++;
      try {
        debugPrint(
          '[RoutingScreen] Intento $attempt/$maxAttempts: Obteniendo rol del usuario: ${user.uid}',
        );
        role = await _userService
            .getUserRole(user.uid)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('[RoutingScreen] ⚠️ Timeout en intento $attempt/$maxAttempts');
                return 'user'; // Retornar 'user' en caso de timeout
              },
            );

        roleObtained = true;
        debugPrint('[RoutingScreen] ✅ User role obtenido en intento $attempt: $role');
        debugPrint('[RoutingScreen] 🔍 Verificando rol obtenido: $role para UID: ${user.uid}');

        // Si el rol es 'user' pero esperábamos 'admin', intentar una vez más después de un delay
        if (role == 'user' && attempt < maxAttempts) {
          debugPrint('[RoutingScreen] ⚠️ Rol es "user", esperando un poco más y reintentando...');
          await Future.delayed(const Duration(milliseconds: 1000));
          final retryRole = await _userService
              .getUserRole(user.uid)
              .timeout(const Duration(seconds: 5), onTimeout: () => 'user');
          if (retryRole != 'user') {
            debugPrint('[RoutingScreen] ✅ Rol corregido después de retry: $retryRole');
            role = retryRole;
          }
        }
      } catch (e) {
        debugPrint('[RoutingScreen] ❌ Error en intento $attempt/$maxAttempts: $e');
        if (attempt < maxAttempts) {
          // Esperar un poco antes de reintentar
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        } else {
          // Si es el último intento y falló, usar 'user' por defecto
          debugPrint(
            '[RoutingScreen] ⚠️ No se pudo obtener el rol después de $maxAttempts intentos. Usando "user" por defecto.',
          );
          debugPrint('[RoutingScreen] ⚠️ UID del usuario: ${user.uid}, Email: ${user.email}');
        }
      }
    }

    if (!mounted) return;

    switch (role) {
      case 'admin':
        destination = const AdminHomeScreen();
        break;
      case 'driver':
        destination = const DriverHomeScreen();
        break;
      default:
        // Usuarios regulares van a WelcomeScreen (pantalla pública)
        destination = const WelcomeScreen();
        break;
    }

    // Actualizar el último usuario procesado
    _lastProcessedUserId = user.uid;

    // Navegar inmediatamente, limpiando todo el stack de navegación
    // Esto asegura que no queden pantallas anteriores en el stack
    if (mounted) {
      debugPrint('[RoutingScreen] 🚀 Navigating to destination for role: $role');
      debugPrint('[RoutingScreen] 🚀 User UID: ${user.uid}');
      Navigator.of(
        context,
      ).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => destination), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
