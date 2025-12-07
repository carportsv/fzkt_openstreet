import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../auth/login_screen.dart';
import '../../auth/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'driver_requests_screen.dart';
import 'driver_availability_screen.dart';
import 'driver_ride_screen.dart';
import 'driver_history_screen.dart';
import 'driver_settings_screen.dart';
import '../../services/push_notification_service.dart';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
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

              // Cargar notificaciones pendientes
              await _loadNotifications(driverId);
              // Cargar viaje activo
              await _loadActiveRide(driverId);
              // Configurar suscripción en tiempo real
              _setupNotificationsSubscription(driverId);
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
      final notifications = await supabaseClient
          .from('messages')
          .select('id, type, title, message')
          .eq('driver_id', driverId)
          .eq('is_read', false)
          .eq('type', 'ride_request'); // Cambiar a 'ride_request' que es el tipo permitido

      if (kDebugMode) {
        debugPrint(
          '[DriverHomeScreen] Notificaciones encontradas: ${(notifications as List).length}',
        );
      }

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = (notifications as List).length;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] Error cargando notificaciones: $e');
      }
    }
  }

  void _setupNotificationsSubscription(String driverId) async {
    try {
      final supabaseClient = _supabaseService.client;

      if (kDebugMode) {
        debugPrint('[DriverHomeScreen] 🔌 Configurando suscripción para driver: $driverId');
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

      // 5. Navegar a la pantalla de login
      if (mounted) {
        if (kDebugMode) {
          debugPrint('[DriverHomeScreen] 🚀 Navegando a LoginScreen...');
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
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
      return Scaffold(
        appBar: AppBar(
          title: Text('Inicio del Conductor', style: GoogleFonts.exo()),
          backgroundColor: Colors.teal[700],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Inicio del Conductor', style: GoogleFonts.exo()),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              if (_driverId != null) {
                _refreshHomeData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_driverId != null) {
            await _refreshHomeData();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección de bienvenida
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '¡Hola, ${_driverName ?? 'Conductor'}!',
                      style: GoogleFonts.exo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bienvenido a tu panel de control. Aquí puedes gestionar tus viajes y configuraciones.',
                      style: GoogleFonts.exo(fontSize: 16, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Menú de acciones rápidas
              Text(
                'Acciones Rápidas',
                style: GoogleFonts.exo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),

              // Card de Solicitudes
              _buildMenuCard(
                icon: Icons.assignment,
                title: 'Solicitudes',
                subtitle: _unreadNotificationsCount > 0
                    ? 'Ver solicitudes de viajes pendientes ($_unreadNotificationsCount nuevas)'
                    : 'Ver solicitudes de viajes pendientes',
                onTap: () => _navigateToScreen('driver_requests'),
                badge: _unreadNotificationsCount > 0 ? _unreadNotificationsCount : null,
              ),

              const SizedBox(height: 12),

              // Card de Disponibilidad
              _buildMenuCard(
                icon: Icons.toggle_on,
                title: 'Disponibilidad',
                subtitle: 'Activar o desactivar disponibilidad',
                onTap: () => _navigateToScreen('driver_availability'),
              ),

              // Card de Viaje Activo (solo si hay uno)
              if (_activeRideId != null) ...[
                const SizedBox(height: 12),
                _buildMenuCard(
                  icon: Icons.directions_car,
                  title: 'Viaje Activo',
                  subtitle: 'Gestionar viaje en curso',
                  onTap: () => _navigateToScreen('driver_ride'),
                  color: Colors.green,
                ),
              ],

              const SizedBox(height: 12),

              // Card de Historial
              _buildMenuCard(
                icon: Icons.history,
                title: 'Historial de Viajes',
                subtitle: 'Ver viajes completados',
                onTap: () => _navigateToScreen('driver_history'),
              ),

              const SizedBox(height: 12),

              // Card de Configuración
              _buildMenuCard(
                icon: Icons.settings,
                title: 'Configuración',
                subtitle: 'Ajustar preferencias de la app',
                onTap: () => _navigateToScreen('driver_settings'),
              ),

              const SizedBox(height: 12),

              // Card de Cerrar Sesión
              _buildMenuCard(
                icon: Icons.logout,
                title: 'Cerrar Sesión',
                subtitle: 'Salir de la aplicación',
                onTap: _handleLogout,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badge,
    Color? color,
  }) {
    final cardColor = color ?? Colors.blue[700]!;
    final isLogout = title == 'Cerrar Sesión';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: isLogout ? Colors.red : cardColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.exo(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isLogout ? Colors.red : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.exo(
                        fontSize: 14,
                        color: isLogout ? Colors.red[300] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null && badge > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge.toString(),
                    style: GoogleFonts.exo(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
