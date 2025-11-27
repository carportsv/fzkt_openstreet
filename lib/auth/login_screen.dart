import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'user_service.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/welcome/welcome_screen.dart';

// Importar js_interop solo en web usando importación condicional
import 'dart:js_interop' if (dart.library.io) 'dart:js_interop_stub.dart' as js_interop;

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

// Función top-level para JS interop (necesaria para usar @JS)
@js_interop.JS('firebaseAuthSignInWithGoogle')
external js_interop.JSPromise<js_interop.JSObject> _firebaseAuthSignInWithGoogleJS(
  js_interop.JSObject config,
);

// This screen handles the UI for the login and the Firebase Google Sign-In logic.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final UserService _userService = UserService();
  StreamSubscription<User?>? _authSubscription;

  Future<Map<String, dynamic>> _firebaseAuthSignInWithGoogleWeb(Map<String, String> config) async {
    if (!kIsWeb) {
      throw UnsupportedError('Este método solo está disponible en web');
    }

    // Convertir el Map a JSObject
    final jsConfig = config.jsify() as js_interop.JSObject;

    // Llamar a la función JavaScript
    final jsResult = await _firebaseAuthSignInWithGoogleJS(jsConfig).toDart;

    // Extraer los datos del resultado usando dartify
    final resultMap = jsResult.dartify() as Map?;
    final credentialData = resultMap?['credential'] as Map?;
    final idToken = credentialData?['idToken'] as String?;
    final accessToken = credentialData?['accessToken'] as String?;

    if (idToken == null || accessToken == null) {
      throw Exception('No se pudieron obtener los tokens de autenticación');
    }

    return {'idToken': idToken, 'accessToken': accessToken};
  }

  @override
  void initState() {
    super.initState();
    // Escuchar cambios de autenticación para navegar automáticamente
    // Esto es especialmente importante después de logout/login
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null && mounted && !_isLoading) {
        // Si hay un usuario y no estamos cargando, verificar rol y navegar
        if (kDebugMode) {
          debugPrint(
            '[LoginScreen] ✅ Usuario detectado en stream (${user.uid}), verificando rol...',
          );
        }
        try {
          final role = await _userService
              .getUserRole(user.uid)
              .timeout(const Duration(seconds: 5), onTimeout: () => 'user');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Solo admin puede acceder a pantallas protegidas
              if (role == 'admin') {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
                  (route) => false,
                );
              } else {
                // Usuario regular o driver: redirigir a /welcome
                Navigator.of(
                  context,
                ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
              }
            }
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[LoginScreen] ⚠️ Error obteniendo rol en stream: $e');
          }
          // En caso de error, redirigir a /welcome
          if (mounted) {
            Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('[LoginScreen] Iniciando Google Sign-In...');

      // Intentar ambas variables por compatibilidad
      final webClientId =
          dotenv.env['EXPO_PUBLIC_GOOGLE_CLIENT_ID'] ??
          dotenv.env['EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID'];
      debugPrint('[LoginScreen] webClientId: ${webClientId != null ? "✅ configurado" : "❌ null"}');

      UserCredential userCredential;

      if (kIsWeb) {
        // En web, usar Firebase Auth directamente con JavaScript interop
        debugPrint('[LoginScreen] Usando Firebase Auth directamente para web...');
        try {
          // Obtener configuración de Firebase
          final firebaseOptions = await DefaultFirebaseOptions.currentPlatform;

          // Crear objeto de configuración para JavaScript
          // Nota: FirebaseOptions valida que estos campos no sean null en tiempo de ejecución
          final firebaseConfig = <String, String>{
            'apiKey': firebaseOptions.apiKey,
            'authDomain': firebaseOptions.authDomain ?? '',
            'projectId': firebaseOptions.projectId,
            if (firebaseOptions.storageBucket != null)
              'storageBucket': firebaseOptions.storageBucket!,
            'messagingSenderId': firebaseOptions.messagingSenderId,
            'appId': firebaseOptions.appId,
          };

          // Llamar a la función JavaScript usando js_interop
          final tokens = await _firebaseAuthSignInWithGoogleWeb(firebaseConfig);
          final idToken = tokens['idToken'] as String;
          final accessToken = tokens['accessToken'] as String;

          debugPrint('[LoginScreen] ✅ Tokens obtenidos de Firebase Auth JS');

          // Crear credencial y autenticar con Firebase
          final credential = GoogleAuthProvider.credential(
            accessToken: accessToken,
            idToken: idToken,
          );

          debugPrint('[LoginScreen] Autenticando con Firebase...');
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          debugPrint('[LoginScreen] ✅ Autenticado con Firebase');
        } catch (e) {
          debugPrint('[LoginScreen] ⚠️ Error con Firebase Auth JS: $e');
          // Fallback a google_sign_in si Firebase Auth JS falla
          debugPrint('[LoginScreen] Intentando con google_sign_in como fallback...');
          final GoogleSignIn googleSignIn = GoogleSignIn(
            clientId: webClientId,
            scopes: ['email', 'profile'],
          );

          final googleUser = await googleSignIn.signIn();
          if (googleUser == null) {
            debugPrint('[LoginScreen] Usuario canceló el inicio de sesión');
            if (mounted) setState(() => _isLoading = false);
            return;
          }

          final googleAuth = await googleUser.authentication;
          if (googleAuth.accessToken == null || googleAuth.idToken == null) {
            throw Exception(
              'Error: No se pudo obtener el token de autenticación de Google.\n\n'
              'Por favor, permite popups en tu navegador para este sitio.',
            );
          }

          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        }
      } else {
        // Para móvil, usar google_sign_in
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: null,
          scopes: ['email', 'profile'],
        );

        debugPrint('[LoginScreen] Llamando a signIn() para móvil...');
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('[LoginScreen] Usuario canceló el inicio de sesión');
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        debugPrint('[LoginScreen] ✅ Usuario seleccionado: ${googleUser.email}');
        debugPrint('[LoginScreen] Obteniendo tokens de autenticación...');
        final googleAuth = await googleUser.authentication;

        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception('No se pudieron obtener los tokens de autenticación');
        }

        debugPrint('[LoginScreen] ✅ Tokens obtenidos, creando credencial...');
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        debugPrint('[LoginScreen] Autenticando con Firebase...');
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        debugPrint('[LoginScreen] ✅ Autenticado con Firebase');
      }

      final user = userCredential.user;
      if (user == null) {
        debugPrint('[LoginScreen] ⚠️ Usuario es null después de signInWithCredential');
        throw Exception('No se pudo obtener el usuario después de la autenticación');
      }

      // Sincronizar con Supabase
      debugPrint('[LoginScreen] Sincronizando con Supabase...');
      await _userService.syncUserWithSupabase();
      debugPrint('[LoginScreen] ✅ Sincronización completada');

      // Verificar rol y navegar internamente (solo admin puede acceder a pantallas protegidas)
      if (mounted) {
        try {
          final role = await _userService
              .getUserRole(user.uid)
              .timeout(const Duration(seconds: 5), onTimeout: () => 'user');

          debugPrint('[LoginScreen] ✅ Rol obtenido: $role');

          // Solo admin puede acceder a pantallas protegidas
          if (role == 'admin') {
            // Navegación interna a AdminHomeScreen (sin cambiar URL)
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
                (route) => false,
              );
            }
          } else {
            // Usuario regular o driver: redirigir a /welcome
            if (mounted) {
              Navigator.of(
                context,
              ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
            }
          }
        } catch (e) {
          debugPrint('[LoginScreen] ⚠️ Error obteniendo rol: $e');
          // En caso de error, redirigir a /welcome
          if (mounted) {
            Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[LoginScreen] ❌ ERROR: $e');
      debugPrint('[LoginScreen] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kPrimaryColor, _kPrimaryColor.withValues(alpha: 0.8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: _kSpacing * 2),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kBorderRadius * 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_kSpacing * 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo o ícono decorativo
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _kPrimaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.local_taxi, size: 40, color: _kPrimaryColor),
                        ),
                        const SizedBox(height: _kSpacing * 2),

                        // Título
                        Text(
                          'cuzcatlansv.ride',
                          style: GoogleFonts.exo(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _kTextColor,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: _kSpacing),

                        // Subtítulo
                        Text(
                          'Inicia sesión para continuar',
                          style: GoogleFonts.exo(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: _kSpacing * 3),

                        // Botón de Google
                        _isLoading
                            ? Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(_kPrimaryColor),
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _signInWithGoogle,
                                  icon: Image.asset(
                                    'assets/images/google_sig.png',
                                    height: 24,
                                    width: 24,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.login, color: Colors.white, size: 24);
                                    },
                                  ),
                                  label: Text(
                                    'Iniciar sesión con Google',
                                    style: GoogleFonts.exo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kPrimaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(_kBorderRadius),
                                    ),
                                    elevation: 3,
                                    shadowColor: _kPrimaryColor.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
