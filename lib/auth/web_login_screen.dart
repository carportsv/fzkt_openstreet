import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'user_service.dart';
import 'routing_screen.dart';

/// Pantalla de login específica para web
/// Usa Firebase Auth directamente con métodos nativos de web
class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  bool _isLoading = false;
  bool _isSignUp = false;
  final UserService _userService = UserService();
  StreamSubscription<User?>? _authSubscription;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Escuchar cambios de autenticación
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && mounted && !_isLoading) {
        if (kDebugMode) {
          debugPrint('[WebLoginScreen] ✅ Usuario detectado, navegando a RoutingScreen');
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const RoutingScreen()),
              (route) => false,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Login sencillo con email y contraseña
  Future<void> _signInWithEmailPassword() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      debugPrint('[WebLoginScreen] Iniciando sesión con email: $email');

      UserCredential userCredential;

      if (_isSignUp) {
        // Registrar nuevo usuario
        debugPrint('[WebLoginScreen] Registrando nuevo usuario...');
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('[WebLoginScreen] ✅ Usuario registrado: ${userCredential.user?.email}');
      } else {
        // Iniciar sesión
        debugPrint('[WebLoginScreen] Iniciando sesión...');
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('[WebLoginScreen] ✅ Sesión iniciada: ${userCredential.user?.email}');
      }

      final user = userCredential.user;
      if (user == null) {
        throw Exception('No se pudo obtener el usuario después de la autenticación');
      }

      // Sincronizar con Supabase
      debugPrint('[WebLoginScreen] Sincronizando con Supabase...');
      await _userService.syncUserWithSupabase();
      debugPrint('[WebLoginScreen] ✅ Sincronización completada');

      // Navegar después del login exitoso
      if (mounted) {
        debugPrint('[WebLoginScreen] ✅ Login exitoso, navegando a RoutingScreen...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoutingScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al iniciar sesión';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No existe una cuenta con este email';
          break;
        case 'wrong-password':
          errorMessage = 'Contraseña incorrecta';
          break;
        case 'email-already-in-use':
          errorMessage = 'Este email ya está registrado';
          break;
        case 'weak-password':
          errorMessage = 'La contraseña es muy débil';
          break;
        case 'invalid-email':
          errorMessage = 'Email inválido';
          break;
        default:
          errorMessage = 'Error: ${e.message ?? e.toString()}';
      }

      final errorCode = e.code;
      debugPrint('[WebLoginScreen] ❌ ERROR: $errorCode - $errorMessage');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      final stackTraceMessage = stackTrace.toString();
      debugPrint('[WebLoginScreen] ❌ ERROR: $errorMessage');
      debugPrint('[WebLoginScreen] Stack trace: $stackTraceMessage');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Login con Google optimizado para web
  /// Usa GoogleSignIn de forma más directa y simple para web
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('[WebLoginScreen] 🌐 Iniciando Google Sign-In (versión web)...');

      // Intentar desde --dart-define primero, luego desde .env
      String webClientId = const String.fromEnvironment('EXPO_PUBLIC_GOOGLE_CLIENT_ID');
      if (webClientId.isEmpty) {
        // Fallback a dotenv
        webClientId =
            dotenv.env['EXPO_PUBLIC_GOOGLE_CLIENT_ID'] ??
            dotenv.env['EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID'] ??
            '';
      }

      if (webClientId.isEmpty) {
        debugPrint('[WebLoginScreen] ❌ ERROR: EXPO_PUBLIC_GOOGLE_CLIENT_ID no está configurado');
        throw Exception(
          'EXPO_PUBLIC_GOOGLE_CLIENT_ID es requerido para web. Configúralo en .env o úsalo con --dart-define=EXPO_PUBLIC_GOOGLE_CLIENT_ID=...',
        );
      }

      debugPrint('[WebLoginScreen] ✅ webClientId configurado (${webClientId.substring(0, 20)}...)');

      // Configurar GoogleSignIn específicamente para web
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: webClientId,
        scopes: ['email', 'profile'],
        // Para web, no necesitamos configuraciones adicionales
      );

      debugPrint('[WebLoginScreen] Llamando a signIn()...');
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('[WebLoginScreen] Usuario canceló el inicio de sesión');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      debugPrint('[WebLoginScreen] ✅ Usuario seleccionado: ${googleUser.email}');
      debugPrint('[WebLoginScreen] Obteniendo tokens de autenticación...');

      final googleAuth = await googleUser.authentication;

      // En web, el idToken puede ser null (problema conocido con google_sign_in)
      if (googleAuth.accessToken == null) {
        debugPrint('[WebLoginScreen] ❌ Error: accessToken es null');
        throw Exception('No se pudo obtener el accessToken de Google');
      }

      if (googleAuth.idToken == null) {
        debugPrint('[WebLoginScreen] ⚠️ idToken es null en web (problema conocido)');
        debugPrint('[WebLoginScreen] Intentando usar solo accessToken...');

        // Intentar cerrar sesión y volver a iniciar para forzar la obtención de idToken
        try {
          await googleSignIn.signOut();
          debugPrint('[WebLoginScreen] Sesión cerrada, esperando...');
          await Future.delayed(const Duration(milliseconds: 500));

          // Intentar signIn nuevamente
          final retryUser = await googleSignIn.signIn();
          if (retryUser != null) {
            final retryAuth = await retryUser.authentication;
            if (retryAuth.idToken != null && retryAuth.accessToken != null) {
              debugPrint('[WebLoginScreen] ✅ idToken obtenido en el segundo intento');
              // Usar los tokens del segundo intento
              final credential = GoogleAuthProvider.credential(
                accessToken: retryAuth.accessToken,
                idToken: retryAuth.idToken,
              );

              final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
              final user = userCredential.user;
              if (user != null) {
                await _userService.syncUserWithSupabase();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const RoutingScreen()),
                    (route) => false,
                  );
                }
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('[WebLoginScreen] ⚠️ Segundo intento falló: ${e.toString()}');
        }

        // Si todo falla, mostrar error claro
        throw Exception(
          'No se pudo obtener el idToken de Google en web. '
          'Este es un problema conocido con google_sign_in. '
          'Solución: Cierra todas las sesiones de Google en este navegador, '
          'luego vuelve a intentar iniciar sesión.',
        );
      }

      debugPrint('[WebLoginScreen] ✅ Tokens obtenidos, creando credencial de Firebase...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('[WebLoginScreen] Autenticando con Firebase...');
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('[WebLoginScreen] ✅ Autenticado con Firebase');

      final user = userCredential.user;
      if (user == null) {
        debugPrint('[WebLoginScreen] ⚠️ Usuario es null después de signInWithCredential');
        throw Exception('No se pudo obtener el usuario después de la autenticación');
      }

      debugPrint('[WebLoginScreen] Usuario Firebase: ${user.email} (${user.uid})');

      // Sincronizar con Supabase
      debugPrint('[WebLoginScreen] Sincronizando con Supabase...');
      await _userService.syncUserWithSupabase();
      debugPrint('[WebLoginScreen] ✅ Sincronización completada');

      // Navegar después del login exitoso
      if (mounted) {
        debugPrint('[WebLoginScreen] ✅ Login exitoso, navegando a RoutingScreen...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoutingScreen()),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      final stackTraceMessage = stackTrace.toString();
      debugPrint('[WebLoginScreen] ❌ ERROR: $errorMessage');
      debugPrint('[WebLoginScreen] Stack trace: $stackTraceMessage');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 8.0,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título removido
                    const SizedBox(height: 12),
                    const Text(
                      'Inicia sesión para continuar',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Versión Web',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu email';
                              }
                              if (!value.contains('@')) {
                                return 'Email inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu contraseña';
                              }
                              if (value.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _signInWithEmailPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: Text(
                                    _isSignUp ? 'Registrarse' : 'Iniciar sesión',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                    });
                                  },
                            child: Text(
                              _isSignUp
                                  ? '¿Ya tienes cuenta? Inicia sesión'
                                  : '¿No tienes cuenta? Regístrate',
                              style: const TextStyle(color: Color(0xFF3B82F6)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('o', style: TextStyle(color: Colors.grey)),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            icon: Image.asset('assets/images/google_sig.png', height: 24.0),
                            label: const Text(
                              'Continuar con Google',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
