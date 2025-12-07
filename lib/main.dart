import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth/firebase_options.dart';
import 'auth/supabase_service.dart';
import 'router/route_handler.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_provider.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  // En Flutter Web, el navegador solo puede acceder a assets servidos por HTTP
  // Por eso usamos 'env' (sin punto) como asset en lugar de '.env'
  // El archivo 'env' está en la raíz del proyecto y se declara en pubspec.yaml
  bool envLoaded = false;

  try {
    // Cargar desde 'env' (asset) - funciona en todas las plataformas
    await dotenv.load(fileName: "env");
    envLoaded = true;
    if (kDebugMode) {
      debugPrint('✅ Variables de entorno cargadas exitosamente desde env');
    }
  } catch (e) {
    // En Flutter Web, si el asset no se encuentra, continuar sin bloquear la app
    // Esto permite que la app funcione aunque el archivo env no esté disponible
    if (kDebugMode) {
      debugPrint('⚠️ No se pudo cargar el archivo env: ${e.toString()}');
      debugPrint('⚠️ La app continuará, pero puede fallar la inicialización de Firebase/Supabase');
      debugPrint('💡 Asegúrate de que el archivo "env" existe en la raíz y está en pubspec.yaml');
      debugPrint(
        '💡 Si estás en desarrollo, ejecuta: flutter clean && flutter pub get && flutter run',
      );
    }
    // No marcar como cargado, pero permitir que la app continúe
    envLoaded = false;
  }

  // Initialize Firebase solo si las variables de entorno están cargadas
  if (envLoaded) {
    try {
      // Verificar si Firebase ya está inicializado antes de intentar inicializarlo
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: await DefaultFirebaseOptions.currentPlatform);
        debugPrint('✅ Firebase inicializado');
      } else {
        debugPrint('✅ Firebase ya estaba inicializado (hot restart)');
      }
    } catch (e, stackTrace) {
      // Convertir excepción a string de forma segura para Flutter Web
      final errorMessage = e.toString();
      final stackTraceMessage = stackTrace.toString();

      // Ignorar el error de app duplicada (común en hot restart)
      if (errorMessage.contains('duplicate-app') || errorMessage.contains('already exists')) {
        debugPrint('⚠️ Firebase ya inicializado (ignorando error de app duplicada)');
      } else {
        debugPrint('❌ Error inicializando Firebase: $errorMessage');
        debugPrint('Stack trace: $stackTraceMessage');
      }
      // Continuar aunque Firebase falle - la app mostrará un error en AuthGate
    }
  }

  // Initialize Supabase solo si las variables de entorno están cargadas
  if (envLoaded) {
    try {
      await SupabaseService().initialize();
      debugPrint('✅ Supabase inicializado');
    } catch (e, stackTrace) {
      // Convertir excepción a string de forma segura para Flutter Web
      final errorMessage = e.toString();
      final stackTraceMessage = stackTrace.toString();
      // Log error but don't crash the app - Supabase operations will fail gracefully
      debugPrint('⚠️ Warning: Could not initialize Supabase: $errorMessage');
      debugPrint('Stack trace: $stackTraceMessage');
      // Continuar - las operaciones de Supabase manejarán el error
    }
  } else {
    if (kDebugMode) {
      debugPrint('⚠️ Supabase no se inicializará: variables de entorno no disponibles');
    }
  }

  // Inicializar servicio de notificaciones push (solo en móvil, no en web)
  if (!kIsWeb && envLoaded) {
    try {
      // Configurar handler para mensajes en segundo plano
      // Nota: Esto puede fallar en hot reload, pero es normal
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ No se pudo configurar background handler (puede ser normal en hot reload): $e',
          );
        }
      }

      // Inicializar servicio de notificaciones
      await PushNotificationService().initialize();
      debugPrint('✅ Servicio de notificaciones push inicializado');
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Plugins nativos no disponibles (ejecuta flutter clean && flutter run): $e',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Warning: Could not initialize push notifications: $e');
        debugPrint('💡 Ejecuta: flutter clean && flutter pub get && flutter run');
      }
    }
  }

  // Configurar error handler global para Flutter Web
  FlutterError.onError = (FlutterErrorDetails details) {
    // Convertir excepción a string de forma segura para Flutter Web
    final errorString = details.exception.toString();

    // Ignorar errores 429 (Too Many Requests) - son temporales y no críticos
    if (errorString.contains('statusCode: 429') || errorString.contains('Too Many Requests')) {
      // No loguear estos errores como críticos
      return;
    }

    // Ignorar errores de carga de imágenes de red que ya tienen fallback
    if (errorString.contains('NetworkImageLoadException') ||
        errorString.contains('HTTP request failed')) {
      // Estos errores ya son manejados por SafeNetworkImage
      return;
    }

    if (kDebugMode) {
      debugPrint('❌ Error no manejado: $errorString');
      debugPrint('Stack trace: ${details.stack}');
    }
    FlutterError.presentError(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const RouteHandler(),
            // Prevenir que Flutter intente manipular el historial automáticamente
            // Esto evita el SecurityError cuando hay URLs con dobles barras
            restorationScopeId: null,
            // Localizaciones para DatePicker y otros widgets de Material
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeProvider.locale, // Idioma dinámico
            // Usar un builder para capturar errores de routing
            builder: (context, child) {
              // Si hay un error, mostrar el widget hijo de todas formas
              return child ?? const RouteHandler();
            },
          );
        },
      ),
    );
  }
}
