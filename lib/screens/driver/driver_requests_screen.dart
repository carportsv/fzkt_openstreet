import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String? _driverId;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedRequest;
  bool _showModal = false;
  bool _accepting = false;
  bool _rejecting = false;
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;
  DateTime? _lastRefreshTime;
  static const Duration _minRefreshInterval = Duration(
    seconds: 5,
  ); // Mínimo 5 segundos entre actualizaciones

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDriverId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final supabaseClient = _supabaseService.client;

      // Obtener user_id desde firebase_uid
      final userResponse = await supabaseClient
          .from('users')
          .select('id')
          .eq('firebase_uid', user.uid)
          .maybeSingle();

      if (userResponse != null) {
        final userId = userResponse['id'] as String?;

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
              _loadRequests(force: true); // Carga inicial, forzar
              _setupRealtimeSubscription();
              _startAutoRefresh();
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverRequests] Error cargando driver_id: $e');
      }
    }
  }

  Future<void> _loadRequests({bool force = false}) async {
    if (_driverId == null) {
      if (kDebugMode) {
        debugPrint('[DriverRequests] ⚠️ _driverId es null, no se pueden cargar solicitudes');
      }
      return;
    }

    // Control de frecuencia: evitar actualizaciones muy frecuentes (excepto si es forzada)
    if (!force && _lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _minRefreshInterval) {
        if (kDebugMode) {
          debugPrint(
            '[DriverRequests] ⏰ Actualización omitida (muy reciente: ${timeSinceLastRefresh.inSeconds}s)',
          );
        }
        return;
      }
    }

    _lastRefreshTime = DateTime.now();
    setState(() => _isLoading = true);

    try {
      final supabaseClient = _supabaseService.client;

      if (kDebugMode) {
        debugPrint('[DriverRequests] 🔍 Cargando solicitudes para driver: $_driverId');
        debugPrint('[DriverRequests] 🔍 Tipo de _driverId: ${_driverId.runtimeType}');
      }

      // DEBUG: Verificar cuántos viajes hay en total para este driver
      try {
        final totalCount = await supabaseClient
            .from('ride_requests')
            .select('id')
            .eq('driver_id', _driverId!);

        if (kDebugMode) {
          debugPrint(
            '[DriverRequests] 📊 Total de viajes con driver_id=$_driverId: ${(totalCount as List).length}',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DriverRequests] ⚠️ Error contando viajes: $e');
        }
      }

      // DEBUG: Verificar viajes por status
      try {
        final byStatus = await supabaseClient
            .from('ride_requests')
            .select('status')
            .eq('driver_id', _driverId!);

        if (kDebugMode) {
          final statusMap = <String, int>{};
          for (var ride in (byStatus as List)) {
            final status = (ride as Map<String, dynamic>)['status']?.toString() ?? 'null';
            statusMap[status] = (statusMap[status] ?? 0) + 1;
          }
          debugPrint('[DriverRequests] 📊 Viajes por status: $statusMap');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DriverRequests] ⚠️ Error verificando status: $e');
        }
      }

      // Cargar viajes asignados a este driver
      // Incluir 'requested' (asignados pero no aceptados) y 'accepted' (aceptados pero no completados)
      // Usar .or() para filtrar múltiples estados
      final requests = await supabaseClient
          .from('ride_requests')
          .select('''
            *,
            user:users!ride_requests_user_id_fkey(id, email, display_name, phone_number)
          ''')
          .eq('driver_id', _driverId!) // Viajes asignados a este driver
          .or('status.eq.requested,status.eq.accepted') // Incluir ambos estados
          .order('created_at', ascending: false)
          .limit(50); // Aumentar límite para ver más viajes

      if (kDebugMode) {
        debugPrint('[DriverRequests] ✅ Solicitudes encontradas: ${(requests as List).length}');
        if ((requests as List).isEmpty) {
          debugPrint('[DriverRequests] ⚠️ No se encontraron viajes.');
          debugPrint('[DriverRequests] 💡 Posibles causas:');
          debugPrint('[DriverRequests]   1. Los viajes no tienen driver_id asignado');
          debugPrint(
            '[DriverRequests]   2. Los viajes tienen un status diferente a "requested" o "accepted"',
          );
          debugPrint('[DriverRequests]   3. El driver_id en la BD no coincide con $_driverId');
        } else {
          // Mostrar detalles de los primeros 3 viajes
          for (var i = 0; i < (requests as List).length && i < 3; i++) {
            final ride = (requests as List)[i] as Map<String, dynamic>;
            debugPrint(
              '[DriverRequests] 📋 Viaje ${i + 1}: id=${ride['id']}, status=${ride['status']}, driver_id=${ride['driver_id']}',
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _requests = (requests as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[DriverRequests] ❌ Error cargando solicitudes: $e');
        debugPrint('[DriverRequests] Stack trace: $stackTrace');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtimeSubscription() {
    if (_driverId == null) return;

    try {
      final supabaseClient = _supabaseService.client;

      if (kDebugMode) {
        debugPrint('[DriverRequests] 🔌 Configurando suscripción para driver: $_driverId');
      }

      _realtimeChannel = supabaseClient
          .channel('driver-requests-$_driverId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ride_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'driver_id',
              value: _driverId!,
            ),
            callback: (payload) {
              if (kDebugMode) {
                debugPrint('[DriverRequests] 🔔 Cambio detectado: ${payload.eventType}');
              }
              // Usar force=true para que Realtime siempre actualice, pero con el control de frecuencia
              _loadRequests(force: true);
            },
          )
          .subscribe();

      if (kDebugMode) {
        debugPrint('[DriverRequests] ✅ Suscripción en tiempo real configurada');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverRequests] ❌ Error configurando suscripción: $e');
      }
    }
  }

  void _startAutoRefresh() {
    // Actualización automática cada 2 minutos (120 segundos)
    // Ya casi no es necesaria si las notificaciones Realtime funcionan correctamente
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _loadRequests(force: true); // Forzar actualización periódica
      }
    });
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    setState(() {
      _selectedRequest = request;
      _showModal = true;
    });
  }

  void _closeModal() {
    setState(() {
      _showModal = false;
      _selectedRequest = null;
    });
  }

  Future<void> _acceptRequest() async {
    if (_selectedRequest == null || _driverId == null) return;

    setState(() => _accepting = true);

    try {
      final supabaseClient = _supabaseService.client;
      final rideId = _selectedRequest!['id']?.toString() ?? '';

      // Verificar que el viaje esté asignado a este driver
      final checkResponse = await supabaseClient
          .from('ride_requests')
          .select('status, driver_id')
          .eq('id', rideId)
          .maybeSingle();

      if (checkResponse == null) {
        throw Exception('El viaje no existe');
      }

      if (checkResponse['status'] != 'requested') {
        throw Exception('El viaje ya no está disponible');
      }

      final checkDriverId = checkResponse['driver_id']?.toString();
      if (checkDriverId != _driverId) {
        throw Exception('Este viaje no está asignado a ti');
      }

      // Aceptar el viaje (ya tiene driver_id, solo cambiamos status)
      await supabaseClient
          .from('ride_requests')
          .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', rideId)
          .eq('driver_id', _driverId!); // Asegurar que solo este driver puede aceptar

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viaje aceptado exitosamente', style: GoogleFonts.exo()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _closeModal();
        _loadRequests(force: true); // Después de aceptar, forzar actualización
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar viaje: ${e.toString()}', style: GoogleFonts.exo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _accepting = false);
      }
    }
  }

  Future<void> _rejectRequest() async {
    if (_selectedRequest == null || _driverId == null) return;

    // Confirmar rechazo
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Rechazar viaje?', style: GoogleFonts.exo()),
        content: Text(
          '¿Estás seguro de que deseas rechazar este viaje? El viaje volverá a estar disponible para otros conductores.',
          style: GoogleFonts.exo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: GoogleFonts.exo()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Rechazar', style: GoogleFonts.exo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _rejecting = true);

    try {
      final supabaseClient = _supabaseService.client;
      final rideId = _selectedRequest!['id']?.toString() ?? '';

      // Verificar que el viaje esté asignado a este driver
      final checkResponse = await supabaseClient
          .from('ride_requests')
          .select('status, driver_id')
          .eq('id', rideId)
          .maybeSingle();

      if (checkResponse == null) {
        throw Exception('El viaje no existe');
      }

      final checkDriverId = checkResponse['driver_id']?.toString();
      if (checkDriverId != _driverId) {
        throw Exception('Este viaje no está asignado a ti');
      }

      // Rechazar: quitar driver_id y mantener status='requested' para que vuelva a estar disponible
      await supabaseClient
          .from('ride_requests')
          .update({
            'driver_id': null,
            'status': 'requested',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', _driverId!); // Asegurar que solo este driver puede rechazar

      // Eliminar la notificación relacionada
      try {
        await supabaseClient
            .from('messages')
            .update({'is_read': true})
            .eq('driver_id', _driverId!)
            .eq('type', 'ride_request')
            .contains('data', {'ride_id': rideId});
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DriverRequests] Error marcando notificación como leída: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viaje rechazado', style: GoogleFonts.exo()),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _closeModal();
        _loadRequests(force: true); // Después de aceptar, forzar actualización
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al rechazar viaje: ${e.toString()}', style: GoogleFonts.exo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _rejecting = false);
      }
    }
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return 'N/A';
    if (distance is num) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return distance.toString();
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return 'N/A';
    if (duration is num) {
      return '${(duration / 60).round()} min';
    }
    return duration.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitudes de Viajes', style: GoogleFonts.exo()),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadRequests(force: true),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay solicitudes disponibles',
                    style: GoogleFonts.exo(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las nuevas solicitudes aparecerán aquí',
                    style: GoogleFonts.exo(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadRequests(force: true),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  final origin = request['origin'] as Map?;
                  final destination = request['destination'] as Map?;
                  final user = request['user'] as Map?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () => _showRequestDetails(request),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        origin?['address']?.toString() ?? 'Origen no especificado',
                                        style: GoogleFonts.exo(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_downward,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              destination?['address']?.toString() ??
                                                  'Destino no especificado',
                                              style: GoogleFonts.exo(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  user?['display_name']?.toString() ??
                                      user?['email']?.toString() ??
                                      'Usuario',
                                  style: GoogleFonts.exo(fontSize: 14, color: Colors.grey[700]),
                                ),
                                const Spacer(),
                                if (request['distance'] != null)
                                  Row(
                                    children: [
                                      Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDistance(request['distance']),
                                        style: GoogleFonts.exo(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (request['price'] != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.attach_money, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '\$${request['price'].toStringAsFixed(2)}',
                                    style: GoogleFonts.exo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _loadRequests(force: true),
        backgroundColor: Colors.teal[700],
        child: const Icon(Icons.refresh),
      ),
      // Modal de detalles
      bottomSheet: _showModal && _selectedRequest != null ? _buildDetailsModal() : null,
    );
  }

  Widget _buildDetailsModal() {
    final request = _selectedRequest!;
    final origin = request['origin'] as Map?;
    final destination = request['destination'] as Map?;
    final user = request['user'] as Map?;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Detalles del Viaje',
                style: GoogleFonts.exo(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: _closeModal),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.location_on,
            'Origen',
            origin?['address']?.toString() ?? 'No especificado',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.location_on,
            'Destino',
            destination?['address']?.toString() ?? 'No especificado',
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.person,
            'Pasajero',
            user?['display_name']?.toString() ?? user?['email']?.toString() ?? 'Usuario',
            Colors.grey,
          ),
          if (user?['phone_number'] != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.phone,
              'Teléfono',
              user?['phone_number']?.toString() ?? '',
              Colors.grey,
            ),
          ],
          if (request['distance'] != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.straighten,
              'Distancia',
              _formatDistance(request['distance']),
              Colors.grey,
            ),
          ],
          if (request['duration'] != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.access_time,
              'Duración estimada',
              _formatDuration(request['duration']),
              Colors.grey,
            ),
          ],
          if (request['price'] != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.attach_money,
              'Precio',
              '\$${request['price'].toStringAsFixed(2)}',
              Colors.green,
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_accepting || _rejecting) ? null : _closeModal,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cerrar',
                    style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: (_accepting || _rejecting) ? null : _rejectRequest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _rejecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        )
                      : Text(
                          'Rechazar',
                          style: GoogleFonts.exo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_accepting || _rejecting) ? null : _acceptRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _accepting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Aceptar Viaje',
                          style: GoogleFonts.exo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.exo(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
