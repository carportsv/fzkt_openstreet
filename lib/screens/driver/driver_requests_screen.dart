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
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;

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
              _loadRequests();
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

  Future<void> _loadRequests() async {
    if (_driverId == null) return;

    setState(() => _isLoading = true);

    try {
      final supabaseClient = _supabaseService.client;

      // Cargar solicitudes disponibles (status='requested' y driver_id=null)
      final requests = await supabaseClient
          .from('ride_requests')
          .select('''
            *,
            user:users!ride_requests_user_id_fkey(id, email, display_name, phone_number)
          ''')
          .eq('status', 'requested')
          .isFilter('driver_id', null)
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _requests = (requests as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverRequests] Error cargando solicitudes: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtimeSubscription() {
    try {
      final supabaseClient = _supabaseService.client;

      _realtimeChannel = supabaseClient
          .channel('driver-requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ride_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'status',
              value: 'requested',
            ),
            callback: (payload) {
              if (kDebugMode) {
                debugPrint('[DriverRequests] 🔔 Cambio detectado: ${payload.eventType}');
              }
              _loadRequests();
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadRequests();
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

      // Verificar que el viaje aún esté disponible
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

      if (checkResponse['driver_id'] != null) {
        throw Exception('El viaje ya fue aceptado por otro conductor');
      }

      // Aceptar el viaje
      await supabaseClient
          .from('ride_requests')
          .update({
            'driver_id': _driverId,
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

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
        _loadRequests();
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
            onPressed: _loadRequests,
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
              onRefresh: _loadRequests,
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
        onPressed: _loadRequests,
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
                  onPressed: _accepting ? null : _closeModal,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _accepting ? null : _acceptRequest,
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
