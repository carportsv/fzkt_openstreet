import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../auth/login_screen.dart';
import '../../auth/user_service.dart';
import '../admin/admin_home_screen.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla pública para solicitar viajes sin autenticación
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _priceController = TextEditingController();
  final _distanceController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();

  // Form State
  String _selectedPriority = 'normal';
  final bool _isLoading = false;

  // Map State
  final MapController _mapController = MapController();
  LatLng? _originCoords;
  LatLng? _destinationCoords;
  Marker? _originMarker;
  Marker? _destinationMarker;
  Polyline? _routePolyline;
  String? _activeInputType; // 'origin' or 'destination'
  List<Map<String, dynamic>> _autocompleteResults = [];
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  Timer? _debounceTimer;

  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Escuchar cambios de autenticación
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null && mounted) {
        // Si el usuario se autentica, verificar rol y navegar
        try {
          final role = await _userService
              .getUserRole(user.uid)
              .timeout(const Duration(seconds: 5), onTimeout: () => 'user');

          if (mounted) {
            // Solo admin puede acceder a pantallas protegidas
            if (role == 'admin') {
              Navigator.of(
                context,
              ).pushReplacement(MaterialPageRoute(builder: (context) => const AdminHomeScreen()));
            } else {
              // Usuario regular o driver: quedarse en /welcome o redirigir
              // No hacer nada, quedarse en WelcomeScreen
            }
          }
        } catch (e) {
          // Error al obtener rol, quedarse en WelcomeScreen
          if (kDebugMode) {
            debugPrint('Error obteniendo rol en WelcomeScreen: $e');
          }
        }
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      // Verificar permisos
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          debugPrint('⚠️ Servicios de ubicación deshabilitados');
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            debugPrint('⚠️ Permisos de ubicación denegados');
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          debugPrint('⚠️ Permisos de ubicación denegados permanentemente');
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Obtener ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = location;
        _isLoadingLocation = false;
      });

      // Centrar el mapa en la ubicación actual
      if (mounted) {
        _mapController.move(location, _mapController.camera.zoom);
      }

      if (kDebugMode) {
        debugPrint('✅ Ubicación actual obtenida: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error obteniendo ubicación: $e');
      }
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _originController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _distanceController.dispose();
    _clientNameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _mapController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cuenta requerida'),
        content: const Text(
          'Necesitas crear una cuenta para solicitar viajes. ¿Deseas crear una cuenta ahora?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimaryColor),
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToLogin();
            },
            child: const Text('Crear cuenta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Viaje'),
        backgroundColor: _kPrimaryColor,
        actions: [
          TextButton.icon(
            onPressed: _navigateToLogin,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Crear cuenta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeader(context),
            const SizedBox(height: _kSpacing * 1.5),

            // Main Content
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return constraints.maxWidth > 900 ? _buildWideLayout() : _buildNarrowLayout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Layout Builders ==========

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form Section
        Expanded(flex: 2, child: _buildForm()),

        // Spacer
        const SizedBox(width: _kSpacing * 1.5),

        // Map Section
        Expanded(flex: 3, child: _buildMapPlaceholder()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return _buildForm();
  }

  // ========== UI Components ==========

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Solicitar Nuevo Viaje',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _kTextColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete los detalles para solicitar un nuevo viaje',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Location Fields with autocomplete
            _buildAddressField(
              label: 'Origen *',
              controller: _originController,
              focusNode: _originFocusNode,
              icon: Icons.location_on,
              type: 'origin',
              validator: _validateRequiredField,
            ),

            _buildAddressField(
              label: 'Destino *',
              controller: _destinationController,
              focusNode: _destinationFocusNode,
              icon: Icons.flag,
              type: 'destination',
              validator: _validateRequiredField,
            ),

            // Price & Distance Row
            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    label: 'Precio (\$)',
                    controller: _priceController,
                    isNumeric: true,
                    validator: _validatePrice,
                  ),
                ),
                const SizedBox(width: _kSpacing),
                Expanded(
                  child: _buildTextFormField(
                    label: 'Distancia (km)',
                    controller: _distanceController,
                    isNumeric: true,
                    readOnly: true,
                  ),
                ),
              ],
            ),

            // Client Info
            _buildTextFormField(
              label: 'Nombre del Cliente *',
              controller: _clientNameController,
              validator: _validateRequiredField,
            ),

            // Date & Time Picker
            Row(
              children: [
                Expanded(
                  child: _buildDatePickerField(
                    label: 'Fecha del Viaje',
                    controller: _dateController,
                  ),
                ),
                const SizedBox(width: _kSpacing),
                Expanded(
                  child: _buildTimePickerField(
                    label: 'Hora del Viaje',
                    controller: _timeController,
                  ),
                ),
              ],
            ),

            // Priority Dropdown
            _buildDropdownFormField(
              label: 'Prioridad',
              value: _selectedPriority,
              items: const ['normal', 'low', 'high', 'urgent'],
              onChanged: (val) => setState(() => _selectedPriority = val!),
            ),

            // Additional Notes
            _buildTextFormField(
              label: 'Notas Adicionales',
              controller: _notesController,
              maxLines: 3,
            ),

            // Action Buttons
            const SizedBox(height: _kSpacing * 1.5),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: constraints.maxHeight > 0 ? constraints.maxHeight : 600,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            child: _currentLocation == null && _isLoadingLocation
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Obteniendo ubicación...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _currentLocation ??
                          (_originCoords ?? (_destinationCoords ?? const LatLng(0, 0))),
                      initialZoom:
                          _currentLocation != null ||
                              _originCoords != null ||
                              _destinationCoords != null
                          ? 13.0
                          : 2.0,
                      onTap: _handleMapTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.fzkt_openstreet',
                      ),
                      if (_originMarker != null) MarkerLayer(markers: [_originMarker!]),
                      if (_destinationMarker != null) MarkerLayer(markers: [_destinationMarker!]),
                      if (_routePolyline != null) PolylineLayer(polylines: [_routePolyline!]),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildAddressField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String type,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            readOnly: _activeInputType != type,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              prefixIcon: Icon(icon),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Escribir',
                    onPressed: () => _enableInput(type),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map, size: 20),
                    tooltip: 'Seleccionar del mapa',
                    onPressed: () => _selectFromMap(type),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              hintText: _activeInputType != type
                  ? 'Haga clic en "Escribir" o "Seleccionar del mapa" para elegir dirección'
                  : null,
            ),
            validator: validator,
            onChanged: _activeInputType == type
                ? (value) => _onAddressInputChanged(value, type)
                : null,
          ),
          if (_autocompleteResults.isNotEmpty && _activeInputType == type)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _autocompleteResults.length,
                itemBuilder: (context, index) {
                  final result = _autocompleteResults[index];
                  final address = result['display_name'] as String? ?? '';
                  return ListTile(
                    dense: true,
                    title: Text(
                      address,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectAddressFromAutocomplete(result, type),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Cancel Button
        TextButton(onPressed: _handleCancel, child: const Text('Cancelar')),

        const SizedBox(width: _kSpacing / 2),

        // Create Ride Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _isLoading ? null : _handleCreateRide,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Solicitar Viaje', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  // ========== Form Field Builders ==========

  Widget _buildTextFormField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool isNumeric = false,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: icon != null ? Icon(icon) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDatePickerField({required String label, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        onTap: _showDatePicker,
      ),
    );
  }

  Widget _buildTimePickerField({required String label, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        onTap: _showTimePicker,
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        initialValue: items.contains(value) ? value : null,
        hint: const Text('Seleccione una opción'),
        items: items
            .map((String item) => DropdownMenuItem<String>(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }

  // ========== Event Handlers ==========

  Future<void> _showDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
    }
  }

  Future<void> _showTimePicker() async {
    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());

    if (pickedTime != null) {
      final now = DateTime.now();
      _timeController.text = DateFormat(
        'HH:mm',
      ).format(DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute));
    }
  }

  void _handleCancel() {
    // Clear form
    _originController.clear();
    _destinationController.clear();
    _priceController.clear();
    _distanceController.clear();
    _clientNameController.clear();
    _dateController.clear();
    _timeController.clear();
    _notesController.clear();
    setState(() {
      _selectedPriority = 'normal';
      _originCoords = null;
      _destinationCoords = null;
      _originMarker = null;
      _destinationMarker = null;
      _routePolyline = null;
      _autocompleteResults = [];
    });
  }

  Future<void> _handleCreateRide() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verificar autenticación antes de proceder
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _showAuthRequiredDialog();
      return;
    }

    // Si está autenticado, verificar rol y navegar
    if (mounted) {
      try {
        final userService = UserService();
        final role = await userService
            .getUserRole(firebaseUser.uid)
            .timeout(const Duration(seconds: 5), onTimeout: () => 'user');

        // Solo admin puede acceder a pantallas protegidas
        if (mounted) {
          if (role == 'admin') {
            Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute(builder: (context) => const AdminHomeScreen()));
          } else {
            // Usuario regular: mostrar mensaje de que necesita ser admin
            // O redirigir a /welcome
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Solo administradores pueden solicitar viajes desde aquí'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        // Error al obtener rol
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error verificando permisos: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ========== Validation Methods ==========

  String? _validateRequiredField(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'El precio es requerido';
    }
    if (double.tryParse(value) == null) {
      return 'Por favor ingrese un número válido';
    }
    return null;
  }

  // ========== Map and Address Methods ==========

  void _enableInput(String type) {
    setState(() {
      _activeInputType = type;
    });
    if (type == 'origin') {
      _originFocusNode.requestFocus();
    } else {
      _destinationFocusNode.requestFocus();
    }
  }

  void _selectFromMap(String type) {
    setState(() {
      _activeInputType = type;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Toca en el mapa para seleccionar ${type == 'origin' ? 'origen' : 'destino'}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleMapTap(TapPosition position, LatLng point) {
    if (_activeInputType == null) return;

    if (_activeInputType == 'origin') {
      _originCoords = point;
      _updateOriginMarker(point);
      _reverseGeocode(point, _originController, 'origin');
    } else {
      _destinationCoords = point;
      _updateDestinationMarker(point);
      _reverseGeocode(point, _destinationController, 'destination');
    }

    // Calcular ruta si ambos puntos están establecidos
    if (_originCoords != null && _destinationCoords != null) {
      _calculateRoute();
    }

    setState(() {
      _activeInputType = null;
    });
  }

  void _updateOriginMarker(LatLng point) {
    setState(() {
      _originMarker = Marker(
        point: point,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      );
    });
    _centerMapOnPoints();
  }

  void _updateDestinationMarker(LatLng point) {
    setState(() {
      _destinationMarker = Marker(
        point: point,
        width: 40,
        height: 40,
        child: const Icon(Icons.flag, color: Colors.green, size: 40),
      );
    });
    _centerMapOnPoints();
  }

  void _centerMapOnPoints() {
    if (_originCoords != null && _destinationCoords != null) {
      final centerLat = (_originCoords!.latitude + _destinationCoords!.latitude) / 2;
      final centerLon = (_originCoords!.longitude + _destinationCoords!.longitude) / 2;
      final center = LatLng(centerLat, centerLon);

      final distance = const Distance();
      final distanceInKm = distance.as(LengthUnit.Kilometer, _originCoords!, _destinationCoords!);

      double zoom;
      if (distanceInKm < 1) {
        zoom = 15.0;
      } else if (distanceInKm < 5) {
        zoom = 13.0;
      } else if (distanceInKm < 20) {
        zoom = 11.0;
      } else if (distanceInKm < 50) {
        zoom = 9.0;
      } else {
        zoom = 7.0;
      }

      _mapController.move(center, zoom);
    } else if (_originCoords != null) {
      _mapController.move(_originCoords!, 15.0);
    } else if (_destinationCoords != null) {
      _mapController.move(_destinationCoords!, 15.0);
    }
  }

  Future<void> _onAddressInputChanged(String query, String type) async {
    _debounceTimer?.cancel();

    if (query.length < 2) {
      setState(() {
        if (_activeInputType == type) {
          _autocompleteResults = [];
        }
      });
      return;
    }

    setState(() {
      _activeInputType = type;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _searchAddresses(query);
        if (mounted && _activeInputType == type) {
          setState(() {
            _autocompleteResults = results;
          });
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error buscando direcciones: $e');
        }
        if (mounted && _activeInputType == type) {
          setState(() {
            _autocompleteResults = [];
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> _searchAddresses(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'format=json&'
        'q=${Uri.encodeComponent(query)}&'
        'limit=10&'
        'addressdetails=1&'
        'extratags=1&'
        'namedetails=1&'
        'accept-language=es,en&'
        'dedupe=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'TaxiApp/1.0',
          'Referer': 'https://nominatim.openstreetmap.org/',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) {
          return [];
        }

        final results = data
            .map(
              (item) => {
                'display_name': item['display_name'] as String? ?? '',
                'lat': double.tryParse(item['lat'] as String? ?? '0') ?? 0.0,
                'lon': double.tryParse(item['lon'] as String? ?? '0') ?? 0.0,
                'importance': (item['importance'] as num?)?.toDouble() ?? 0.0,
                'type': item['type'] as String? ?? '',
                'class': item['class'] as String? ?? '',
              },
            )
            .where((item) => item['lat'] != 0.0 && item['lon'] != 0.0)
            .toList();

        results.sort((a, b) {
          final importanceA = a['importance'] as double;
          final importanceB = b['importance'] as double;
          return importanceB.compareTo(importanceA);
        });

        return results
            .map(
              (item) => {
                'display_name': item['display_name'] as String,
                'lat': item['lat'] as double,
                'lon': item['lon'] as double,
              },
            )
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error en búsqueda de direcciones: $e');
      }
      return [];
    }
  }

  void _selectAddressFromAutocomplete(Map<String, dynamic> result, String type) {
    final address = result['display_name'] as String;
    final lat = result['lat'] as double;
    final lon = result['lon'] as double;
    final point = LatLng(lat, lon);

    if (type == 'origin') {
      _originController.text = address;
      _originCoords = point;
      _updateOriginMarker(point);
    } else {
      _destinationController.text = address;
      _destinationCoords = point;
      _updateDestinationMarker(point);
    }

    setState(() {
      _autocompleteResults = [];
      _activeInputType = null;
    });

    if (_originCoords != null && _destinationCoords != null) {
      _calculateRoute();
    }
  }

  Future<void> _reverseGeocode(LatLng point, TextEditingController controller, String type) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
        ),
        headers: {'Accept': 'application/json', 'User-Agent': 'TaxiApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['display_name'] as String? ?? '';
        controller.text = address;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error en geocodificación inversa: $e');
      }
    }
  }

  Future<void> _calculateRoute() async {
    if (_originCoords == null || _destinationCoords == null) return;

    try {
      setState(() {
        _routePolyline = Polyline(
          points: [_originCoords!, _destinationCoords!],
          strokeWidth: 3.0,
          color: Colors.blue,
        );
      });

      final distance = const Distance();
      final distanceInKm = distance.as(LengthUnit.Kilometer, _originCoords!, _destinationCoords!);
      _distanceController.text = distanceInKm.toStringAsFixed(2);

      final estimatedPrice = distanceInKm * 0.5;
      if (_priceController.text.isEmpty) {
        _priceController.text = estimatedPrice.toStringAsFixed(2);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculando ruta: $e');
      }
    }
  }
}
