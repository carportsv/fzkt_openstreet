import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';
import '../../auth/login_screen.dart';
import '../../auth/supabase_service.dart';
import 'package:flutter/foundation.dart';
import '../welcome/welcome/welcome_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'driver_requests_screen.dart';
import 'driver_availability_screen.dart';
import 'driver_ride_screen.dart';
import 'driver_history_screen.dart';
import 'driver_settings_screen.dart';
import '../../services/push_notification_service.dart';
import '../../l10n/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/welcome/navbar/language_selector.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String? _driverName;
  String? _driverId;
  int _unreadNotificationsCount = 0;
  String? _activeRideId;
  bool _isLoading = true;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _rideRequestsChannel; // Canal para escuchar cambios en ride_requests
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    _rideRequestsChannel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final supabaseClient = _supabaseService.client;

      // Obtener user_id desde firebase_uid
      final userResponse = await supabaseClient
          .from('users')
          .select('id, display_name, email')
          .eq('firebase_uid', user.uid)
          .maybeSingle();

      if (userResponse != null) {
        final userId = userResponse['id'] as String?;
        final displayName = userResponse['display_name'] as String?;
        final email = userResponse['email'] as String?;

        // Obtener nombre del driver
        _driverName = displayName ?? email?.split('@')[0] ?? 'Conductor';

        if (userId != null) {
          // Obtener driver_id
          final driverResponse = await supabaseClient
              .from('drivers')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

          if (driverResponse != null) {
            final driverId = driverResponse['id'] as String?;

            if (driverId != null) {
              setState(() => _driverId = driverId);

              // Guardar token FCM para el driver
              try {
                await PushNotificationService().saveTokenForDriver(driverId);
                if (kDebugMode) {
                  debugPrint('[DriverHomeScreen] ✅ Token FCM guardado para driver: $driverId');
                }
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('[DriverHomeScreen] ⚠️ Error guardando token FCM: $e');
                }
              }

              // Cargar notificaciones pendientes (viajes pendientes)
              await _loadNotifications(driverId);
              // Cargar viaje activo
              await _loadActiveRide(driverId);
              // Configurar suscripción en tiempo real para notificaciones (messages)
              _setupNotificationsSubscription(driverId);
              // Configurar suscripción en tiempo real para viajes (ride_requests)
              _setupRideRequestsSubscription(driverId);
              // Iniciar auto-refresh
              _startAutoRefresh();
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Error cargando datos: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNotifications(String driverId) async {
    try {
      final supabaseClient = _supabaseService.client;
      // Contar viajes pendientes (requested y accepted) asignados a este driver
      // Esto debe coincidir con lo que se muestra en la pantalla de solicitudes
      final pendingRequests = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('driver_id', driverId)
          .or('status.eq.requested,status.eq.accepted'); // Incluir ambos estados

      final count = (pendingRequests as List).length;

      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Viajes pendientes encontrados: $count');
      }

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Error cargando viajes pendientes: $e');
      }
    }
  }

  void _setupNotificationsSubscription(String driverId) async {
    try {
      final supabaseClient = _supabaseService.client;

      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] 🔌 Configurando suscripción para driver: $driverId');
      }

      // Verificar si las notificaciones están habilitadas
      try {
        final driverResponse = await supabaseClient
            .from('drivers')
            .select('notifications_enabled')
            .eq('id', driverId)
            .maybeSingle();

        if (driverResponse != null) {
          final notificationsEnabled = driverResponse['notifications_enabled'] as bool? ?? true;
          if (!notificationsEnabled) {
            if (kDebugMode) {
              debugPrint(
                '[DriverHomeScreen] ⚠️ Notificaciones desactivadas para este driver, no se suscribirá',
              );
            }
            return; // No suscribirse si las notificaciones están desactivadas
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DriverHomeScreen] ⚠️ Error verificando preferencia de notificaciones: $e');
        }
        // Continuar con la suscripción si hay error (fallback a permitir)
      }

      // Verificar que Realtime esté habilitado para la tabla messages
      // Esto es importante porque si Realtime no está habilitado, no recibiremos eventos
      try {
        await supabaseClient.from('messages').select('id').limit(1).maybeSingle();

        if (kDebugMode) {
          debugPrint('[DriverHomeScreen] ✅ Conexión a tabla messages verificada');
          debugPrint(
            '[DriverHomeScreen] ⚠️⚠️⚠️ IMPORTANTE: Realtime debe estar habilitado para recibir notificaciones',
          );
          debugPrint('[DriverHomeScreen] 💡 PASOS PARA HABILITAR REALTIME:');
          debugPrint('[DriverHomeScreen] 💡 1. Ve a Supabase Dashboard > SQL Editor');
          debugPrint(
            '[DriverHomeScreen] 💡 2. Ejecuta el script: database/enable-realtime-messages.sql',
          );
          debugPrint('[DriverHomeScreen] 💡 3. O ejecuta directamente:');
          debugPrint(
            '[DriverHomeScreen] 💡    ALTER PUBLICATION supabase_realtime ADD TABLE messages;',
          );
          debugPrint('[DriverHomeScreen] 💡 4. Verifica con:');
          debugPrint(
            '[DriverHomeScreen] 💡    SELECT * FROM pg_publication_tables WHERE tablename = '
            'messages'
            ';',
          );
          debugPrint(
            '[DriverHomeScreen] 💡 5. Si NO aparece ninguna fila, Realtime NO está habilitado',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DriverHomeScreen] ⚠️ Error verificando tabla messages: $e');
        }
      }

      // Cancelar suscripción anterior si existe
      _notificationsChannel?.unsubscribe();

      if (kDebugMode) {
        debugPrint(
          '[DriverHomeScreen] 🔍 Tipo de driverId: ${driverId.runtimeType}, valor: $driverId',
        );
      }

      // Suscribirse a nuevas notificaciones para este driver
      // Usar un nombre de canal único para evitar conflictos
      final channelName = 'driver-notifications-$driverId-${DateTime.now().millisecondsSinceEpoch}';
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] 📡 Nombre del canal: $channelName');
      }

      // Pequeño delay para asegurar que la conexión WebSocket esté lista
      await Future.delayed(const Duration(milliseconds: 300));

      // Suscripción principal con filtro
      _notificationsChannel = supabaseClient
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'driver_id',
              value: driverId,
            ),
            callback: (payload) {
              if (kDebugMode) {
                debugPrint(
                  '[DriverHomeScreen] 🔔🔔🔔 CALLBACK EJECUTADO - EventType: ${payload.eventType}',
                );
                debugPrint('[DriverHomeScreen] 🔔 Payload completo: $payload');
                debugPrint('[DriverHomeScreen] 🔔 newRecord: ${payload.newRecord}');
                debugPrint('[DriverHomeScreen] 🔔 oldRecord: ${payload.oldRecord}');

                // Verificar que el driver_id coincida
                final newRecord = payload.newRecord;
                final recordDriverId = newRecord['driver_id']?.toString();
                debugPrint('[DriverHomeScreen] 🔍 Comparando driver_id:');
                debugPrint('[DriverHomeScreen]   - Esperado: $driverId (${driverId.runtimeType})');
                debugPrint(
                  '[DriverHomeScreen]   - Recibido: $recordDriverId (${recordDriverId.runtimeType})',
                );
                debugPrint('[DriverHomeScreen]   - Coinciden: ${driverId == recordDriverId}');
              }

              // Recargar notificaciones cuando se inserta una nueva
              if (payload.eventType == PostgresChangeEvent.insert) {
                if (kDebugMode) {
                  debugPrint(
                    '[DriverHomeScreen] ✅ Evento INSERT detectado, recargando notificaciones...',
                  );
                }

                // Obtener datos de la notificación
                final newRecord = payload.newRecord;
                final title = (newRecord['title'] as String?) ?? '🚗 ¡Nuevo viaje asignado!';
                final message =
                    (newRecord['message'] as String?) ??
                    'Tienes un nuevo viaje asignado. Toca para ver detalles.';

                if (kDebugMode) {
                  debugPrint('[DriverHomeScreen] 🔔 Preparando para mostrar notificación:');
                  debugPrint('[DriverHomeScreen]   - Título: $title');
                  debugPrint('[DriverHomeScreen]   - Mensaje: $message');
                }

                // Reproducir sonido y vibración
                _playNotificationSound();

                // Mostrar notificación local del sistema (con sonido) - sin await
                if (kDebugMode) {
                  debugPrint(
                    '[DriverHomeScreen] 📱 Llamando a PushNotificationService.showLocalNotification...',
                  );
                }
                PushNotificationService()
                    .showLocalNotification(
                      title: title,
                      body: message,
                      data: {'type': 'ride_request', 'driver_id': driverId},
                      driverId: driverId,
                    )
                    .then((_) {
                      if (kDebugMode) {
                        debugPrint('[DriverHomeScreen] ✅ Notificación local mostrada exitosamente');
                      }
                    })
                    .catchError((e, stackTrace) {
                      if (kDebugMode) {
                        debugPrint('[DriverHomeScreen] ❌ Error mostrando notificación local: $e');
                        debugPrint('[DriverHomeScreen] Stack trace: $stackTrace');
                      }
                    });

                // Recargar notificaciones y datos
                if (_driverId != null) {
                  _loadNotifications(_driverId!);
                  _loadActiveRide(_driverId!);
                }

                // Mostrar snackbar de notificación mejorado
                if (mounted) {
                  // Usar un pequeño delay para asegurar que el estado se actualice
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_active,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.exo(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      style: GoogleFonts.exo(fontSize: 13, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.teal[700],
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          duration: const Duration(seconds: 6),
                          action: SnackBarAction(
                            label: 'Ver',
                            textColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            onPressed: () {
                              // Navegar a solicitudes
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DriverRequestsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }
                  });
                }
              }
            },
          )
          .subscribe((status, [error]) {
            if (kDebugMode) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                debugPrint(
                  '[DriverHomeScreen] ✅ Suscripción ACTIVA - Escuchando cambios en messages para driver_id=$driverId',
                );
              } else if (status == RealtimeSubscribeStatus.channelError) {
                // Error de conexión inicial es normal, Supabase se reconecta automáticamente
                if (error != null) {
                  final closeEvent = error as RealtimeCloseEvent?;
                  if (closeEvent?.code == 1006) {
                    // Código 1006 = conexión cerrada anormalmente (normal durante inicialización)
                    debugPrint('[DriverHomeScreen] ⚠️ Reintentando conexión... (error temporal)');
                  } else {
                    debugPrint('[DriverHomeScreen] ⚠️ Error en suscripción: $error');
                  }
                }
              } else {
                debugPrint('[DriverHomeScreen] 📡 Estado de suscripción: $status');
              }
            }
          });

      if (kDebugMode) {
        debugPrint(
          '[DriverHomeScreen] ✅ Suscripción a notificaciones configurada para driver: $driverId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] ❌ Error configurando suscripción a notificaciones: $e');
        debugPrint('[DriverHomeScreen] Stack trace: ${StackTrace.current}');
      }
    }
  }

  /// Configurar suscripción en tiempo real para cambios en ride_requests
  void _setupRideRequestsSubscription(String driverId) async {
    try {
      final supabaseClient = _supabaseService.client;

      if (kDebugMode) {
        debugPrint(
          '[DriverHomeScreen] 🔌 Configurando suscripción a ride_requests para driver: $driverId',
        );
      }

      // Cancelar suscripción anterior si existe
      _rideRequestsChannel?.unsubscribe();

      // Suscribirse a cambios en ride_requests para este driver
      final channelName = 'driver-ride-requests-$driverId-${DateTime.now().millisecondsSinceEpoch}';

      _rideRequestsChannel = supabaseClient
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all, // Escuchar INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'ride_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'driver_id',
              value: driverId,
            ),
            callback: (payload) {
              if (kDebugMode) {
                debugPrint('[DriverHomeScreen] 🔔 Cambio en ride_requests: ${payload.eventType}');
              }
              // Actualizar contador cuando cambien los viajes
              if (_driverId != null) {
                _loadNotifications(_driverId!);
                _loadActiveRide(_driverId!);
              }
            },
          )
          .subscribe();

      if (kDebugMode) {
        debugPrint(
          '[DriverHomeScreen] ✅ Suscripción a ride_requests configurada para driver: $driverId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] ❌ Error configurando suscripción a ride_requests: $e');
      }
    }
  }

  Future<void> _playNotificationSound() async {
    // Vibración
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Error en vibración: $e');
      }
    }

    // Reproducir sonido de notificación
    try {
      final player = FlutterRingtonePlayer();
      await player.playNotification();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Error reproduciendo sonido: $e');
      }
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Reducir frecuencia de refresh a 30 segundos para evitar problemas de rendimiento
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_driverId != null && mounted) {
        _refreshHomeData();
      }
    });
  }

  Future<void> _refreshHomeData() async {
    if (_driverId == null) return;

    try {
      await Future.wait([_loadNotifications(_driverId!), _loadActiveRide(_driverId!)]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Error refrescando datos: $e');
      }
    }
  }

  Future<void> _loadActiveRide(String driverId) async {
    try {
      final supabaseClient = _supabaseService.client;
      // Buscar viajes activos (accepted o in_progress)
      final acceptedRides = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'accepted')
          .limit(1);

      final inProgressRides = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'in_progress')
          .limit(1);

      final activeRides = [...acceptedRides, ...inProgressRides];

      if (mounted) {
        setState(() {
          _activeRideId = (activeRides as List).isNotEmpty
              ? (activeRides[0] as Map)['id']?.toString()
              : null;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Error cargando viaje activo: $e');
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Iniciando cierre de sesión...');
      }

      // 1. Cerrar sesión de Firebase primero
      await FirebaseAuth.instance.signOut();
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] ✅ Sesión de Firebase cerrada');
      }

      // 2. Esperar un momento para que Firebase procese el logout
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Cerrar sesión de Google Sign-In también
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        await googleSignIn.signOut();
        if (kDebugMode) {
          debugPrint('[DriverHomeScreen] ✅ Sesión de Google Sign-In cerrada');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DriverHomeScreen] ⚠️ Error al cerrar sesión de Google: ${e.toString()}');
        }
      }

      // 4. Esperar un momento adicional
      await Future.delayed(const Duration(milliseconds: 300));

      // 5. Navegar a la pantalla apropiada después de logout
      if (mounted) {
        if (kIsWeb) {
          // En web, redirigir a WelcomeScreen después de logout
          if (kDebugMode) {
            debugPrint('[DriverHomeScreen] 🚀 Navegando a WelcomeScreen (web)...');
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        } else {
          // En móvil, redirigir a LoginScreen
          if (kDebugMode) {
            debugPrint('[DriverHomeScreen] 🚀 Navegando a LoginScreen (móvil)...');
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToScreen(String route) {
    switch (route) {
      case 'driver_requests':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DriverRequestsScreen()),
        );
        break;
      case 'driver_availability':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DriverAvailabilityScreen()),
        );
        break;
      case 'driver_ride':
        if (_activeRideId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DriverRideScreen(rideId: _activeRideId!)),
          );
        }
        break;
      case 'driver_history':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DriverHistoryScreen()),
        );
        break;
      case 'driver_settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DriverSettingsScreen()),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pantalla $route en desarrollo'), backgroundColor: Colors.orange),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final localeProvider = Provider.of<LocaleProvider>(context, listen: true);
      final selectedLanguage = localeProvider.locale.languageCode;

      return Stack(
        children: <Widget>[
          CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              backgroundColor: CupertinoColors.systemBackground,
              trailing: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LanguageSelectorWidget(
                  selectedLanguage: selectedLanguage,
                  onLanguageChanged: (language) {
                    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
                    localeProvider.setLocaleFromCode(language);
                  },
                ),
              ),
            ),
            child: const Center(child: CupertinoActivityIndicator(radius: 16)),
          ),
        ],
      );
    }

    // Obtener idioma seleccionado del LocaleProvider
    final localeProvider = Provider.of<LocaleProvider>(context, listen: true);
    final selectedLanguage = localeProvider.locale.languageCode;

    return Stack(
      children: <Widget>[
        CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            backgroundColor: CupertinoColors.systemBackground,
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: LanguageSelectorWidget(
                selectedLanguage: selectedLanguage,
                onLanguageChanged: (language) {
                  final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
                  localeProvider.setLocaleFromCode(language);
                  if (kDebugMode) {
                    debugPrint('[DriverHomeScreen] Idioma cambiado a: $language');
                  }
                },
              ),
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () async {
                    if (_driverId != null) {
                      await _refreshHomeData();
                    }
                  },
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Sección de bienvenida
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            final greeting =
                                (l10n?.translate('driver.welcomeGreeting') ?? '¡Hola, {name}!')
                                    .replaceAll('{name}', _driverName ?? 'Conductor');
                            final description =
                                l10n?.translate('driver.welcomeDescription') ??
                                'Bienvenido a tu panel de control. Aquí puedes gestionar tus viajes y configuraciones.';
                            return Column(
                              children: [
                                Text(
                                  greeting,
                                  style: GoogleFonts.exo(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: CupertinoColors.label,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  description,
                                  style: GoogleFonts.exo(
                                    fontSize: 15,
                                    color: CupertinoColors.secondaryLabel,
                                    height: 1.4,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Lista de opciones con estilo Cupertino
                      Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              children: [
                                // Solicitudes
                                _buildCupertinoListTile(
                                  icon: CupertinoIcons.doc_text,
                                  title: l10n?.translate('driver.requests') ?? 'Solicitudes',
                                  subtitle: _unreadNotificationsCount > 0
                                      ? (l10n?.translate('driver.newRequests') ?? '{count} nuevas')
                                            .replaceAll(
                                              '{count}',
                                              _unreadNotificationsCount.toString(),
                                            )
                                      : l10n?.translate('driver.viewPendingRequests') ??
                                            'Ver solicitudes pendientes',
                                  onTap: () => _navigateToScreen('driver_requests'),
                                  badge: _unreadNotificationsCount > 0
                                      ? _unreadNotificationsCount
                                      : null,
                                  isFirst: true,
                                ),
                                const Divider(height: 1, indent: 60),

                                // Disponibilidad
                                _buildCupertinoListTile(
                                  icon: CupertinoIcons.location,
                                  title: l10n?.translate('driver.availability') ?? 'Disponibilidad',
                                  subtitle:
                                      l10n?.translate('driver.toggleAvailability') ??
                                      'Activar o desactivar',
                                  onTap: () => _navigateToScreen('driver_availability'),
                                ),
                                const Divider(height: 1, indent: 60),

                                // Viaje Activo (solo si hay uno)
                                if (_activeRideId != null) ...[
                                  _buildCupertinoListTile(
                                    icon: CupertinoIcons.car,
                                    title: l10n?.translate('driver.activeRide') ?? 'Viaje Activo',
                                    subtitle:
                                        l10n?.translate('driver.manageActiveRide') ??
                                        'Gestionar viaje en curso',
                                    onTap: () => _navigateToScreen('driver_ride'),
                                    color: CupertinoColors.systemGreen,
                                  ),
                                  const Divider(height: 1, indent: 60),
                                ],

                                // Historial
                                _buildCupertinoListTile(
                                  icon: CupertinoIcons.clock,
                                  title:
                                      l10n?.translate('driver.rideHistory') ??
                                      'Historial de Viajes',
                                  subtitle:
                                      l10n?.translate('driver.viewCompletedRides') ??
                                      'Ver viajes completados',
                                  onTap: () => _navigateToScreen('driver_history'),
                                ),
                                const Divider(height: 1, indent: 60),

                                // Configuración
                                _buildCupertinoListTile(
                                  icon: CupertinoIcons.settings,
                                  title: l10n?.translate('driver.settings') ?? 'Configuración',
                                  subtitle:
                                      l10n?.translate('driver.adjustPreferences') ??
                                      'Ajustar preferencias',
                                  onTap: () => _navigateToScreen('driver_settings'),
                                  isLast: true,
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Botón de Cerrar Sesión
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _handleLogout,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CupertinoColors.destructiveRed.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.power,
                                    color: CupertinoColors.destructiveRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n?.translate('driver.logout') ??
                                        l10n?.logout ??
                                        'Cerrar Sesión',
                                    style: GoogleFonts.exo(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.destructiveRed,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      // Logo centrado debajo del botón de cerrar sesión
                      Center(
                        child: Image.asset(
                          'assets/images/logo_21.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.scaleDown,
                          errorBuilder: (context, error, stackTrace) {
                            if (kDebugMode) {
                              debugPrint('[DriverHomeScreen] ❌ Error cargando logo: $error');
                              debugPrint('[DriverHomeScreen] StackTrace: $stackTrace');
                            }
                            return Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    CupertinoIcons.car,
                                    size: 100,
                                    color: CupertinoColors.activeBlue,
                                  ),
                                  if (kDebugMode)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Logo no encontrado',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCupertinoListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badge,
    Color? color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final iconColor = color ?? CupertinoColors.activeBlue;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isFirst ? 12 : 0),
            topRight: Radius.circular(isFirst ? 12 : 0),
            bottomLeft: Radius.circular(isLast ? 12 : 0),
            bottomRight: Radius.circular(isLast ? 12 : 0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.exo(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.exo(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge != null && badge > 0) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.destructiveRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge.toString(),
                  style: GoogleFonts.exo(
                    color: CupertinoColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            Icon(CupertinoIcons.chevron_right, color: CupertinoColors.tertiaryLabel, size: 18),
          ],
        ),
      ),
    );
  }
}
