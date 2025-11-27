import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../auth/supabase_service.dart';

class BookingsAcceptedScreen extends StatefulWidget {
  const BookingsAcceptedScreen({super.key});

  @override
  State<BookingsAcceptedScreen> createState() => _BookingsAcceptedScreenState();
}

class _BookingsAcceptedScreenState extends State<BookingsAcceptedScreen> {
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
    _loadAcceptedRides();
  }

  Future<void> _loadAcceptedRides() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseClient = _supabaseService.client;

      // Cargar viajes con status 'accepted'
      var query = supabaseClient
          .from('ride_requests')
          .select('''
            *,
            user:users!ride_requests_user_id_fkey(id, email, display_name, phone_number),
            driver:drivers(id, user:users(id, email, display_name, phone_number))
          ''')
          .eq('status', 'accepted');

      // Aplicar filtros de fecha si existen
      if (_selectedDate != null) {
        final date = DateTime.parse(_selectedDate!);
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        query = query
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rides = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cargando viajes aceptados: $e');
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
                    'Bookings - Accepted',
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
                        onPressed: _loadAcceptedRides,
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
                    _loadAcceptedRides();
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
            _loadAcceptedRides();
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
        onChanged: (value) => setState(() => _searchTerm = value.toLowerCase()),
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
              ElevatedButton(onPressed: _loadAcceptedRides, child: const Text('Reintentar')),
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
    final driver = ride['driver'];
    String driverName = 'N/A';
    if (driver != null && driver is Map<String, dynamic>) {
      final driverUser = driver['user'];
      if (driverUser is Map<String, dynamic>) {
        driverName = driverUser['display_name']?.toString() ?? 'N/A';
      }
    }

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
              driverName.toString(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
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
    final driver = ride['driver'];
    String driverName = 'N/A';
    if (driver != null && driver is Map<String, dynamic>) {
      final driverUser = driver['user'];
      if (driverUser is Map<String, dynamic>) {
        driverName = driverUser['display_name']?.toString() ?? 'N/A';
      }
    }

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
          Text('Driver: $driverName', style: const TextStyle(fontSize: 12, color: Colors.green)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Accepted',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        ],
      ),
    );
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
