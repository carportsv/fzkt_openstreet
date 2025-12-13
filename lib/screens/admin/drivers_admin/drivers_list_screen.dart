import 'package:flutter/material.dart';
import '../../../auth/supabase_service.dart';
import 'driver_form_screen.dart';

class DriversListScreen extends StatefulWidget {
  final String status;

  const DriversListScreen({super.key, required this.status});

  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String _searchTerm = '';
  int _recordsPerPage = 10;
  int _currentPage = 1;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      setState(() => _loading = true);
      final supabaseClient = _supabaseService.client;

      var query = supabaseClient.from('drivers').select('''
            *,
            user:users(id, email, display_name, phone_number)
          ''');

      // Filtrar por estado
      if (widget.status == 'active') {
        query = query.eq('status', 'active');
      } else if (widget.status == 'suspended') {
        query = query.eq('status', 'busy');
      } else if (widget.status == 'pending') {
        query = query.eq('status', 'inactive').eq('is_available', true);
      } else if (widget.status == 'deleted') {
        query = query.eq('status', 'inactive').eq('is_available', false);
      }

      final response = await query.order('created_at', ascending: false);

      final driversList = response as List? ?? [];
      setState(() {
        _drivers = List<Map<String, dynamic>>.from(driversList);
        _filterDrivers();
      });
    } catch (e) {
      debugPrint('Error cargando conductores: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando conductores: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filterDrivers() {
    List<Map<String, dynamic>> filtered = [..._drivers];

    // Filtrar por término de búsqueda
    if (_searchTerm.isNotEmpty) {
      final term = _searchTerm.toLowerCase();
      filtered = filtered.where((driver) {
        final user = driver['user'] as Map<String, dynamic>?;
        final name = user?['display_name']?.toString().toLowerCase() ?? '';
        final email = user?['email']?.toString().toLowerCase() ?? '';
        final carInfo = driver['car_info'] as Map<String, dynamic>?;
        final make = carInfo?['model']?.toString().split(' ').first.toLowerCase() ?? '';
        final model = carInfo?['model']?.toString().toLowerCase() ?? '';
        final regNo = carInfo?['plate']?.toString().toLowerCase() ?? '';

        return name.contains(term) ||
            email.contains(term) ||
            make.contains(term) ||
            model.contains(term) ||
            regNo.contains(term);
      }).toList();
    }

    // Paginación
    final startIndex = (_currentPage - 1) * _recordsPerPage;
    final endIndex = startIndex + _recordsPerPage;
    filtered = filtered.length > startIndex
        ? filtered.sublist(startIndex, endIndex > filtered.length ? filtered.length : endIndex)
        : [];

    setState(() => _filteredDrivers = filtered);
  }

  @override
  void didUpdateWidget(DriversListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _loadDrivers();
    }
  }

  String _getStatusLabel() {
    switch (widget.status) {
      case 'active':
        return 'Active';
      case 'suspended':
        return 'Suspended';
      case 'pending':
        return 'Pending';
      case 'deleted':
        return 'Deleted';
      default:
        return 'All';
    }
  }

  int get _totalPages {
    final total = _searchTerm.isNotEmpty
        ? _drivers.where((driver) {
            final term = _searchTerm.toLowerCase();
            final user = driver['user'] as Map<String, dynamic>?;
            final name = user?['display_name']?.toString().toLowerCase() ?? '';
            final email = user?['email']?.toString().toLowerCase() ?? '';
            final carInfo = driver['car_info'] as Map<String, dynamic>?;
            final make = carInfo?['model']?.toString().split(' ').first.toLowerCase() ?? '';
            final model = carInfo?['model']?.toString().toLowerCase() ?? '';
            final regNo = carInfo?['plate']?.toString().toLowerCase() ?? '';
            return name.contains(term) ||
                email.contains(term) ||
                make.contains(term) ||
                model.contains(term) ||
                regNo.contains(term);
          }).length
        : _drivers.length;
    return (total / _recordsPerPage).ceil();
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
              // Title
              Text(
                'Driver List - ${_getStatusLabel()}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A202C),
                  fontSize: isTablet ? null : 20,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 16),
              // Controls
              _buildControls(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              // Table
              Expanded(child: _buildTable()),
              SizedBox(height: isTablet ? 16 : 12),
              // Pagination
              if (_totalPages > 1) _buildPagination(),
              // Add New Button
              _buildAddNewButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_buildRecordsDropdown(), const SizedBox(height: 12), _buildSearchField()],
          );
        }

        return Row(
          children: [
            SizedBox(width: 150, child: _buildRecordsDropdown()),
            const SizedBox(width: 12),
            Expanded(child: _buildSearchField()),
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
          items: [10, 25, 50]
              .map(
                (int value) => DropdownMenuItem<int>(value: value, child: Text('$value Records')),
              )
              .toList(),
          onChanged: (newValue) {
            setState(() {
              _recordsPerPage = newValue!;
              _currentPage = 1;
              _filterDrivers();
            });
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
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
          suffixIcon: Icon(Icons.search),
        ),
        onChanged: (value) {
          setState(() {
            _searchTerm = value;
            _currentPage = 1;
            _filterDrivers();
          });
        },
      ),
    );
  }

  Widget _buildTable() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredDrivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_taxi, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No hay conductores disponibles', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTableHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredDrivers.length,
              itemBuilder: (context, index) {
                final driver = _filteredDrivers[index];
                final displayNumber = (_currentPage - 1) * _recordsPerPage + index + 1;
                return _buildTableRow(driver, displayNumber);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 800;

    if (isNarrow) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: const Text('Driver Information', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          SizedBox(width: 60, child: _buildHeaderCell('No.')),
          Expanded(flex: 2, child: _buildHeaderCell('Name')),
          Expanded(flex: 2, child: _buildHeaderCell('Email')),
          Expanded(flex: 1, child: _buildHeaderCell('Make')),
          Expanded(flex: 1, child: _buildHeaderCell('Model')),
          Expanded(flex: 1, child: _buildHeaderCell('Reg. No.')),
          Expanded(flex: 1, child: _buildHeaderCell('Documents')),
          Expanded(flex: 1, child: _buildHeaderCell('')),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> driver, int number) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 800;
    final user = driver['user'] as Map<String, dynamic>?;
    final carInfo = driver['car_info'] as Map<String, dynamic>?;
    final name = user?['display_name'] ?? user?['email'] ?? 'N/A';
    final email = user?['email'] ?? 'N/A';
    final make = carInfo?['model']?.toString().split(' ').first ?? 'N/A';
    final model = carInfo?['model'] ?? 'N/A';
    final regNo = carInfo?['plate'] ?? 'N/A';
    final documentsStatus = 'Fine'; // Simulado

    if (isNarrow) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$number. $name', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(email, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('$make $model - $regNo'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Documents: $documentsStatus',
                  style: const TextStyle(color: Color(0xFF4CAF50)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Color(0xFFFF9800)),
                      onPressed: () => _handleEdit(driver),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFFF44336)),
                      onPressed: () => _handleDelete(driver),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text('$number')),
          Expanded(flex: 2, child: Text(name.toString())),
          Expanded(flex: 2, child: Text(email.toString())),
          Expanded(flex: 1, child: Text(make.toString())),
          Expanded(flex: 1, child: Text(model.toString())),
          Expanded(flex: 1, child: Text(regNo.toString())),
          Expanded(
            flex: 1,
            child: Text(
              documentsStatus,
              style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: const Color(0xFFFF9800),
                  onPressed: () => _handleEdit(driver),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: const Color(0xFFF44336),
                  onPressed: () => _handleDelete(driver),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                    _filterDrivers();
                  });
                }
              : null,
          child: const Text('Anterior'),
        ),
        const SizedBox(width: 16),
        Text('Página $_currentPage de $_totalPages'),
        const SizedBox(width: 16),
        TextButton(
          onPressed: _currentPage < _totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                    _filterDrivers();
                  });
                }
              : null,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }

  Widget _buildAddNewButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D4ED8),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Agregar Nuevo Conductor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverFormScreen(),
            ),
          );
          if (result == true) {
            await _loadDrivers();
          }
        },
      ),
    );
  }

  void _handleEdit(Map<String, dynamic> driver) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverFormScreen(driverData: driver),
      ),
    );
    if (result == true) {
      await _loadDrivers();
    }
  }

  void _handleDelete(Map<String, dynamic> driver) {
    final user = driver['user'] as Map<String, dynamic>?;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Conductor'),
        content: Text(
          '¿Estás seguro de que quieres eliminar a ${user?['display_name'] ?? 'este conductor'}?\n\nEl conductor será marcado como eliminado y no aparecerá en las listas activas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (!mounted) return;
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                navigator.pop();

                final supabaseClient = _supabaseService.client;
                final driverId = driver['id'] as String;

                // Marcar como eliminado (status='inactive', is_available=false)
                await supabaseClient
                    .from('drivers')
                    .update({
                      'status': 'inactive',
                      'is_available': false,
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', driverId);

                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Conductor eliminado exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Recargar la lista
                await _loadDrivers();
              } catch (e) {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar conductor: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
