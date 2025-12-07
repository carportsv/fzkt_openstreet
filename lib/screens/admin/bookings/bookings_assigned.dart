import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/supabase_service.dart';

class BookingsAssignedScreen extends StatefulWidget {
  const BookingsAssignedScreen({super.key});

  @override
  State<BookingsAssignedScreen> createState() => _BookingsAssignedScreenState();
}

class _BookingsAssignedScreenState extends State<BookingsAssignedScreen> {
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
    _loadAssignedRides();
  }

  Future<void> _loadAssignedRides() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseClient = _supabaseService.client;

      // Cargar viajes con driver_id asignado que estén en estado 'requested' o 'accepted'
      // Los viajes con driver_id pero status 'requested' están asignados esperando aceptación
      // Los viajes con status 'accepted' ya fueron aceptados por el driver
      final selectQuery = '''
        *,
        user:users!ride_requests_user_id_fkey(id, email, display_name, phone_number)
      ''';

      // Preparar filtros de fecha si existen
      String? dateFilter;
      String? endDateFilter;
      if (_selectedDate != null) {
        final date = DateTime.parse(_selectedDate!);
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        dateFilter = startOfDay.toIso8601String();
        endDateFilter = endOfDay.toIso8601String();
      }

      // Consulta para bookings con driver_id asignado pero aún en 'requested' (esperando aceptación)
      var requestedWithDriverQuery = supabaseClient
          .from('ride_requests')
          .select(selectQuery)
          .eq('status', 'requested')
          .not('driver_id', 'is', null);

      // Consulta para bookings con status 'accepted' (ya aceptados por el driver)
      var acceptedQuery = supabaseClient
          .from('ride_requests')
          .select(selectQuery)
          .eq('status', 'accepted')
          .not('driver_id', 'is', null);

      // Aplicar filtros de fecha si existen
      if (dateFilter != null && endDateFilter != null) {
        requestedWithDriverQuery = requestedWithDriverQuery
            .gte('created_at', dateFilter)
            .lt('created_at', endDateFilter);
        acceptedQuery = acceptedQuery.gte('created_at', dateFilter).lt('created_at', endDateFilter);
      }

      // Ejecutar ambas consultas en paralelo
      if (kDebugMode) {
        debugPrint('[BookingsAssigned] Ejecutando consulta para "requested" con driver_id...');
      }
      final requestedWithDriverResponse = await requestedWithDriverQuery.order(
        'created_at',
        ascending: false,
      );

      if (kDebugMode) {
        debugPrint('[BookingsAssigned] Ejecutando consulta para status "accepted"...');
      }
      final acceptedResponse = await acceptedQuery.order('created_at', ascending: false);

      // Combinar los resultados y eliminar duplicados
      final requestedWithDriverList = (requestedWithDriverResponse as List)
          .cast<Map<String, dynamic>>();
      final acceptedList = (acceptedResponse as List).cast<Map<String, dynamic>>();

      if (kDebugMode) {
        debugPrint(
          '[BookingsAssigned] Bookings "requested" con driver_id: ${requestedWithDriverList.length}',
        );
        debugPrint('[BookingsAssigned] Bookings con status "accepted": ${acceptedList.length}');
        for (var ride in requestedWithDriverList) {
          debugPrint(
            '[BookingsAssigned] Requested+Driver - ID: ${ride['id']}, Status: ${ride['status']}, Driver ID: ${ride['driver_id']}',
          );
        }
      }

      // Usar un Set para eliminar duplicados basado en el ID
      final Map<String, Map<String, dynamic>> uniqueRides = {};
      for (var ride in requestedWithDriverList) {
        final id = ride['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          uniqueRides[id] = ride;
        }
      }
      for (var ride in acceptedList) {
        final id = ride['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          uniqueRides[id] = ride;
        }
      }

      final response = uniqueRides.values.toList();

      // Ordenar por fecha de creación (más recientes primero)
      response.sort((a, b) {
        final dateA = a['created_at'] != null ? DateTime.parse(a['created_at']) : DateTime(1970);
        final dateB = b['created_at'] != null ? DateTime.parse(b['created_at']) : DateTime(1970);
        return dateB.compareTo(dateA);
      });

      if (kDebugMode) {
        debugPrint(
          '[BookingsAssigned] Total de bookings asignados cargados: ${(response as List).length}',
        );
        for (var ride in (response as List)) {
          debugPrint(
            '[BookingsAssigned] Booking ID: ${ride['id']}, Status: ${ride['status']}, Driver ID: ${ride['driver_id']}',
          );
        }
      }

      if (mounted) {
        setState(() {
          _rides = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cargando viajes asignados: $e');
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
                    'Bookings - Assigned',
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
                        onPressed: _loadAssignedRides,
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
              Expanded(child: _buildBookingsTable()),
              SizedBox(height: isTablet ? 16 : 12),
              _buildBottomActions(),
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
                    _loadAssignedRides();
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
            _loadAssignedRides();
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

  Widget _buildBookingsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTableHeader(),
          Container(constraints: const BoxConstraints(minHeight: 200), child: _buildTableContent()),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: isTablet
          ? Row(
              children: [
                _buildHeaderCell('Order No.', flex: 1),
                _buildHeaderCell('Passenger', flex: 1),
                _buildHeaderCell('Date & Time', flex: 1),
                _buildHeaderCell('Pick Up', flex: 2),
                _buildHeaderCell('Drop Off', flex: 2),
                _buildHeaderCell('Vehicle', flex: 1),
                _buildHeaderCell('Payment', flex: 1),
                _buildHeaderCell('Fare', flex: 1),
                _buildHeaderCell('Driver', flex: 1),
                _buildHeaderCell('Acciones', flex: 1),
              ],
            )
          : const Text(
              'Bookings',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildTableContent() {
    if (_isLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 200,
        child: Center(
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
              ElevatedButton(onPressed: _loadAssignedRides, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    // Filtrar por búsqueda
    final filteredRides = _rides.where((ride) {
      if (_searchTerm.isEmpty) return true;

      final origin = (ride['origin'] as Map?)?['address']?.toString().toLowerCase() ?? '';
      final destination = (ride['destination'] as Map?)?['address']?.toString().toLowerCase() ?? '';
      final clientName = ride['client_name']?.toString().toLowerCase() ?? '';
      final userEmail = (ride['user'] as Map?)?['email']?.toString().toLowerCase() ?? '';

      return origin.contains(_searchTerm) ||
          destination.contains(_searchTerm) ||
          clientName.contains(_searchTerm) ||
          userEmail.contains(_searchTerm);
    }).toList();

    if (filteredRides.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32.0),
        child: const Center(
          child: Text('No Records', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    if (isTablet) {
      return ListView.builder(
        shrinkWrap: true,
        itemCount: filteredRides.length,
        itemBuilder: (context, index) {
          final ride = filteredRides[index];
          return _buildTableRow(ride, isTablet);
        },
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        itemCount: filteredRides.length,
        itemBuilder: (context, index) {
          final ride = filteredRides[index];
          return _buildMobileCard(ride);
        },
      );
    }
  }

  Widget _buildTableRow(Map<String, dynamic> ride, bool isTablet) {
    final origin = (ride['origin'] as Map?)?['address'] ?? 'N/A';
    final destination = (ride['destination'] as Map?)?['address'] ?? 'N/A';
    final clientName = ride['client_name'] ?? 'N/A';
    final price = ride['price'] ?? 0.0;
    final createdAt = ride['created_at'] != null
        ? DateTime.parse(ride['created_at'])
        : DateTime.now();
    final driverId = ride['driver_id']?.toString() ?? 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              ride['id']?.toString().substring(0, 8) ?? 'N/A',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              clientName.toString(),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              DateFormat('MM/dd HH:mm').format(createdAt),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              origin.toString(),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              destination.toString(),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(flex: 1, child: Text('N/A', style: const TextStyle(fontSize: 12))),
          Expanded(flex: 1, child: Text('Cash', style: const TextStyle(fontSize: 12))),
          Expanded(
            flex: 1,
            child: Text(
              '\$${price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              driverId != 'N/A' ? driverId.substring(0, 8) : 'N/A',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  color: Colors.blue,
                  tooltip: 'Cambiar conductor',
                  onPressed: () => _showChangeDriverDialog(ride),
                ),
                IconButton(
                  icon: const Icon(Icons.undo, size: 18),
                  color: Colors.orange,
                  tooltip: 'Regresar a pendientes',
                  onPressed: () => _returnToPending(ride),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> ride) {
    final origin = (ride['origin'] as Map?)?['address'] ?? 'N/A';
    final destination = (ride['destination'] as Map?)?['address'] ?? 'N/A';
    final clientName = ride['client_name'] ?? 'N/A';
    final price = ride['price'] ?? 0.0;
    final createdAt = ride['created_at'] != null
        ? DateTime.parse(ride['created_at'])
        : DateTime.now();
    final driverId = ride['driver_id']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order: ${ride['id']?.toString().substring(0, 8) ?? 'N/A'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Passenger: $clientName', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            'Driver: ${driverId != 'N/A' ? driverId.substring(0, 8) : 'N/A'}',
            style: const TextStyle(fontSize: 12, color: Colors.blue),
          ),
          const SizedBox(height: 4),
          Text(
            'Date: ${DateFormat('MM/dd/yyyy HH:mm').format(createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  origin.toString(),
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.red),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  destination.toString(),
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ride['status']?.toString().toUpperCase() ?? 'ASSIGNED',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: Colors.blue,
                tooltip: 'Cambiar conductor',
                onPressed: () => _showChangeDriverDialog(ride),
              ),
              IconButton(
                icon: const Icon(Icons.undo, size: 18),
                color: Colors.orange,
                tooltip: 'Regresar a pendientes',
                onPressed: () => _returnToPending(ride),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeDriverDialog(Map<String, dynamic> ride) async {
    try {
      final supabaseClient = _supabaseService.client;
      final rideId = ride['id']?.toString() ?? '';
      final currentDriverId = ride['driver_id']?.toString();

      // Cargar lista de drivers disponibles
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
          String? selectedDriverId = currentDriverId;

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
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.swap_horiz, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cambiar Conductor',
                                  style: GoogleFonts.exo(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Selecciona un nuevo conductor para este viaje',
                                  style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
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
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text('Cancelar', style: GoogleFonts.exo()),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed:
                                selectedDriverId != null && selectedDriverId != currentDriverId
                                ? () async {
                                    Navigator.of(dialogContext).pop();
                                    await _changeDriver(rideId, selectedDriverId!);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Cambiar', style: GoogleFonts.exo()),
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
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _changeDriver(String rideId, String newDriverId) async {
    try {
      final supabaseClient = _supabaseService.client;

      // Actualizar el viaje con el nuevo driver
      await supabaseClient
          .from('ride_requests')
          .update({
            'driver_id': newDriverId,
            'status': 'requested', // Mantener en requested para que el nuevo driver lo acepte
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      // Crear notificación para el nuevo driver
      final ride = await supabaseClient
          .from('ride_requests')
          .select('origin, destination')
          .eq('id', rideId)
          .maybeSingle();

      if (ride != null) {
        final origin = (ride['origin'] as Map?)?['address']?.toString() ?? 'Origen';
        final destination = (ride['destination'] as Map?)?['address']?.toString() ?? 'Destino';

        await supabaseClient.from('messages').insert({
          'type': 'ride_request',
          'title': '🚗 Nuevo viaje asignado',
          'message':
              'Tienes un nuevo viaje asignado: $origin → $destination. Revisa los detalles y acepta o rechaza.',
          'data': {'ride_id': rideId, 'action': 'driver_accept_reject'},
          'driver_id': newDriverId,
          'is_read': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conductor cambiado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAssignedRides();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar conductor: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _returnToPending(Map<String, dynamic> ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Regresar a pendientes?', style: GoogleFonts.exo()),
        content: Text(
          '¿Estás seguro de que deseas regresar este viaje a pendientes? Se quitará la asignación del conductor.',
          style: GoogleFonts.exo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: GoogleFonts.exo()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text('Regresar', style: GoogleFonts.exo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabaseClient = _supabaseService.client;
      final rideId = ride['id']?.toString() ?? '';

      // Quitar driver_id y mantener status='requested'
      await supabaseClient
          .from('ride_requests')
          .update({
            'driver_id': null,
            'status': 'requested',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaje regresado a pendientes'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadAssignedRides();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBottomActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download),
          label: const Text('Export'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade700,
            foregroundColor: Colors.white,
          ),
        ),
        Row(
          children: [
            TextButton(onPressed: null, child: const Text('Previous')),
            const SizedBox(width: 8),
            TextButton(onPressed: null, child: const Text('Next')),
          ],
        ),
      ],
    );
  }
}
