import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String? _driverId;
  List<Map<String, dynamic>> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final supabaseClient = _supabaseService.client;

      final userResponse = await supabaseClient
          .from('users')
          .select('id')
          .eq('firebase_uid', user.uid)
          .maybeSingle();

      if (userResponse != null) {
        final userId = userResponse['id'] as String?;

        if (userId != null) {
          final driverResponse = await supabaseClient
              .from('drivers')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

          if (driverResponse != null) {
            final driverId = driverResponse['id'] as String?;
            if (driverId != null) {
              setState(() => _driverId = driverId);
              _loadHistory();
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHistory] Error cargando driver_id: $e');
      }
    }
  }

  Future<void> _loadHistory() async {
    if (_driverId == null) return;

    setState(() => _isLoading = true);

    try {
      final supabaseClient = _supabaseService.client;

      final rides = await supabaseClient
          .from('ride_requests')
          .select('''
            *,
            user:users!ride_requests_user_id_fkey(id, email, display_name, phone_number)
          ''')
          .eq('driver_id', _driverId!)
          .or('status.eq.accepted,status.eq.in_progress,status.eq.completed,status.eq.cancelled')
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _rides = (rides as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverHistory] Error cargando historial: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'accepted':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'in_progress':
        return 'En Progreso';
      case 'accepted':
        return 'Aceptado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Viajes', style: GoogleFonts.exo()),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay viajes en el historial',
                    style: GoogleFonts.exo(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _rides.length,
                itemBuilder: (context, index) {
                  final ride = _rides[index];
                  final origin = ride['origin'] as Map?;
                  final destination = ride['destination'] as Map?;
                  final user = ride['user'] as Map?;
                  final status = ride['status']?.toString() ?? 'unknown';
                  final createdAt = ride['created_at']?.toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusText(status),
                                  style: GoogleFonts.exo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(status),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (createdAt != null)
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(createdAt)),
                                  style: GoogleFonts.exo(fontSize: 12, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 20, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  origin?['address']?.toString() ?? 'Origen no especificado',
                                  style: GoogleFonts.exo(fontSize: 14, fontWeight: FontWeight.w500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 20, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  destination?['address']?.toString() ?? 'Destino no especificado',
                                  style: GoogleFonts.exo(fontSize: 14, fontWeight: FontWeight.w500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                              if (ride['price'] != null) ...[
                                const Spacer(),
                                Text(
                                  '\$${ride['price'].toStringAsFixed(2)}',
                                  style: GoogleFonts.exo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
