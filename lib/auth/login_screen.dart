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
import '../screens/welcome/welcome/welcome_screen.dart';
import '../screens/welcome/carousel/background/background_carousel.dart';

// Importar funciones JS interop condicionalmente
// En web: usa js_interop_web.dart con dart:js_interop
// En móvil: usa js_interop_mobile.dart con stubs
// Nota: Importamos sin 'show' para que las extensiones estén disponibles
import 'js_interop_mobile.dart' if (dart.library.html) 'js_interop_web.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

// This screen handles the UI for the login and the Firebase Google Sign-In logic.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  final UserService _userService = UserService();
  StreamSubscription<User?>? _authSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Future<Map<String, dynamic>> _firebaseAuthSignInWithGoogleWeb(Map<String, String> config) async {
    if (!kIsWeb) {
      throw UnsupportedError('Este método solo está disponible en web');
    }

    try {
      // En web, usar js_interop directamente
      // jsify y dartify son funciones top-level importadas condicionalmente
      final jsConfig = jsify(config);

      // Llamar a la función JavaScript y convertir JSPromise a Future
      final jsPromise = firebaseAuthSignInWithGoogleJS(jsConfig);

      // Convertir JSPromise a Future usando la extensión toDart
      dynamic jsResult;
      try {
        // Convertir JSPromise a Future usando la extensión toDart
        jsResult = await jsPromise.toDart;
      } catch (e) {
        debugPrint('[LoginScreen] Error al convertir JSPromise: ${e.toString()}');
        // Si el error contiene "POPUP_BLOCKED", relanzar con mensaje más claro
        final errorStr = e.toString();
        if (errorStr.contains('POPUP_BLOCKED') || errorStr.contains('popup')) {
          throw Exception(
            'POPUP_BLOCKED: El popup fue bloqueado.\n\n'
            'Por favor, permite popups en tu navegador para este sitio y vuelve a intentar.',
          );
        }
        rethrow;
      }

      // Verificar que jsResult no sea null
      if (jsResult == null) {
        throw Exception(
          'El resultado de la autenticación es null.\n\n'
          'Esto puede ocurrir si el popup fue bloqueado o cerrado.\n'
          'Por favor, permite popups en tu navegador para este sitio.',
        );
      }

      // Extraer los datos del resultado usando dartify
      // jsResult es un JSObject cuando viene de toDart
      final resultMap = dartify(jsResult as dynamic);

      // Verificar que resultMap es un Map antes de acceder
      if (resultMap is! Map) {
        throw Exception('Resultado inesperado de la autenticación: ${resultMap.runtimeType}');
      }

      final credentialData = resultMap['credential'] as Map?;
      final idToken = credentialData?['idToken'] as String?;
      final accessToken = credentialData?['accessToken'] as String?;

      // Si no hay tokens en credential, intentar obtener idToken del usuario
      if (idToken == null && accessToken == null) {
        // Verificar si hay un usuario en el resultado
        final userData = resultMap['user'] as Map?;
        if (userData != null) {
          debugPrint(
            '[LoginScreen] ⚠️ No hay credential, pero hay user. El usuario puede estar ya autenticado.',
          );
          // Si el usuario ya está autenticado, Firebase Auth puede manejar esto automáticamente
          // Retornar null para que el código continúe con el flujo normal
          throw Exception(
            'No se pudieron obtener los tokens de autenticación del popup.\n'
            'El usuario puede estar ya autenticado. Verificando estado...',
          );
        }

        throw Exception(
          'No se pudieron obtener los tokens de autenticación. idToken: ${idToken != null}, accessToken: ${accessToken != null}',
        );
      }

      // Verificar que al menos idToken esté disponible (requerido por Firebase)
      if (idToken == null) {
        debugPrint('[LoginScreen] ⚠️ idToken es null, pero accessToken está disponible');
        throw Exception('No se pudo obtener el idToken de la autenticación');
      }

      // accessToken puede ser opcional en algunos casos, pero intentar obtenerlo
      if (accessToken == null) {
        debugPrint('[LoginScreen] ⚠️ accessToken es null, pero idToken está disponible');
        // Firebase puede funcionar solo con idToken en algunos casos
        // Usar string vacío como fallback
      }

      return {'idToken': idToken, 'accessToken': accessToken ?? ''};
    } catch (e) {
      debugPrint('[LoginScreen] Error en _firebaseAuthSignInWithGoogleWeb: ${e.toString()}');
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    // Inicializar animación de pulso
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
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
            debugPrint('[LoginScreen] ⚠️ Error obteniendo rol en stream: ${e.toString()}');
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
    _pulseController.dispose();
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
          final errorMessage = e.toString();
          debugPrint('[LoginScreen] ⚠️ Error con Firebase Auth JS: $errorMessage');

          // Si el error es de popup bloqueado, mostrar mensaje claro y no intentar fallback
          if (errorMessage.contains('POPUP_BLOCKED') || errorMessage.contains('popup')) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'El popup fue bloqueado. Por favor, permite popups en tu navegador para este sitio.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Entendido',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
            return;
          }

          // Fallback a google_sign_in solo si el error no es de popup bloqueado
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

          // En web, google_sign_in puede no retornar idToken con el método deprecado
          // Intentar autenticar solo con accessToken si idToken no está disponible
          if (googleAuth.accessToken == null) {
            throw Exception(
              'Error: No se pudo obtener el token de acceso de Google.\n\n'
              'Por favor, permite popups en tu navegador para este sitio.',
            );
          }

          // Si no hay idToken, intentar obtenerlo usando el accessToken
          if (googleAuth.idToken == null) {
            debugPrint(
              '[LoginScreen] ⚠️ idToken no disponible, intentando obtener con accessToken...',
            );
            // Intentar usar solo accessToken (puede no funcionar con Firebase Auth)
            // En este caso, mejor mostrar un error más claro
            throw Exception(
              'Error: No se pudo obtener el token de identidad de Google.\n\n'
              'Esto puede ocurrir si los popups están bloqueados.\n'
              'Por favor, permite popups en tu navegador para este sitio y vuelve a intentar.',
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
          debugPrint('[LoginScreen] ⚠️ Error obteniendo rol: ${e.toString()}');
          // En caso de error, redirigir a /welcome
          if (mounted) {
            Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
          }
        }
      }
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      final stackTraceMessage = stackTrace.toString();
      debugPrint('[LoginScreen] ❌ ERROR: $errorMessage');
      debugPrint('[LoginScreen] Stack trace: $stackTraceMessage');
      if (mounted) {
        final safeErrorMessage = errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: $safeErrorMessage'),
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Carrusel de imágenes de fondo (igual que welcome)
          Positioned.fill(child: const BackgroundCarousel()),
          // Overlay oscuro con gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1C1C1C).withValues(alpha: 0.4),
                  const Color(0xFF000000).withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          // Contenedor principal con glassmorphism
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: _kSpacing * 2),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(_kBorderRadius * 2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(_kSpacing * 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo o ícono decorativo con gradiente
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _kPrimaryColor.withValues(alpha: 0.2),
                              _kPrimaryColor.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _kPrimaryColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(Icons.local_taxi, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: _kSpacing * 2.5),

                      // Título
                      Text(
                        'Bienvenido',
                        style: GoogleFonts.exo(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: _kSpacing * 3),

                      // Botón de Google con estilo glassmorphism
                      _isLoading
                          ? const SizedBox.shrink()
                          : Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(_kBorderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kPrimaryColor.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _signInWithGoogle,
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.asset(
                                    'assets/images/otros/google_sig.png',
                                    height: 20,
                                    width: 20,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.login, color: Colors.white, size: 20);
                                    },
                                  ),
                                ),
                                label: Text(
                                  'Iniciar sesión con Google',
                                  style: GoogleFonts.exo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kPrimaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(_kBorderRadius),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Overlay de carga con logo_21 cuando está cargando
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo con animación de pulso continua
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _kPrimaryColor.withValues(alpha: 0.6),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/logo_21.png',
                                width: 150,
                                height: 150,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.local_taxi, size: 100, color: Colors.white);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: _kSpacing * 2.5),
                    // Texto de carga
                    Text(
                      'Iniciando sesión...',
                      style: GoogleFonts.exo(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: _kSpacing * 1.5),
                    // Indicador de progreso
                    SizedBox(
                      width: 250,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(_kPrimaryColor),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
