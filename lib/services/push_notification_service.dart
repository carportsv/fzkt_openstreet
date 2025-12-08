import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../auth/supabase_service.dart';
import '../auth/firebase_options.dart';
import 'package:flutter/services.dart';

/// Servicio para manejar notificaciones push del sistema
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;
  StreamSubscription<String>? _tokenSubscription;

  /// Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    // Solo inicializar en móvil (Android/iOS), no en web
    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] ⚠️ Notificaciones push no disponibles en web');
      }
      return;
    }

    try {
      // Solicitar permisos
      await _requestPermissions();

      // Configurar notificaciones locales
      await _initializeLocalNotifications();

      // Configurar handlers de FCM
      _setupFCMHandlers();

      // Obtener token FCM
      await _getFCMToken();

      // Escuchar cambios en el token
      _tokenSubscription = _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode) {
          debugPrint('[PushNotificationService] 🔄 Token FCM actualizado: $newToken');
        }
        // Aquí puedes guardar el token en Supabase para el driver
      });

      _initialized = true;
      if (kDebugMode) {
        debugPrint('[PushNotificationService] ✅ Servicio inicializado correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] ❌ Error inicializando: $e');
        debugPrint(
          '[PushNotificationService] 💡 Asegúrate de ejecutar: flutter clean && flutter pub get && flutter run',
        );
      }
      // No marcar como inicializado si hay error
      _initialized = false;
    }
  }

  /// Solicitar permisos de notificación
  Future<void> _requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint('[PushNotificationService] Permisos: ${settings.authorizationStatus}');
      }
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[PushNotificationService] ⚠️ Plugin no disponible (puede ser normal en hot reload): $e',
        );
        debugPrint(
          '[PushNotificationService] 💡 Ejecuta: flutter clean && flutter pub get && flutter run',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] Error solicitando permisos: $e');
      }
      rethrow;
    }
  }

  /// Inicializar notificaciones locales
  Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Crear canal de notificaciones para Android
      const androidChannel = AndroidNotificationChannel(
        'ride_notifications',
        'Notificaciones de Viajes',
        description: 'Notificaciones sobre nuevos viajes asignados',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[PushNotificationService] ⚠️ Plugin de notificaciones locales no disponible: $e',
        );
        debugPrint(
          '[PushNotificationService] 💡 Ejecuta: flutter clean && flutter pub get && flutter run',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] Error inicializando notificaciones locales: $e');
      }
      rethrow;
    }
  }

  /// Configurar handlers de FCM
  void _setupFCMHandlers() {
    // Handler para cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handler para cuando el usuario toca la notificación y la app está en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

    // Handler para cuando el usuario toca la notificación y la app estaba cerrada
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleBackgroundMessageTap(message);
      }
    });
  }

  /// Manejar mensaje cuando la app está en primer plano
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint(
        '[PushNotificationService] 📨 Mensaje recibido en primer plano: ${message.messageId}',
      );
    }

    // Mostrar notificación local
    await _showLocalNotification(message);
  }

  /// Manejar cuando el usuario toca una notificación
  void _handleBackgroundMessageTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[PushNotificationService] 👆 Usuario tocó notificación: ${message.messageId}');
    }

    // Aquí puedes navegar a la pantalla correspondiente
    // Por ejemplo, si es un viaje asignado, navegar a DriverRequestsScreen
    final data = message.data;
    if (data['type'] == 'ride_assignment' || data['type'] == 'ride_request') {
      // Navegar a solicitudes
      // Nota: Necesitarás un GlobalKey<NavigatorState> o similar para navegar desde aquí
    }
  }

  /// Callback cuando se toca una notificación local
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('[PushNotificationService] 👆 Notificación local tocada: ${response.id}');
    }

    final payload = response.payload;
    if (payload != null) {
      // Procesar payload y navegar
    }
  }

  /// Mostrar notificación local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'ride_notifications',
      'Notificaciones de Viajes',
      channelDescription: 'Notificaciones sobre nuevos viajes asignados',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Nuevo viaje',
      notification.body ?? 'Tienes un nuevo viaje asignado',
      details,
      payload: message.data.toString(),
    );
  }

  /// Mostrar notificación local manualmente (para uso desde otras pantallas)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Verificar que el servicio esté inicializado
      if (!_initialized) {
        if (kDebugMode) {
          debugPrint('[PushNotificationService] ⚠️ Servicio no inicializado, inicializando...');
        }
        await initialize();
      }

      if (kDebugMode) {
        debugPrint('[PushNotificationService] 📱 Mostrando notificación local:');
        debugPrint('[PushNotificationService]   - Título: $title');
        debugPrint('[PushNotificationService]   - Cuerpo: $body');
      }

      // Verificar permisos antes de mostrar
      final bool? granted = await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();

      if (granted == false) {
        if (kDebugMode) {
          debugPrint('[PushNotificationService] ⚠️ Notificaciones no habilitadas en Android');
        }
      }

      // Asegurarse de que el canal esté creado
      const androidChannel = AndroidNotificationChannel(
        'ride_notifications',
        'Notificaciones de Viajes',
        description: 'Notificaciones sobre nuevos viajes asignados',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      const androidDetails = AndroidNotificationDetails(
        'ride_notifications',
        'Notificaciones de Viajes',
        channelDescription: 'Notificaciones sobre nuevos viajes asignados',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // Generar un ID único para cada notificación
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: data?.toString(),
      );

      if (kDebugMode) {
        debugPrint(
          '[PushNotificationService] ✅ Notificación local mostrada exitosamente (ID: $notificationId)',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] ❌ Error mostrando notificación local: $e');
        debugPrint('[PushNotificationService] Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Obtener token FCM
  Future<String?> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        debugPrint('[PushNotificationService] 🔑 Token FCM: $_fcmToken');
      }
      return _fcmToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] Error obteniendo token: $e');
      }
      return null;
    }
  }

  /// Guardar token FCM en Supabase para un driver
  Future<void> saveTokenForDriver(String driverId) async {
    try {
      if (_fcmToken == null) {
        await _getFCMToken();
      }

      if (_fcmToken == null) {
        if (kDebugMode) {
          debugPrint('[PushNotificationService] ⚠️ No hay token FCM para guardar');
        }
        return;
      }

      final supabaseService = SupabaseService();
      final supabaseClient = supabaseService.client;

      // Actualizar el driver con el token FCM
      // Nota: Necesitas agregar la columna notification_token a la tabla drivers
      await supabaseClient
          .from('drivers')
          .update({'notification_token': _fcmToken, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', driverId);

      if (kDebugMode) {
        debugPrint('[PushNotificationService] ✅ Token FCM guardado para driver $driverId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] Error guardando token: $e');
      }
    }
  }

  /// Obtener el token FCM actual
  String? get fcmToken => _fcmToken;

  /// Limpiar recursos
  void dispose() {
    _tokenSubscription?.cancel();
  }
}

/// Handler para mensajes en segundo plano (debe ser top-level)
/// IMPORTANTE: Este handler se ejecuta en un isolate separado cuando la app está en segundo plano
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase en el isolate de segundo plano con las opciones correctas
  // Verificar si Firebase ya está inicializado (puede estar inicializado en algunos casos)
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: await DefaultFirebaseOptions.currentPlatform);
  }

  if (kDebugMode) {
    debugPrint('[PushNotificationService] 📨 Mensaje en segundo plano: ${message.messageId}');
    debugPrint('[PushNotificationService] 📨 Título: ${message.notification?.title}');
    debugPrint('[PushNotificationService] 📨 Cuerpo: ${message.notification?.body}');
    debugPrint('[PushNotificationService] 📨 Data: ${message.data}');
  }

  // Inicializar notificaciones locales en el isolate de segundo plano
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

  await localNotifications.initialize(initSettings);

  // Crear canal de notificaciones para Android
  const androidChannel = AndroidNotificationChannel(
    'ride_notifications',
    'Notificaciones de Viajes',
    description: 'Notificaciones sobre nuevos viajes asignados',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  await localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  // Mostrar notificación local
  final notification = message.notification;
  if (notification != null) {
    const androidDetails = AndroidNotificationDetails(
      'ride_notifications',
      'Notificaciones de Viajes',
      channelDescription: 'Notificaciones sobre nuevos viajes asignados',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await localNotifications.show(
      message.hashCode,
      notification.title ?? 'Nueva notificación',
      notification.body ?? 'Tienes una nueva notificación',
      details,
      payload: message.data.toString(),
    );

    if (kDebugMode) {
      debugPrint('[PushNotificationService] ✅ Notificación mostrada en segundo plano');
    }
  } else if (message.data.isNotEmpty) {
    // Si no hay notification pero hay data, mostrar notificación con los datos
    const androidDetails = AndroidNotificationDetails(
      'ride_notifications',
      'Notificaciones de Viajes',
      channelDescription: 'Notificaciones sobre nuevos viajes asignados',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final title = message.data['title'] ?? 'Nueva notificación';
    final body = message.data['body'] ?? message.data['message'] ?? 'Tienes una nueva notificación';

    await localNotifications.show(
      message.hashCode,
      title.toString(),
      body.toString(),
      details,
      payload: message.data.toString(),
    );

    if (kDebugMode) {
      debugPrint('[PushNotificationService] ✅ Notificación mostrada en segundo plano (desde data)');
    }
  }
}
