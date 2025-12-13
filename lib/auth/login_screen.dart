import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'user_service.dart';
import 'routing_screen.dart';
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
  bool _isSigningIn = false; // Guard para prevenir popup duplicado
  final UserService _userService = UserService();
  StreamSubscription<User?>? _authSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Future<Map<String, dynamic>> _firebaseAuthSignInWithGoogleWeb(Map<String, String> config) async {
    if (!kIsWeb) {
      throw UnsupportedError('Este método solo está disponible en web');
    }

    try {
      // Nota: La verificación de disponibilidad se hace implícitamente al llamar la función
      // Si la función no está disponible, se lanzará un error que será capturado más abajo

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
        final errorStr = e.toString();

        // Si el error contiene "POPUP_BLOCKED", relanzar con mensaje más claro
        if (errorStr.contains('POPUP_BLOCKED') || errorStr.contains('popup')) {
          throw Exception(
            'POPUP_BLOCKED: El popup fue bloqueado.\n\n'
            'Por favor, permite popups en tu navegador para este sitio y vuelve a intentar.',
          );
        }

        // Si el error contiene "API key", proporcionar mensaje más útil
        if (errorStr.contains('API key') || errorStr.contains('api-key')) {
          throw Exception(
            'Error de configuración de Firebase: La API key no es válida o aún no se ha propagado.\n\n'
            'Esto puede tardar hasta 5 minutos después de configurar la API key en Google Cloud Console.\n\n'
            'Por favor, espera unos minutos y vuelve a intentar, o verifica la configuración de la API key.',
          );
        }

        // Si el error es sobre Promise, intentar usar el método alternativo
        if (errorStr.contains('Promise') || errorStr.contains('LegacyJavaScriptObject')) {
          debugPrint(
            '[LoginScreen] ⚠️ Problema con Promise, el error será manejado por el fallback',
          );
          // Relanzar para que se use el fallback
          rethrow;
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

      // Verificar si se usó redirect
      if (resultMap['redirect'] == true) {
        debugPrint('[LoginScreen] ✅ Redirect iniciado, la página se recargará');
        // El redirect ya se inició, la página se recargará automáticamente
        // No necesitamos hacer nada más aquí
        throw Exception('REDIRECT_INICIADO: La autenticación se completará después de la redirección.');
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
      if (idToken == null || idToken.isEmpty) {
        debugPrint('[LoginScreen] ❌ idToken es null o vacío');
        throw Exception('No se pudo obtener el idToken de la autenticación');
      }

      // accessToken puede ser opcional en algunos casos
      // Firebase puede funcionar solo con idToken si accessToken no está disponible
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[LoginScreen] ⚠️ accessToken no está disponible, pero idToken está disponible');
        debugPrint('[LoginScreen] ℹ️ Firebase puede funcionar solo con idToken');
      }

      return {
        'idToken': idToken,
        'accessToken': accessToken?.isNotEmpty == true ? accessToken! : '',
      };
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
    
    // En web, verificar si hay resultado de redirect cuando la página se carga
    if (kIsWeb) {
      _checkRedirectResult();
    }
    
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
  
  // Verificar si hay resultado de redirect cuando la página se carga
  Future<void> _checkRedirectResult() async {
    if (!kIsWeb) return;
    
    try {
      // Obtener configuración de Firebase
      final firebaseOptions = await DefaultFirebaseOptions.currentPlatform;
      final firebaseConfig = <String, String>{
        'apiKey': firebaseOptions.apiKey,
        'authDomain': firebaseOptions.authDomain ?? '',
        'projectId': firebaseOptions.projectId,
        if (firebaseOptions.storageBucket != null)
          'storageBucket': firebaseOptions.storageBucket!,
        'messagingSenderId': firebaseOptions.messagingSenderId,
        'appId': firebaseOptions.appId,
      };
      
      // Llamar a la función JavaScript para obtener el resultado del redirect
      final jsConfig = jsify(firebaseConfig);
      final jsPromise = firebaseAuthGetRedirectResultJS(jsConfig);
      
      // Convertir JSPromise a Future
      final jsResult = await jsPromise.toDart;
      
      if (jsResult == null) {
        // No hay resultado del redirect
        return;
      }
      
      // Extraer los datos del resultado
      final resultMap = dartify(jsResult as dynamic);
      if (resultMap is! Map) {
        return;
      }
      
      final credentialData = resultMap['credential'] as Map?;
      final idToken = credentialData?['idToken'] as String?;
      final accessToken = credentialData?['accessToken'] as String?;
      
      if (idToken == null || idToken.isEmpty) {
        return;
      }
      
      // Autenticar con Firebase usando los tokens del redirect
      debugPrint('[LoginScreen] ✅ Resultado de redirect encontrado, autenticando...');
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken?.isNotEmpty == true ? accessToken : null,
        idToken: idToken,
      );
      
      await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('[LoginScreen] ✅ Autenticado con resultado de redirect');
      
      // La navegación se manejará automáticamente por el authStateChanges listener
    } catch (e) {
      // Si hay error, simplemente continuar (puede que no haya resultado de redirect)
      debugPrint('[LoginScreen] No hay resultado de redirect o error al procesarlo: $e');
    }
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

          // Log de la configuración (solo primeros y últimos caracteres de API key por seguridad)
          debugPrint('[LoginScreen] Configuración de Firebase para web:');
          debugPrint(
            '[LoginScreen] API Key: ${firebaseOptions.apiKey.substring(0, 10)}...${firebaseOptions.apiKey.substring(firebaseOptions.apiKey.length - 5)} (longitud: ${firebaseOptions.apiKey.length})',
          );
          debugPrint('[LoginScreen] Project ID: ${firebaseOptions.projectId}');
          debugPrint('[LoginScreen] Auth Domain: ${firebaseOptions.authDomain}');
          debugPrint('[LoginScreen] Messaging Sender ID: ${firebaseOptions.messagingSenderId}');
          debugPrint('[LoginScreen] App ID: ${firebaseOptions.appId}');

          // Llamar a la función JavaScript usando js_interop
          final tokens = await _firebaseAuthSignInWithGoogleWeb(firebaseConfig);
          
          final idToken = tokens['idToken'] as String?;
          final accessToken = tokens['accessToken'] as String?;
          
          // Si no hay tokens, puede ser que se usó redirect
          if (idToken == null || idToken.isEmpty) {
            debugPrint('[LoginScreen] ⚠️ No hay tokens, puede ser que se usó redirect');
            _isSigningIn = false;
            if (mounted) setState(() => _isLoading = false);
            return;
          }

          debugPrint('[LoginScreen] ✅ Tokens obtenidos de Firebase Auth JS');
          debugPrint('[LoginScreen] idToken: ${idToken.isNotEmpty ? "✅ Disponible" : "❌ Vacío"}');
          debugPrint(
            '[LoginScreen] accessToken: ${accessToken != null && accessToken.isNotEmpty ? "✅ Disponible" : "⚠️ No disponible (usando solo idToken)"}',
          );

          // Crear credencial y autenticar con Firebase
          // Firebase puede funcionar solo con idToken si accessToken no está disponible
          final credential = GoogleAuthProvider.credential(
            accessToken: accessToken?.isNotEmpty == true ? accessToken : null,
            idToken: idToken,
          );

          debugPrint('[LoginScreen] Autenticando con Firebase...');
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          debugPrint('[LoginScreen] ✅ Autenticado con Firebase');
        } catch (e) {
          final errorMessage = e.toString();
          debugPrint('[LoginScreen] ⚠️ Error con Firebase Auth JS: $errorMessage');

          // Si el error es de popup bloqueado o redirect iniciado, el redirect ya se manejó
          if (errorMessage.contains('REDIRECT_INICIADO')) {
            debugPrint('[LoginScreen] ✅ Redirect iniciado, esperando recarga de página');
            _isSigningIn = false;
            if (mounted) setState(() => _isLoading = false);
            // Mostrar mensaje informativo
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Redirigiendo a Google para autenticación...',
                  ),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
          
          // Si el error es de popup bloqueado, el código JS ya intentó usar redirect
          // Si llegamos aquí, significa que el redirect también falló
          if (errorMessage.contains('POPUP_BLOCKED') || errorMessage.contains('popup')) {
            _isSigningIn = false;
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'No se pudo iniciar la autenticación. Por favor, verifica la configuración del navegador.',
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
            _isSigningIn = false;
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
