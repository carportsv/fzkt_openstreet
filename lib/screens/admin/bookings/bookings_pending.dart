import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/supabase_service.dart';

class BookingsPendingScreen extends StatefulWidget {
  const BookingsPendingScreen({super.key});

  @override
  State<BookingsPendingScreen> createState() => _BookingsPendingScreenState();
}

class _BookingsPendingScreenState extends State<BookingsPendingScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String _searchTerm = '';
  int _recordsPerPage = 10;
  String? _selectedDate;
  String? _selectedCustomer;
  String? _selectedDriver;

  List<Map<String, dynamic>> _rides = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingRides();
  }

  Future<void> _loadPendingRides() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseClient = _supabaseService.client;

      // Cargar viajes con status 'requested' y sin driver asignado
      final queryBuilder = supabaseClient
          .from('ride_requests')
          .select('''
            *,
            user:users!ride_requests_user_id_fkey(id, email, display_name, phone_number)
          ''')
          .eq('status', 'requested')
          .isFilter('driver_id', null);

      // Aplicar filtros de fecha si existen
      if (_selectedDate != null) {
        final date = DateTime.parse(_selectedDate!);
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        final response = await queryBuilder
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String())
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _rides = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
        }
        return;
      }

      // Ordenar por fecha de creación
      final response = await queryBuilder.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rides = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cargando viajes pendientes: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar viajes: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Material(
      color: Colors.white,
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bookings - Pending',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A202C),
                      fontSize: isTablet ? null : 20,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadPendingRides,
                        tooltip: 'Refresh',
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard),
                        onPressed: () {},
                        tooltip: 'Keyboard shortcuts',
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 24 : 16),
              _buildControls(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              Expanded(child: _buildBookingsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRecordsDropdown(),
              const SizedBox(height: 12),
              _buildDateFilter(),
              const SizedBox(height: 12),
              _buildCustomerFilter(),
              const SizedBox(height: 12),
              _buildDriverFilter(),
              const SizedBox(height: 12),
              _buildSearchField(),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 150, child: _buildRecordsDropdown()),
            const SizedBox(width: 12),
            Expanded(child: _buildDateFilter()),
            const SizedBox(width: 12),
            Expanded(child: _buildCustomerFilter()),
            const SizedBox(width: 12),
            Expanded(child: _buildDriverFilter()),
            const SizedBox(width: 12),
            SizedBox(width: 200, child: _buildSearchField()),
          ],
        );
      },
    );
  }

  Widget _buildRecordsDropdown() {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: DropdownButton<int>(
          value: _recordsPerPage,
          underline: const SizedBox(),
          isExpanded: true,
          items: [10, 25, 50, 100]
              .map(
                (int value) => DropdownMenuItem<int>(value: value, child: Text('$value Bookings')),
              )
              .toList(),
          onChanged: (newValue) {
            setState(() => _recordsPerPage = newValue!);
          },
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          hintText: 'Date',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          suffixIcon: _selectedDate != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() => _selectedDate = null);
                    _loadPendingRides();
                  },
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            setState(() => _selectedDate = DateFormat('yyyy-MM-dd').format(date));
            _loadPendingRides();
          }
        },
      ),
    );
  }

  Widget _buildCustomerFilter() {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: DropdownButton<String>(
          value: _selectedCustomer,
          underline: const SizedBox(),
          isExpanded: true,
          hint: const Text('All Customers'),
          items: [const DropdownMenuItem<String>(value: null, child: Text('All Customers'))],
          onChanged: (newValue) {
            setState(() => _selectedCustomer = newValue);
          },
        ),
      ),
    );
  }

  Widget _buildDriverFilter() {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: DropdownButton<String>(
          value: _selectedDriver,
          underline: const SizedBox(),
          isExpanded: true,
          hint: const Text('All Drivers'),
          items: [const DropdownMenuItem<String>(value: null, child: Text('All Drivers'))],
          onChanged: (newValue) {
            setState(() => _selectedDriver = newValue);
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Search',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          suffixIcon: Icon(Icons.search),
        ),
        onChanged: (value) {
          setState(() => _searchTerm = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildBookingsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPendingRides, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    // Filtrar por búsqueda
    final filteredRides = _rides.where((ride) {
      if (_searchTerm.isEmpty) return true;

      final origin = (ride['origin'] as Map?)?['address']?.toString().toLowerCase() ?? '';
      final destination = (ride['destination'] as Map?)?['address']?.toString().toLowerCase() ?? '';
      final user = ride['user'] as Map<String, dynamic>?;
      final userName = user?['display_name']?.toString().toLowerCase() ?? '';
      final userEmail = user?['email']?.toString().toLowerCase() ?? '';

      return origin.contains(_searchTerm) ||
          destination.contains(_searchTerm) ||
          userName.contains(_searchTerm) ||
          userEmail.contains(_searchTerm);
    }).toList();

    // Aplicar límite de registros por página
    final displayedRides = filteredRides.take(_recordsPerPage).toList();

    if (displayedRides.isEmpty) {
      return const Center(
        child: Text('No Records', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return ListView.builder(
      itemCount: displayedRides.length,
      itemBuilder: (context, index) {
        final ride = displayedRides[index];
        return _buildBookingCard(ride);
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> ride) {
    final user = ride['user'] as Map<String, dynamic>?;
    final userName = user?['display_name'] ?? user?['email'] ?? 'Sin nombre';
    final createdAt = ride['created_at'] != null
        ? DateTime.parse(ride['created_at'])
        : DateTime.now();
    final formattedDate = DateFormat('MM/dd/yyyy HH:mm').format(createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showBookingDetailsModal(ride),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar o icono
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              // Información principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName.toString(),
                      style: GoogleFonts.exo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Botón de asignar
              ride['driver_id'] == null
                  ? ElevatedButton.icon(
                      onPressed: () => _showAssignDriverDialog(ride),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Asignar Driver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Asignado',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Función helper para formatear duración
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 min';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else if (minutes > 0) {
      return '${minutes}min ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  Future<void> _showBookingDetailsModal(Map<String, dynamic> ride) async {
    final user = ride['user'] as Map<String, dynamic>?;
    final origin = (ride['origin'] as Map?)?['address'] ?? '';
    final destination = (ride['destination'] as Map?)?['address'] ?? '';
    final originCoords = (ride['origin'] as Map?)?['coordinates'] as Map?;
    final destinationCoords = (ride['destination'] as Map?)?['coordinates'] as Map?;

    // Convertir distancia de metros a kilómetros
    final distanceInMeters = (ride['distance'] ?? 0.0) as double;
    final distanceInKm = distanceInMeters / 1000.0;

    // Obtener duración en segundos
    final durationInSeconds = (ride['duration'] ?? 0) as int;

    // Controllers para edición
    final originController = TextEditingController(text: origin.toString());
    final destinationController = TextEditingController(text: destination.toString());
    final priceController = TextEditingController(text: (ride['price'] ?? 0.0).toStringAsFixed(2));
    final distanceController = TextEditingController(text: distanceInKm.toStringAsFixed(2));
    final durationController = TextEditingController(text: durationInSeconds.toString());
    final statusController = TextEditingController(text: ride['status'] ?? 'requested');

    String? selectedDriverId = ride['driver_id']?.toString();
    List<Map<String, dynamic>>? availableDrivers;

    // Cargar drivers disponibles
    try {
      final supabaseClient = _supabaseService.client;
      final driversResponse = await supabaseClient
          .from('drivers')
          .select('id, user:users!drivers_user_id_fkey(id, display_name, email, phone_number)')
          .eq('status', 'active');
      availableDrivers = (driversResponse as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cargando drivers: $e');
      }
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 900,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header mejorado con gradiente
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.edit_document, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detalles del Booking',
                                  style: GoogleFonts.exo(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'ID: ${ride['id']?.toString().substring(0, 8) ?? 'N/A'}',
                                    style: GoogleFonts.exo(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white, size: 24),
                            tooltip: 'Cerrar',
                          ),
                        ],
                      ),
                    ),
                    // Contenido con padding
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Información del usuario con card
                            _buildSectionCard(
                              title: 'Información del Usuario',
                              icon: Icons.person,
                              child: Column(
                                children: [
                                  _buildInfoRow('Nombre', user?['display_name'] ?? 'N/A'),
                                  const Divider(height: 24),
                                  _buildInfoRow('Email', user?['email'] ?? 'N/A'),
                                  const Divider(height: 24),
                                  _buildInfoRow('Teléfono', user?['phone_number'] ?? 'N/A'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Origen y Destino en cards
                            _buildSectionCard(
                              title: 'Ruta del Viaje',
                              icon: Icons.route,
                              child: Column(
                                children: [
                                  TextField(
                                    controller: originController,
                                    decoration: InputDecoration(
                                      labelText: 'Dirección de Origen',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF1D4ED8),
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.green.shade50,
                                      prefixIcon: const Icon(
                                        Icons.location_on,
                                        color: Colors.green,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: GoogleFonts.exo(),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: destinationController,
                                    decoration: InputDecoration(
                                      labelText: 'Dirección de Destino',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF1D4ED8),
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.red.shade50,
                                      prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: GoogleFonts.exo(),
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Información del viaje con card
                            _buildSectionCard(
                              title: 'Información del Viaje',
                              icon: Icons.info_outline,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: priceController,
                                          decoration: InputDecoration(
                                            labelText: 'Precio (€)',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF1D4ED8),
                                                width: 2,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.blue.shade50,
                                            prefixIcon: const Icon(
                                              Icons.attach_money,
                                              color: Color(0xFF1D4ED8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                          ),
                                          style: GoogleFonts.exo(),
                                          keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: distanceController,
                                          decoration: InputDecoration(
                                            labelText: 'Distancia (km)',
                                            helperText: 'Distancia en kilómetros',
                                            helperStyle: GoogleFonts.exo(fontSize: 11),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF1D4ED8),
                                                width: 2,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.orange.shade50,
                                            prefixIcon: const Icon(
                                              Icons.straighten,
                                              color: Colors.orange,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                          ),
                                          style: GoogleFonts.exo(),
                                          keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              controller: durationController,
                                              decoration: InputDecoration(
                                                labelText: 'Duración (segundos)',
                                                helperText: 'Ejemplo: 1800 = 30 min',
                                                helperStyle: GoogleFonts.exo(fontSize: 11),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFF1D4ED8),
                                                    width: 2,
                                                  ),
                                                ),
                                                filled: true,
                                                fillColor: Colors.purple.shade50,
                                                prefixIcon: const Icon(
                                                  Icons.timer,
                                                  color: Colors.purple,
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 16,
                                                ),
                                              ),
                                              style: GoogleFonts.exo(),
                                              keyboardType: TextInputType.number,
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.purple.shade200),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    size: 16,
                                                    color: Colors.purple.shade700,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Actual: ${_formatDuration(durationInSeconds)}',
                                                      style: GoogleFonts.exo(
                                                        fontSize: 12,
                                                        color: Colors.purple.shade700,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Estado y Conductor en cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSectionCard(
                                    title: 'Estado del Viaje',
                                    icon: Icons.info_outline,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: statusController.text,
                                      decoration: InputDecoration(
                                        labelText: 'Estado',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1D4ED8),
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.blue.shade50,
                                        prefixIcon: const Icon(
                                          Icons.info,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                      style: GoogleFonts.exo(),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'requested',
                                          child: Text('Solicitado'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'assigned',
                                          child: Text('Asignado'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'accepted',
                                          child: Text('Aceptado'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'in_progress',
                                          child: Text('En Progreso'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'completed',
                                          child: Text('Completado'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'cancelled',
                                          child: Text('Cancelado'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setDialogState(() {
                                          statusController.text = value ?? 'requested';
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSectionCard(
                                    title: 'Conductor',
                                    icon: Icons.person,
                                    child: availableDrivers != null && availableDrivers.isNotEmpty
                                        ? DropdownButtonFormField<String>(
                                            initialValue: selectedDriverId,
                                            decoration: InputDecoration(
                                              labelText: 'Conductor Asignado',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF1D4ED8),
                                                  width: 2,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: Colors.green.shade50,
                                              prefixIcon: const Icon(
                                                Icons.person,
                                                color: Colors.green,
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 16,
                                              ),
                                            ),
                                            style: GoogleFonts.exo(),
                                            items: [
                                              const DropdownMenuItem<String>(
                                                value: null,
                                                child: Text('Sin asignar'),
                                              ),
                                              ...availableDrivers.map((driver) {
                                                final driverUser =
                                                    driver['user'] as Map<String, dynamic>?;
                                                final driverName =
                                                    driverUser?['display_name'] ??
                                                    driverUser?['email'] ??
                                                    'Sin nombre';
                                                return DropdownMenuItem<String>(
                                                  value: driver['id'].toString(),
                                                  child: Text(driverName.toString()),
                                                );
                                              }),
                                            ],
                                            onChanged: (value) {
                                              setDialogState(() {
                                                selectedDriverId = value;
                                              });
                                            },
                                          )
                                        : Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.orange.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: Colors.orange.shade700,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'No hay conductores disponibles',
                                                    style: GoogleFonts.exo(
                                                      fontSize: 14,
                                                      color: Colors.orange.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Fechas con card
                            _buildSectionCard(
                              title: 'Información de Fechas',
                              icon: Icons.calendar_today,
                              child: Column(
                                children: [
                                  _buildInfoRow(
                                    'Creado',
                                    ride['created_at'] != null
                                        ? DateFormat(
                                            'dd/MM/yyyy HH:mm:ss',
                                          ).format(DateTime.parse(ride['created_at']))
                                        : 'N/A',
                                  ),
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                    'Actualizado',
                                    ride['updated_at'] != null
                                        ? DateFormat(
                                            'dd/MM/yyyy HH:mm:ss',
                                          ).format(DateTime.parse(ride['updated_at']))
                                        : 'N/A',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Botones de acción con mejor estilo
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 20),
                            label: Text(
                              'Cancelar',
                              style: GoogleFonts.exo(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final supabaseClient = _supabaseService.client;

                                // Convertir distancia de km a metros para guardar
                                final distanceKm = double.tryParse(distanceController.text) ?? 0.0;
                                final distanceMeters = distanceKm * 1000;

                                // Preparar datos para actualizar
                                final updateData = <String, dynamic>{
                                  'origin': {
                                    'address': originController.text,
                                    'coordinates': originCoords ?? {},
                                  },
                                  'destination': {
                                    'address': destinationController.text,
                                    'coordinates': destinationCoords ?? {},
                                  },
                                  'price': double.tryParse(priceController.text) ?? ride['price'],
                                  'distance': distanceMeters,
                                  'duration':
                                      int.tryParse(durationController.text) ?? ride['duration'],
                                  'status': statusController.text,
                                  'driver_id': selectedDriverId,
                                  'updated_at': DateTime.now().toIso8601String(),
                                };

                                await supabaseClient
                                    .from('ride_requests')
                                    .update(updateData)
                                    .eq('id', ride['id']);

                                // Si se asignó un driver y el status es 'requested', crear notificación
                                if (selectedDriverId != null &&
                                    statusController.text == 'requested') {
                                  await _createDriverNotification(
                                    rideId: ride['id'].toString(),
                                    driverId: selectedDriverId!,
                                    origin: originController.text,
                                    destination: destinationController.text,
                                  );
                                }

                                if (!mounted) return;
                                if (!context.mounted) return;

                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Booking actualizado exitosamente',
                                      style: GoogleFonts.exo(),
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                                _loadPendingRides();
                              } catch (e) {
                                if (!mounted) return;
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error al actualizar: ${e.toString()}',
                                      style: GoogleFonts.exo(),
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.save, size: 20),
                            label: Text(
                              'Guardar Cambios',
                              style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createDriverNotification({
    required String rideId,
    required String driverId,
    required String origin,
    required String destination,
  }) async {
    try {
      final supabaseClient = _supabaseService.client;
      await supabaseClient.from('messages').insert({
        'type': 'ride_request',
        'title': '🚗 Nuevo viaje asignado',
        'message': 'Viaje: $origin → $destination',
        'data': {'ride_id': rideId, 'action': 'driver_accept_reject'},
        'driver_id': driverId,
        'is_read': false,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BookingsPending] Error creando notificación para driver: $e');
      }
    }
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1D4ED8), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.exo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.exo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.exo(fontSize: 14, color: const Color(0xFF1A202C)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDriverDialog(Map<String, dynamic> ride) async {
    try {
      // Cargar lista de drivers disponibles
      final supabaseClient = _supabaseService.client;
      final driversResponse = await supabaseClient
          .from('drivers')
          .select('id, user:users!drivers_user_id_fkey(id, display_name, email, phone_number)')
          .eq('status', 'active');

      final drivers = (driversResponse as List).cast<Map<String, dynamic>>();

      if (drivers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay conductores disponibles'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          String? selectedDriverId;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con icono
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Asignar Conductor',
                                  style: GoogleFonts.exo(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A202C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Selecciona un conductor para este viaje',
                                  style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Lista de conductores
                      Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: drivers.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final driver = drivers[index];
                              final driverUser = driver['user'] as Map<String, dynamic>?;
                              final driverName =
                                  driverUser?['display_name'] ??
                                  driverUser?['email'] ??
                                  'Sin nombre';
                              final driverEmail = driverUser?['email'] ?? '';
                              final driverId = driver['id'] as String;
                              final isSelected = selectedDriverId == driverId;

                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    selectedDriverId = driverId;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1D4ED8).withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? const LinearGradient(
                                                  colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                                                )
                                              : null,
                                          color: isSelected ? null : Colors.grey.shade300,
                                          shape: BoxShape.circle,
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                                            : Icon(
                                                Icons.person,
                                                color: Colors.grey.shade600,
                                                size: 20,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              driverName.toString(),
                                              style: GoogleFonts.exo(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? const Color(0xFF1D4ED8)
                                                    : const Color(0xFF1A202C),
                                              ),
                                            ),
                                            if (driverEmail.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                driverEmail,
                                                style: GoogleFonts.exo(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.radio_button_checked,
                                          color: const Color(0xFF1D4ED8),
                                          size: 24,
                                        )
                                      else
                                        Icon(
                                          Icons.radio_button_unchecked,
                                          color: Colors.grey.shade400,
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.exo(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Builder(
                            builder: (buttonContext) {
                              return ElevatedButton(
                                onPressed: selectedDriverId == null
                                    ? null
                                    : () async {
                                        // Asignar driver al viaje y notificar
                                        try {
                                          // Convertir el ID a String de forma segura
                                          final rideId = ride['id']?.toString() ?? '';
                                          if (rideId.isEmpty) {
                                            throw Exception('ID del viaje no válido');
                                          }

                                          if (kDebugMode) {
                                            debugPrint(
                                              '[BookingsPending] Asignando driver: rideId=$rideId, driverId=$selectedDriverId',
                                            );
                                          }

                                          // Actualizar solo el driver_id, mantener el status actual
                                          // El status cambiará a 'accepted' cuando el driver acepte el viaje
                                          final updateResult = await supabaseClient
                                              .from('ride_requests')
                                              .update({
                                                'driver_id': selectedDriverId,
                                                'updated_at': DateTime.now().toIso8601String(),
                                              })
                                              .eq('id', rideId);

                                          if (kDebugMode) {
                                            debugPrint(
                                              '[BookingsPending] Update result: $updateResult',
                                            );
                                          }

                                          // Crear notificación para el driver asignado
                                          await _createDriverNotification(
                                            rideId: rideId,
                                            driverId: selectedDriverId!,
                                            origin:
                                                (ride['origin'] as Map?)?['address']?.toString() ??
                                                'Origen',
                                            destination:
                                                (ride['destination'] as Map?)?['address']
                                                    ?.toString() ??
                                                'Destino',
                                          );

                                          if (!mounted) return;
                                          if (!buttonContext.mounted) return;

                                          Navigator.of(buttonContext).pop();
                                          ScaffoldMessenger.of(buttonContext).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Conductor asignado exitosamente',
                                                style: GoogleFonts.exo(),
                                              ),
                                              backgroundColor: Colors.green,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                          // Recargar la lista
                                          _loadPendingRides();

                                          if (kDebugMode) {
                                            debugPrint(
                                              '[BookingsPending] Driver asignado exitosamente, recargando lista...',
                                            );
                                          }
                                        } catch (e) {
                                          if (kDebugMode) {
                                            debugPrint(
                                              '[BookingsPending] Error al asignar driver: $e',
                                            );
                                          }
                                          if (!mounted) return;
                                          if (!buttonContext.mounted) return;

                                          Navigator.of(buttonContext).pop();
                                          ScaffoldMessenger.of(buttonContext).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error al asignar conductor: ${e.toString()}',
                                                style: GoogleFonts.exo(),
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D4ED8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Asignar',
                                  style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar conductores: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
