import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_service.dart';
import 'routing_screen.dart';
import '../screens/welcome/carousel/background/background_carousel.dart';

// Importar funciones JS interop condicionalmente
// En web: usa js_interop_web.dart con dart:js_interop
// En móvil: usa js_interop_mobile.dart con stubs
// Nota: Importamos sin 'show' para que las extensiones estén disponibles

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
  bool _isSigningIn = false; // Guard para prevenir popup duplicado
  final UserService _userService = UserService();
  StreamSubscription<User?>? _authSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;


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

    // Escuchar cambios de autenticación para navegar cuando el usuario se autentique
    // Esto es especialmente importante después de logout/login cuando LoginScreen está directamente en el stack
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      // Prevenir navegación duplicada si ya estamos procesando el login
      if (user != null && mounted && !_isLoading && !_isSigningIn) {
        if (kDebugMode) {
          debugPrint(
            '[LoginScreen] ✅ Usuario autenticado (${user.uid}), navegando a RoutingScreen',
          );
        }
        // Navegar a RoutingScreen que verificará el rol y navegará a la pantalla correcta
        // Esto es necesario cuando LoginScreen está directamente en el stack (después de logout)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Importar RoutingScreen dinámicamente para evitar dependencias circulares
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
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    // Prevenir múltiples llamadas simultáneas
    if (_isLoading || _isSigningIn) {
      debugPrint('[LoginScreen] ⚠️ Sign-in ya en progreso, ignorando llamada duplicada');
      return;
    }
    _isSigningIn = true;
    setState(() => _isLoading = true);

    try {
      debugPrint('[LoginScreen] Iniciando Google Sign-In...');

      // Intentar ambas variables por compatibilidad
      final webClientId =
          dotenv.env['EXPO_PUBLIC_GOOGLE_CLIENT_ID'] ??
          dotenv.env['EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID'];
      final androidClientId = dotenv.env['EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID'];
      debugPrint('[LoginScreen] webClientId: ${webClientId != null ? "✅ configurado" : "❌ null"}');
      debugPrint(
        '[LoginScreen] androidClientId: ${androidClientId != null ? "✅ configurado" : "❌ null"}',
      );

      UserCredential userCredential;

      if (kIsWeb) {
        // En web, usar Firebase Auth directamente con signInWithPopup
        debugPrint('[LoginScreen] Usando Firebase Auth signInWithPopup para web...');
        try {
          final googleProvider = GoogleAuthProvider();
          userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
          debugPrint('[LoginScreen] ✅ Autenticado con Firebase usando signInWithPopup');
        } catch (e) {
          final errorMessage = e.toString();
          debugPrint('[LoginScreen] ⚠️ Error con Firebase Auth signInWithPopup: $errorMessage');

          // Manejar errores específicos de popup
          if (errorMessage.contains('popup-blocked') ||
              errorMessage.contains('popup_closed_by_user') ||
              errorMessage.contains('POPUP_BLOCKED')) {
            _isSigningIn = false;
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

          // Si hay otro error, relanzarlo para que se muestre al usuario
          rethrow;
        }
      } else {
        // Para móvil, usar google_sign_in
        // En Android, cuando el SHA-1 está registrado, normalmente no se necesita clientId
        // Pero si oauth_client está vacío en google-services.json, puede ser necesario
        debugPrint('[LoginScreen] Configurando GoogleSignIn para móvil (Android/iOS)...');
        debugPrint(
          '[LoginScreen] androidClientId: ${androidClientId != null ? "✅ configurado" : "❌ null (usando null - configuración automática)"}',
        );

        // En Android, usar serverClientId (webClientId) para obtener idToken
        // serverClientId es el Client ID de la aplicación web, necesario para obtener idToken en Android
        // Esto es diferente de clientId, que es específico para iOS
        debugPrint('[LoginScreen] Configurando GoogleSignIn para Android con serverClientId...');
        debugPrint(
          '[LoginScreen] serverClientId (webClientId): ${webClientId != null ? "✅ configurado" : "❌ null"}',
        );

        // En Android, usar serverClientId en lugar de clientId
        // serverClientId debe ser el OAuth Client ID de tipo "Web application"
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId:
              webClientId, // serverClientId es necesario en Android para obtener idToken
          scopes: ['email', 'profile'],
        );

        // IMPORTANTE: Hacer signOut primero para limpiar la caché y forzar selección de cuenta
        // Esto asegura que el usuario pueda elegir una cuenta diferente después de cerrar sesión
        try {
          debugPrint(
            '[LoginScreen] Limpiando caché de Google Sign-In para permitir selección de cuenta...',
          );
          await googleSignIn.signOut();
          // Esperar un momento para que se limpie completamente
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint(
            '[LoginScreen] ⚠️ Error al limpiar caché de Google (puede ser normal si no hay sesión): ${e.toString()}',
          );
          // Continuar aunque falle, puede que no haya sesión previa
        }

        debugPrint('[LoginScreen] Llamando a signIn() para móvil (con selector de cuenta)...');
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('[LoginScreen] Usuario canceló el inicio de sesión');
          _isSigningIn = false;
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        debugPrint('[LoginScreen] ✅ Usuario seleccionado: ${googleUser.email}');
        debugPrint('[LoginScreen] Obteniendo tokens de autenticación...');
        var googleAuth = await googleUser.authentication;

        // Log detallado de los tokens obtenidos
        debugPrint(
          '[LoginScreen] accessToken: ${googleAuth.accessToken != null ? "✅ Disponible (${googleAuth.accessToken!.substring(0, 20)}...)" : "❌ null"}',
        );
        debugPrint(
          '[LoginScreen] idToken: ${googleAuth.idToken != null ? "✅ Disponible (${googleAuth.idToken!.substring(0, 20)}...)" : "❌ null"}',
        );

        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          final errorMsg =
              'No se pudieron obtener los tokens de autenticación.\n'
              'accessToken: ${googleAuth.accessToken != null ? "✅" : "❌ null"}\n'
              'idToken: ${googleAuth.idToken != null ? "✅" : "❌ null"}\n\n'
              'Verifica que:\n'
              '1. El serverClientId (webClientId) esté configurado correctamente\n'
              '2. El OAuth Client ID de tipo "Web application" esté habilitado en Google Cloud Console\n'
              '3. El SHA-1 esté registrado en Firebase Console\n'
              '4. El package name sea correcto: com.consultancy.app';
          debugPrint('[LoginScreen] ❌ ERROR: $errorMsg');
          throw Exception(errorMsg);
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

      // Navegar a RoutingScreen que verificará el rol y navegará a la pantalla correcta
      // Esto es necesario cuando LoginScreen está directamente en el stack (después de logout)
      // El listener de authStateChanges() también navegará como respaldo
      if (mounted) {
        debugPrint('[LoginScreen] ✅ Autenticación completada, navegando a RoutingScreen');
        _isSigningIn = false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoutingScreen()),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      _isSigningIn = false;
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
      _isSigningIn = false;
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
