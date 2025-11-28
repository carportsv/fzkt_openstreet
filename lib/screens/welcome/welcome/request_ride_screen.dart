import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/login_screen.dart';
import '../../../auth/supabase_service.dart';
import '../../../services/ride_service.dart';
import '../../../widgets/app_logo_header.dart';
import 'welcome_screen.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla para solicitar viajes (requiere autenticación)
class RequestRideScreen extends StatefulWidget {
  final String? initialOrigin;
  final String? initialDestination;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final int? initialPassengers;
  final double? initialEstimatedPrice;

  const RequestRideScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
    this.initialDate,
    this.initialTime,
    this.initialPassengers,
    this.initialEstimatedPrice,
  });

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _priceController = TextEditingController();
  final _distanceController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();
  // Card payment fields
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardNameController = TextEditingController();

  // Form State
  String _selectedPriority = 'normal';
  String _selectedVehicleType = 'sedan';
  String _selectedPaymentMethod = 'card';
  int _passengerCount = 1;
  int _childSeats = 0;
  int _handLuggage = 0;
  int _checkInLuggage = 0;
  bool _isLoading = false;

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

  final SupabaseService _supabaseService = SupabaseService();
  final RideService _rideService = RideService();

  // User state
  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Obtener usuario actual de forma segura
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
    } catch (e) {
      // Manejo seguro de excepciones para Flutter Web
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] ⚠️ Error obteniendo usuario: $e');
      }
      _currentUser = null;
    }

    // Escuchar cambios de autenticación
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
          // Cargar datos del usuario cuando cambia el estado de autenticación
          if (user != null) {
            _loadUserData();
          }
        }
      },
      onError: (error) {
        // Manejo seguro de errores en el stream para Flutter Web
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] ⚠️ Error en authStateChanges: $error');
        }
        if (mounted) {
          setState(() {
            _currentUser = null;
          });
        }
      },
    );

    // Inicializar campos con valores pasados desde WelcomeScreen
    if (widget.initialOrigin != null && widget.initialOrigin!.isNotEmpty) {
      _originController.text = widget.initialOrigin!;
    }
    if (widget.initialDestination != null && widget.initialDestination!.isNotEmpty) {
      _destinationController.text = widget.initialDestination!;
    }
    if (widget.initialDate != null) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(widget.initialDate!);
    }
    if (widget.initialTime != null) {
      _timeController.text = DateFormat(
        'HH:mm',
      ).format(DateTime(2000, 1, 1, widget.initialTime!.hour, widget.initialTime!.minute));
    }
    if (widget.initialPassengers != null) {
      _passengerCount = widget.initialPassengers!;
    }
    if (widget.initialEstimatedPrice != null) {
      _priceController.text = widget.initialEstimatedPrice!.toStringAsFixed(2);
    }

    // Cargar datos del usuario si está autenticado
    if (_currentUser != null) {
      _loadUserData();
    }

    _getCurrentLocation();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    try {
      final userData = await _supabaseService.getUserByFirebaseUid(_currentUser!.uid);
      if (userData != null && mounted) {
        setState(() {
          // Cargar datos del usuario en los campos (editables)
          if (userData['display_name'] != null) {
            _clientNameController.text = userData['display_name'] as String;
          }
          if (userData['email'] != null) {
            _clientEmailController.text = userData['email'] as String;
          }
          if (userData['phone_number'] != null) {
            _clientPhoneController.text = userData['phone_number'] as String;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cargando datos del usuario: $e');
      }
    }
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
      // Esperar a que el mapa esté renderizado antes de usar el controller
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (_mapController.camera.zoom > 0) {
              _mapController.move(location, _mapController.camera.zoom);
            } else {
              _mapController.move(location, 13.0);
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ Error al mover el mapa: $e');
            }
          }
        });
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
    _authSubscription?.cancel();
    _debounceTimer?.cancel();
    // Dispose all controllers
    _originController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _distanceController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardNameController.dispose();
    _mapController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  Future<void> _handleLogout() async {
    try {
      // Cerrar sesión de Firebase
      await FirebaseAuth.instance.signOut();

      // Esperar un momento para que Firebase procese el logout
      await Future.delayed(const Duration(milliseconds: 500));

      // Navegar a WelcomeScreen y limpiar el stack
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Manejo seguro de excepciones para Flutter Web
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cerrar sesión: ${e is Exception ? e.toString() : 'Error desconocido'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToProfile() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mi perfil (próximamente)')));
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
        title: Text(
          'Solicitar Viaje',
          style: GoogleFonts.exo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: _currentUser != null
            ? [
                // Menú de usuario con estilo profesional
                PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kBorderRadius),
                  ),
                  color: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Foto de perfil o icono
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: _currentUser!.photoURL != null
                              ? NetworkImage(_currentUser!.photoURL!)
                              : null,
                          child: _currentUser!.photoURL == null
                              ? const Icon(Icons.person, color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        // Nombre del usuario
                        Text(
                          _currentUser!.displayName ??
                              _currentUser!.email?.split('@').first ??
                              'Usuario',
                          style: GoogleFonts.exo(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                  itemBuilder: (BuildContext context) => [
                    // Información del usuario
                    PopupMenuItem<String>(
                      enabled: false,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _kPrimaryColor.withValues(alpha: 0.1),
                            backgroundImage: _currentUser!.photoURL != null
                                ? NetworkImage(_currentUser!.photoURL!)
                                : null,
                            child: _currentUser!.photoURL == null
                                ? Icon(Icons.person, color: _kPrimaryColor, size: 24)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentUser!.displayName ??
                                      _currentUser!.email?.split('@').first ??
                                      'Usuario',
                                  style: GoogleFonts.exo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _kTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_currentUser!.email != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentUser!.email!,
                                    style: GoogleFonts.exo(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuDivider(height: 1, color: Colors.grey.shade200),
                    // Opción Perfil
                    PopupMenuItem<String>(
                      value: 'profile',
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _kPrimaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.person, color: _kPrimaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Mi Perfil',
                                style: GoogleFonts.exo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Opción Cerrar sesión
                    PopupMenuItem<String>(
                      value: 'logout',
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Cerrar sesión',
                                style: GoogleFonts.exo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  onSelected: (String value) {
                    if (value == 'profile') {
                      _navigateToProfile();
                    } else if (value == 'logout') {
                      _handleLogout();
                    }
                  },
                ),
                const SizedBox(width: 8),
              ]
            : [],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, _kPrimaryColor.withValues(alpha: 0.03)],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 900) {
                    // Layout ancho: header arriba, luego form y mapa lado a lado
                    return Column(
                      children: [
                        Padding(padding: const EdgeInsets.all(24.0), child: _buildHeader(context)),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Form Section
                              Expanded(
                                flex: 2,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 24, right: 12, bottom: 24),
                                  child: _buildForm(hasInternalScroll: true),
                                ),
                              ),
                              // Map Section
                              Expanded(
                                flex: 3,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 12, right: 24),
                                  child: _buildMapPlaceholder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Layout estrecho: todo en columna con scroll
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          _buildHeader(context),
                          const SizedBox(height: _kSpacing * 2),
                          // Form Section (sin su propio scroll en layout estrecho)
                          _buildForm(hasInternalScroll: false),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          const AppLogoHeader(),
        ],
      ),
    );
  }

  // ========== Layout Builders ==========
  // Los métodos _buildWideLayout y _buildNarrowLayout ya no se usan
  // El layout ahora se maneja directamente en el método build()

  // ========== UI Components ==========

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_kSpacing * 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_car, color: _kPrimaryColor, size: 28),
          ),
          const SizedBox(width: _kSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitar Nuevo Viaje',
                  style: GoogleFonts.exo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _kTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete los detalles para solicitar un nuevo viaje',
                  style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({bool hasInternalScroll = true}) {
    final formContent = Form(
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

          // Vehicle Details Section
          _buildSectionHeader('Vehicle Details'),
          const SizedBox(height: _kSpacing),
          _buildVehicleSelection(),
          const SizedBox(height: _kSpacing),
          Row(
            children: [
              Expanded(
                child: _buildDropdownFormField(
                  label: 'Passenger',
                  value: _passengerCount.toString(),
                  items: List.generate(8, (i) => (i + 1).toString()),
                  onChanged: (val) => setState(() => _passengerCount = int.parse(val!)),
                ),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: _buildDropdownFormField(
                  label: 'Child Seats',
                  value: _childSeats.toString(),
                  items: List.generate(4, (i) => i.toString()),
                  onChanged: (val) => setState(() => _childSeats = int.parse(val!)),
                ),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: _buildDropdownFormField(
                  label: 'Hand Luggage',
                  value: _handLuggage.toString(),
                  items: List.generate(5, (i) => i.toString()),
                  onChanged: (val) => setState(() => _handLuggage = int.parse(val!)),
                ),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: _buildDropdownFormField(
                  label: 'Check-in Luggage',
                  value: _checkInLuggage.toString(),
                  items: List.generate(6, (i) => i.toString()),
                  onChanged: (val) => setState(() => _checkInLuggage = int.parse(val!)),
                ),
              ),
            ],
          ),

          const SizedBox(height: _kSpacing * 1.5),

          // Passenger Details Section
          _buildSectionHeader('Passenger Details'),
          const SizedBox(height: _kSpacing),
          _buildTextFormField(
            label: 'Full name *',
            controller: _clientNameController,
            validator: _validateRequiredField,
          ),
          _buildTextFormField(
            label: 'Email address',
            controller: _clientEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
          _buildTextFormField(
            label: 'Contact number',
            controller: _clientPhoneController,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: _kSpacing * 1.5),

          // Price & Distance Row
          Row(
            children: [
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

          // Date & Time Picker
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField(label: 'Fecha del Viaje', controller: _dateController),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: _buildTimePickerField(label: 'Hora del Viaje', controller: _timeController),
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

          const SizedBox(height: _kSpacing * 1.5),

          // Payment & Fare Section
          _buildSectionHeader('Payment & Fare'),
          const SizedBox(height: _kSpacing),
          _buildPaymentMethodSelection(),
          const SizedBox(height: _kSpacing),
          // Card details (only shown when card is selected)
          if (_selectedPaymentMethod == 'card') ...[
            _buildCardDetailsSection(),
            const SizedBox(height: _kSpacing),
          ],
          _buildFareDisplay(),

          // Action Buttons
          const SizedBox(height: _kSpacing * 1.5),
          _buildActionButtons(),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: hasInternalScroll
          ? SingleChildScrollView(padding: const EdgeInsets.all(_kSpacing * 2), child: formContent)
          : Padding(padding: const EdgeInsets.all(_kSpacing * 2), child: formContent),
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
            style: GoogleFonts.exo(fontSize: 16),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.exo(color: Colors.grey.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kBorderRadius),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kBorderRadius),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kBorderRadius),
                borderSide: BorderSide(color: _kPrimaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kPrimaryColor, _kPrimaryColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 20, color: _kPrimaryColor),
                    tooltip: 'Escribir',
                    onPressed: () => _enableInput(type),
                  ),
                  IconButton(
                    icon: Icon(Icons.map, size: 20, color: _kPrimaryColor),
                    tooltip: 'Seleccionar del mapa',
                    onPressed: () => _selectFromMap(type),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: _activeInputType != type
                  ? 'Haga clic en "Escribir" o "Seleccionar del mapa" para elegir dirección'
                  : null,
              hintStyle: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade400),
            ),
            validator: validator,
            onChanged: _activeInputType == type
                ? (value) => _onAddressInputChanged(value, type)
                : null,
          ),
          if (_autocompleteResults.isNotEmpty && _activeInputType == type)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(_kBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _autocompleteResults.length,
                itemBuilder: (context, index) {
                  final result = _autocompleteResults[index];
                  final address = result['display_name'] as String? ?? '';
                  return InkWell(
                    onTap: () => _selectAddressFromAutocomplete(result, type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: index < _autocompleteResults.length - 1 ? 1 : 0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: _kPrimaryColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              address,
                              style: GoogleFonts.exo(fontSize: 14, color: _kTextColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: _kSpacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Cancel Button
          TextButton(
            onPressed: _handleCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

          const SizedBox(width: _kSpacing),

          // Create Ride Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius)),
              elevation: 3,
              shadowColor: _kPrimaryColor.withValues(alpha: 0.4),
            ),
            onPressed: _isLoading ? null : _handleCreateRide,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Solicitar Viaje',
                        style: GoogleFonts.exo(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
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
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType:
            keyboardType ??
            (isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
        maxLines: maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: GoogleFonts.exo(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.exo(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: _kPrimaryColor, width: 2),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
          prefixIcon: icon != null ? Icon(icon, color: _kPrimaryColor) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDatePickerField({required String label, required TextEditingController controller}) {
    DateTime? selectedDate;
    if (controller.text.isNotEmpty) {
      try {
        selectedDate = DateFormat('yyyy-MM-dd').parse(controller.text);
      } catch (e) {
        // Si hay error, usar null
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: GestureDetector(
        onTap: _showDatePicker,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(
              color: selectedDate != null
                  ? _kPrimaryColor.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_today, color: _kPrimaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.exo(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(selectedDate)
                          : 'Seleccionar fecha',
                      style: GoogleFonts.exo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selectedDate != null ? _kTextColor : Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selectedDate != null) Icon(Icons.check_circle, color: _kPrimaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerField({required String label, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(
            color: controller.text.isNotEmpty
                ? _kPrimaryColor.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.access_time, color: _kPrimaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller,
                style: GoogleFonts.exo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kTextColor,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  _TimeInputFormatter(),
                ],
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'HH:mm (ej: 08:30)',
                  hintStyle: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade400),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // Campo opcional
                  }
                  // Validar formato HH:mm
                  final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5]?[0-9])$');
                  if (!timeRegex.hasMatch(value)) {
                    return 'Formato inválido. Use HH:mm (ej: 08:30)';
                  }
                  final parts = value.split(':');
                  final hour = int.tryParse(parts[0]);
                  final minute = int.tryParse(parts[1]);
                  if (hour == null || minute == null) {
                    return 'Formato inválido';
                  }
                  if (hour < 0 || hour > 23) {
                    return 'La hora debe estar entre 00 y 23';
                  }
                  if (minute < 0 || minute > 59) {
                    return 'Los minutos deben estar entre 00 y 59';
                  }
                  return null;
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.access_time, color: _kPrimaryColor, size: 20),
              onPressed: _showTimePicker,
              tooltip: 'Seleccionar hora',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String label,
    required String? value,
    required List<dynamic> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.exo(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: _kPrimaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        initialValue: value,
        hint: Text('Seleccione una opción', style: GoogleFonts.exo()),
        items: items.map<DropdownMenuItem<String>>((item) {
          if (item is DropdownMenuItem<String?>) {
            return DropdownMenuItem<String>(value: item.value, child: item.child);
          } else if (item is String) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: GoogleFonts.exo()),
            );
          }
          return DropdownMenuItem<String>(
            value: item.toString(),
            child: Text(item.toString(), style: GoogleFonts.exo()),
          );
        }).toList(),
        onChanged: onChanged,
        isExpanded: true,
        style: GoogleFonts.exo(fontSize: 16, color: _kTextColor),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(top: _kSpacing, bottom: _kSpacing),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _kPrimaryColor, width: 4)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.exo(fontSize: 18, fontWeight: FontWeight.bold, color: _kTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelection() {
    final vehicles = [
      {'type': 'sedan', 'name': 'Sedan', 'passengers': 3, 'handLuggage': 1, 'checkInLuggage': 0},
      {'type': 'suv', 'name': 'SUV', 'passengers': 6, 'handLuggage': 2, 'checkInLuggage': 2},
      {'type': 'van', 'name': 'Van', 'passengers': 8, 'handLuggage': 3, 'checkInLuggage': 4},
      {'type': 'luxury', 'name': 'Luxury', 'passengers': 3, 'handLuggage': 2, 'checkInLuggage': 1},
    ];

    final selectedVehicle = vehicles.firstWhere(
      (v) => v['type'] == _selectedVehicleType,
      orElse: () => vehicles[0],
    );

    return Container(
      padding: const EdgeInsets.all(_kSpacing),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(_kBorderRadius),
      ),
      child: Row(
        children: [
          const Text('Vehicle:-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 12),
          // Vehicle icon placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_car, size: 24),
          ),
          const SizedBox(width: 12),
          // Selected vehicle info
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kPrimaryColor),
              ),
              child: Row(
                children: [
                  Text(
                    selectedVehicle['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 16),
                      Text('${selectedVehicle['passengers']}'),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Icon(Icons.luggage, size: 16),
                      Text('${selectedVehicle['handLuggage']}'),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Icon(Icons.luggage_outlined, size: 16),
                      Text('${selectedVehicle['checkInLuggage']}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Vehicle type dropdown
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedVehicleType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: vehicles
                  .map(
                    (v) => DropdownMenuItem<String>(
                      value: v['type'] as String,
                      child: Text(v['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedVehicleType = val;
                    final vehicle = vehicles.firstWhere((v) => v['type'] == val);
                    _passengerCount = vehicle['passengers'] as int;
                    _handLuggage = vehicle['handLuggage'] as int;
                    _checkInLuggage = vehicle['checkInLuggage'] as int;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return SegmentedButton<String>(
      segments: const [ButtonSegment<String>(value: 'card', label: Text('Card'))],
      selected: {_selectedPaymentMethod},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _selectedPaymentMethod = newSelection.first;
        });
      },
    );
  }

  Widget _buildCardDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(_kSpacing),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Card Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: _kSpacing),
          _buildTextFormField(
            label: 'Card Number *',
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            validator: _validateCardNumber,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              _CardNumberFormatter(),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildTextFormField(
                  label: 'Expiry (MM/YY) *',
                  controller: _cardExpiryController,
                  keyboardType: TextInputType.number,
                  validator: _validateCardExpiry,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _CardExpiryFormatter(),
                  ],
                ),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: _buildTextFormField(
                  label: 'CVV *',
                  controller: _cardCvvController,
                  keyboardType: TextInputType.number,
                  validator: _validateCardCvv,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                ),
              ),
            ],
          ),
          _buildTextFormField(
            label: 'Name on Card *',
            controller: _cardNameController,
            validator: _validateRequiredField,
          ),
        ],
      ),
    );
  }

  Widget _buildFareDisplay() {
    return Container(
      padding: const EdgeInsets.all(_kSpacing),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Text('Journey Fare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          SizedBox(
            width: 150,
            child: TextFormField(
              controller: _priceController,
              readOnly: true,
              style: GoogleFonts.exo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kPrimaryColor,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_kBorderRadius),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_kBorderRadius),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_kBorderRadius),
                  borderSide: BorderSide(color: _kPrimaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixText: 'USD',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== Event Handlers ==========

  Future<void> _showDatePicker() async {
    DateTime initialDate = DateTime.now();
    if (_dateController.text.isNotEmpty) {
      try {
        final parsed = DateFormat('yyyy-MM-dd').parse(_dateController.text);
        initialDate = parsed;
      } catch (e) {
        initialDate = DateTime.now();
      }
    }

    await showDialog(
      context: context,
      builder: (context) => _CustomDatePickerDialog(
        initialDate: initialDate,
        firstDate: DateTime.now(),
        lastDate: DateTime(2101),
        onDateSelected: (date) {
          setState(() {
            _dateController.text = DateFormat('yyyy-MM-dd').format(date);
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _showTimePicker() async {
    // Intentar parsear la hora del campo de texto
    TimeOfDay initialTime = TimeOfDay.now();
    if (_timeController.text.isNotEmpty) {
      try {
        final parts = _timeController.text.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? TimeOfDay.now().hour;
          final minute = int.tryParse(parts[1]) ?? TimeOfDay.now().minute;
          initialTime = TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
        }
      } catch (e) {
        // Si hay error, usar hora actual
      }
    }

    await showDialog(
      context: context,
      builder: (context) => _CustomTimePickerDialog(
        initialTime: initialTime,
        onTimeSelected: (time) {
          setState(() {
            _timeController.text = DateFormat(
              'HH:mm',
            ).format(DateTime(2000, 1, 1, time.hour, time.minute));
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _handleCancel() {
    // Clear all form fields
    _originController.clear();
    _destinationController.clear();
    _priceController.clear();
    _distanceController.clear();
    _clientNameController.clear();
    _clientEmailController.clear();
    _clientPhoneController.clear();
    _dateController.clear();
    _timeController.clear();
    _notesController.clear();
    _cardNumberController.clear();
    _cardExpiryController.clear();
    _cardCvvController.clear();
    _cardNameController.clear();

    // Reset form state
    setState(() {
      _selectedPriority = 'normal';
      _selectedVehicleType = 'sedan';
      _selectedPaymentMethod = 'card';
      _passengerCount = 1;
      _childSeats = 0;
      _handLuggage = 0;
      _checkInLuggage = 0;
      _originCoords = null;
      _destinationCoords = null;
      _originMarker = null;
      _destinationMarker = null;
      _routePolyline = null;
      _autocompleteResults = [];
    });

    // Reset map to current location
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 13.0);
    }
  }

  Future<void> _handleCreateRide() async {
    // Validar formulario
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verificar autenticación antes de proceder
    User? firebaseUser;
    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
    } catch (e) {
      // Manejo seguro de excepciones para Flutter Web
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] ⚠️ Error obteniendo usuario: $e');
      }
      firebaseUser = null;
    }

    if (firebaseUser == null) {
      _showAuthRequiredDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse form data
      final originAddress = _originController.text.trim();
      final destinationAddress = _destinationController.text.trim();
      final price = double.tryParse(_priceController.text.trim());
      final distance = double.tryParse(_distanceController.text.trim());
      final clientName = _clientNameController.text.trim();
      final notes = _notesController.text.trim();
      final scheduledDate = _dateController.text.trim();
      final scheduledTime = _timeController.text.trim();

      // Validar precio
      if (price == null || price <= 0) {
        throw Exception('El precio debe ser mayor a cero');
      }

      // Preparar fecha programada si existe
      DateTime? scheduledDateTime;
      if (scheduledDate.isNotEmpty && scheduledTime.isNotEmpty) {
        try {
          scheduledDateTime = DateTime.parse('${scheduledDate}T$scheduledTime');
        } catch (e) {
          throw Exception('Formato de fecha u hora inválido');
        }
      }

      // Preparar datos para el servicio
      final rideData = CreateRideData(
        originAddress: originAddress,
        destinationAddress: destinationAddress,
        price: price,
        clientName: clientName,
        originCoords: _originCoords,
        destinationCoords: _destinationCoords,
        distanceKm: distance,
        priority: _selectedPriority,
        vehicleType: _selectedVehicleType,
        passengerCount: _passengerCount,
        childSeats: _childSeats,
        handLuggage: _handLuggage,
        checkInLuggage: _checkInLuggage,
        paymentMethod: _selectedPaymentMethod,
        clientEmail: _clientEmailController.text.trim().isNotEmpty
            ? _clientEmailController.text.trim()
            : null,
        clientPhone: _clientPhoneController.text.trim().isNotEmpty
            ? _clientPhoneController.text.trim()
            : null,
        notes: notes.isNotEmpty ? notes : null,
        scheduledDateTime: scheduledDateTime,
        cardNumber: _selectedPaymentMethod == 'card' ? _cardNumberController.text.trim() : null,
        cardExpiry: _selectedPaymentMethod == 'card' ? _cardExpiryController.text.trim() : null,
        cardName: _selectedPaymentMethod == 'card' ? _cardNameController.text.trim() : null,
      );

      // Crear viaje usando el servicio
      await _rideService.createRideRequest(rideData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Viaje solicitado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _handleCancel();
      }
    } catch (e) {
      // Manejo seguro de excepciones para Flutter Web
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] Error creando viaje: $e');
      }
      if (mounted) {
        final errorMessage = e is Exception
            ? e.toString().replaceAll('Exception: ', '')
            : 'Error desconocido al solicitar viaje';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar viaje: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'El número de tarjeta es requerido';
    }
    // Remove spaces and dashes
    final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.length < 13 || cleaned.length > 19) {
      return 'Número de tarjeta inválido';
    }
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Solo se permiten números';
    }
    return null;
  }

  String? _validateCardExpiry(String? value) {
    if (value == null || value.isEmpty) {
      return 'La fecha de expiración es requerida';
    }
    // Format: MM/YY
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
      return 'Formato: MM/YY';
    }
    final parts = value.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null || month < 1 || month > 12) {
      return 'Fecha inválida';
    }
    return null;
  }

  String? _validateCardCvv(String? value) {
    if (value == null || value.isEmpty) {
      return 'El CVV es requerido';
    }
    if (value.length < 3 || value.length > 4) {
      return 'CVV debe tener 3 o 4 dígitos';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Solo se permiten números';
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

// Widget personalizado de calendario
class _CustomDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime) onDateSelected;

  const _CustomDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  });

  @override
  State<_CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState extends State<_CustomDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  final List<String> _weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  final List<String> _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = month;
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    final days = <DateTime>[];

    // Agregar días vacíos al inicio
    for (int i = 1; i < firstWeekday; i++) {
      days.add(DateTime(month.year, month.month, 0 - (firstWeekday - i - 1)));
    }

    // Agregar días del mes
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    return days;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSelectable(DateTime date) {
    return date.isAfter(widget.firstDate.subtract(const Duration(days: 1))) &&
        date.isBefore(widget.lastDate.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth(_currentMonth);
    final now = DateTime.now();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius * 2)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con mes y año
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: Icon(Icons.chevron_left, color: _kPrimaryColor),
                  style: IconButton.styleFrom(
                    backgroundColor: _kPrimaryColor.withValues(alpha: 0.1),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      _months[_currentMonth.month - 1],
                      style: GoogleFonts.exo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _kTextColor,
                      ),
                    ),
                    Text(
                      '${_currentMonth.year}',
                      style: GoogleFonts.exo(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: Icon(Icons.chevron_right, color: _kPrimaryColor),
                  style: IconButton.styleFrom(
                    backgroundColor: _kPrimaryColor.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Días de la semana
            Row(
              children: _weekDays.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: GoogleFonts.exo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Calendario
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                final isCurrentMonth = date.month == _currentMonth.month;
                final isSelected = _isSameDay(date, _selectedDate);
                final isToday = _isSameDay(date, now);
                final isSelectable = _isSelectable(date);

                return GestureDetector(
                  onTap: isSelectable && isCurrentMonth
                      ? () {
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kPrimaryColor
                          : isToday
                          ? _kPrimaryColor.withValues(alpha: 0.2)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday && !isSelected
                          ? Border.all(color: _kPrimaryColor, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: GoogleFonts.exo(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: !isCurrentMonth || !isSelectable
                              ? Colors.grey.shade300
                              : isSelected
                              ? Colors.white
                              : _kTextColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kBorderRadius),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onDateSelected(_selectedDate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kBorderRadius),
                      ),
                    ),
                    child: Text(
                      'Seleccionar',
                      style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget personalizado de selector de hora
class _CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeSelected;

  const _CustomTimePickerDialog({required this.initialTime, required this.onTimeSelected});

  @override
  State<_CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<_CustomTimePickerDialog> {
  late int _selectedHour;
  late int _selectedMinute;
  bool _isAM = true;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hourOfPeriod;
    // Validar que el minuto no exceda 59
    _selectedMinute = widget.initialTime.minute.clamp(0, 59);
    _isAM = widget.initialTime.period == DayPeriod.am;
  }

  void _updateHour(int hour) {
    setState(() {
      _selectedHour = hour;
    });
  }

  void _updateMinute(int minute) {
    setState(() {
      _selectedMinute = minute;
    });
  }

  Future<void> _showNumberInputDialog(
    String label,
    int currentValue,
    int min,
    int max,
    Function(int) onChanged,
  ) async {
    final controller = TextEditingController(text: currentValue.toString());

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius * 2)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Editar $label',
                style: GoogleFonts.exo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kTextColor,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.exo(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(_kBorderRadius)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kBorderRadius),
                    borderSide: BorderSide(color: _kPrimaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_kBorderRadius),
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final value = int.tryParse(controller.text) ?? currentValue;
                        final clampedValue = value.clamp(min, max);
                        onChanged(clampedValue);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_kBorderRadius),
                        ),
                      ),
                      child: Text(
                        'Aceptar',
                        style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePeriod() {
    setState(() {
      _isAM = !_isAM;
    });
  }

  TimeOfDay _getSelectedTime() {
    int hour = _selectedHour;
    if (!_isAM && hour != 12) {
      hour += 12;
    } else if (_isAM && hour == 12) {
      hour = 0;
    }
    return TimeOfDay(hour: hour, minute: _selectedMinute);
  }

  Widget _buildNumberPicker({
    required int value,
    required int min,
    required int max,
    int step = 1,
    required Function(int) onChanged,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.exo(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón arriba
              Expanded(
                child: InkWell(
                  onTap: value < max ? () => onChanged(value + step) : null,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: value < max
                          ? _kPrimaryColor.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(_kBorderRadius),
                        topRight: Radius.circular(_kBorderRadius),
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: value < max ? _kPrimaryColor : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              // Valor (editable)
              Expanded(
                child: InkWell(
                  onTap: () => _showNumberInputDialog(label, value, min, max, onChanged),
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(
                      value.toString().padLeft(2, '0'),
                      style: GoogleFonts.exo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _kTextColor,
                      ),
                    ),
                  ),
                ),
              ),
              // Botón abajo
              Expanded(
                child: InkWell(
                  onTap: value > min ? () => onChanged(value - step) : null,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: value > min
                          ? _kPrimaryColor.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(_kBorderRadius),
                        bottomRight: Radius.circular(_kBorderRadius),
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: value > min ? _kPrimaryColor : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodButton(String label, bool isAM) {
    final isSelected = _isAM == isAM;
    return GestureDetector(
      onTap: _togglePeriod,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(_kBorderRadius),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.exo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius * 2)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Text(
              'Seleccionar hora',
              style: GoogleFonts.exo(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextColor),
            ),
            const SizedBox(height: 24),

            // Selector de hora y minutos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Horas
                _buildNumberPicker(
                  value: _selectedHour,
                  min: 1,
                  max: 12,
                  onChanged: _updateHour,
                  label: 'Hora',
                ),
                const SizedBox(width: 8),

                // Separador
                Text(
                  ':',
                  style: GoogleFonts.exo(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _kPrimaryColor,
                  ),
                ),
                const SizedBox(width: 8),

                // Minutos
                _buildNumberPicker(
                  value: _selectedMinute,
                  min: 0,
                  max: 59,
                  step: 1,
                  onChanged: _updateMinute,
                  label: 'Minuto',
                ),
                const SizedBox(width: 16),

                // AM/PM
                Column(
                  children: [
                    _buildPeriodButton('AM', true),
                    const SizedBox(height: 8),
                    _buildPeriodButton('PM', false),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Hora seleccionada
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_kBorderRadius),
              ),
              child: Text(
                _getSelectedTime().format(context),
                style: GoogleFonts.exo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _kPrimaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kBorderRadius),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onTimeSelected(_getSelectedTime()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kBorderRadius),
                      ),
                    ),
                    child: Text(
                      'Seleccionar',
                      style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom formatter for time input (HH:mm)
class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    // Si está vacío, permitir
    if (text.isEmpty) {
      return newValue;
    }

    // Remover todo excepto números y dos puntos
    final cleaned = text.replaceAll(RegExp(r'[^0-9:]'), '');

    // Limitar a 5 caracteres (HH:mm)
    if (cleaned.length > 5) {
      return oldValue;
    }

    // Si solo hay números, formatear automáticamente
    if (!cleaned.contains(':')) {
      if (cleaned.length <= 2) {
        // Solo horas
        return TextEditingValue(
          text: cleaned,
          selection: TextSelection.collapsed(offset: cleaned.length),
        );
      } else if (cleaned.length <= 4) {
        // Horas y minutos sin dos puntos
        final hours = cleaned.substring(0, 2);
        final minutes = cleaned.substring(2);
        return TextEditingValue(
          text: '$hours:$minutes',
          selection: TextSelection.collapsed(offset: '$hours:$minutes'.length),
        );
      }
    }

    // Si ya tiene dos puntos, validar formato
    if (cleaned.contains(':')) {
      final parts = cleaned.split(':');
      if (parts.length > 2) {
        // Más de un dos puntos, mantener el valor anterior
        return oldValue;
      }

      String hours = parts[0];
      String minutes = parts.length > 1 ? parts[1] : '';

      // Validar horas (00-23)
      if (hours.isNotEmpty) {
        final hourInt = int.tryParse(hours);
        if (hourInt != null) {
          if (hourInt > 23) {
            hours = '23';
          } else if (hours.length > 2) {
            hours = hours.substring(0, 2);
          }
        } else {
          hours = '';
        }
      }

      // Validar minutos (00-59)
      if (minutes.isNotEmpty) {
        final minuteInt = int.tryParse(minutes);
        if (minuteInt != null) {
          if (minuteInt > 59) {
            minutes = '59';
          } else if (minutes.length > 2) {
            minutes = minutes.substring(0, 2);
          }
        } else {
          minutes = '';
        }
      }

      final formatted = minutes.isEmpty ? hours : '$hours:$minutes';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

// Custom formatters for card input
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    // Remove all non-digits
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');

    // Add space every 4 digits
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    // Remove all non-digits
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 4 digits
    final limited = digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;

    // Format as MM/YY
    String formatted = limited;
    if (limited.length >= 2) {
      formatted = '${limited.substring(0, 2)}/${limited.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
