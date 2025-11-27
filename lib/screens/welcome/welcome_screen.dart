import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../auth/login_screen.dart';
import 'request_ride_screen.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla pública de bienvenida con carrusel de vehículos
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _carouselController = PageController();
  int _currentCarIndex = 0;
  Timer? _carouselTimer;

  // Estado del usuario
  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  // Controllers para campos de ubicación
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropoffFocusNode = FocusNode();

  // Estado para autocompletado
  List<Map<String, dynamic>> _autocompleteResults = [];
  String? _activeInputType; // 'pickup' o 'dropoff'
  Timer? _debounceTimer;

  // Estado para fecha, hora y pasajeros
  DateTime? _pickupDate;
  final TextEditingController _timeController = TextEditingController();
  int _passengers = 1;
  static const int _maxPassengers = 35;

  // Coordenadas y cálculo de ruta
  LatLng? _originCoords;
  LatLng? _destinationCoords;
  double? _distanceKm;
  double? _estimatedPrice;

  // Lista de vehículos con sus imágenes
  final List<Map<String, dynamic>> _vehicles = [
    {
      'name': 'Sedan',
      'image': 'assets/images/cars/sedan.jpg',
      'passengers': 3,
      'luggage': 1,
      'description': 'Comfortable y económico',
    },
    {
      'name': 'Económica',
      'image': 'assets/images/cars/economica.jpg',
      'passengers': 3,
      'luggage': 1,
      'description': 'Opción económica y práctica',
    },
    {
      'name': 'SUV',
      'image': 'assets/images/cars/suv.jpg',
      'passengers': 6,
      'luggage': 2,
      'description': 'Espacioso para grupos',
    },
    {
      'name': 'Van',
      'image': 'assets/images/cars/van.jpg',
      'passengers': 8,
      'luggage': 4,
      'description': 'Ideal para grupos grandes',
    },
    {
      'name': 'Luxury',
      'image': 'assets/images/cars/luxury.jpg',
      'passengers': 3,
      'luggage': 2,
      'description': 'Máximo confort y elegancia',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Verificar usuario actual
    _currentUser = FirebaseAuth.instance.currentUser;

    // Escuchar cambios de autenticación
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });

    // Iniciar el carrusel automático después de que el widget esté construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCarouselTimer();
    });
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_carouselController.hasClients) return;

      if (_currentCarIndex < _vehicles.length - 1) {
        _currentCarIndex++;
      } else {
        _currentCarIndex = 0;
      }

      _carouselController.animateToPage(
        _currentCarIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _debounceTimer?.cancel();
    _authSubscription?.cancel();
    _carouselController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _timeController.dispose();
    _pickupFocusNode.dispose();
    _dropoffFocusNode.dispose();
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

  void _navigateToProfile() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mi perfil (próximamente)')));
  }

  void _navigateToRequestRide() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Si no está autenticado, mostrar diálogo
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius * 2)),
          child: Container(
            padding: const EdgeInsets.all(_kSpacing * 2),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono decorativo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _kPrimaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_alt_1, size: 40, color: _kPrimaryColor),
                ),
                const SizedBox(height: _kSpacing * 2),

                // Título
                Text(
                  'Cuenta requerida',
                  style: GoogleFonts.exo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _kTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _kSpacing),

                // Mensaje
                Text(
                  'Necesitas crear una cuenta para solicitar viajes. ¿Deseas crear una cuenta ahora?',
                  style: GoogleFonts.exo(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _kSpacing * 2.5),

                // Botones
                Row(
                  children: [
                    // Botón cancelar
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
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
                    const SizedBox(width: _kSpacing),
                    // Botón crear cuenta
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _navigateToLogin();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_kBorderRadius),
                          ),
                        ),
                        child: Text(
                          'Crear cuenta',
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
    } else {
      // Si está autenticado, ir directamente a solicitar viaje
      // Pasar los valores de origen, destino, fecha, hora, pasajeros y precio estimado si existen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RequestRideScreen(
            initialOrigin: _pickupController.text.trim().isNotEmpty
                ? _pickupController.text.trim()
                : null,
            initialDestination: _dropoffController.text.trim().isNotEmpty
                ? _dropoffController.text.trim()
                : null,
            initialDate: _pickupDate,
            initialTime: _parseTimeFromText(_timeController.text),
            initialPassengers: _passengers,
            initialEstimatedPrice: _estimatedPrice,
          ),
          settings: const RouteSettings(name: '/request-ride'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kPrimaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'cuzcatlansv.ride',
          style: GoogleFonts.exo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
            : [
                // Botones de login/registro si no está autenticado
                TextButton(
                  onPressed: _navigateToLogin,
                  child: Text(
                    'Regístrate',
                    style: GoogleFonts.exo(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _navigateToLogin,
                  child: Text(
                    'Iniciar sesión',
                    style: GoogleFonts.exo(
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, _kPrimaryColor.withValues(alpha: 0.05)],
          ),
        ),
        child: SafeArea(child: isTablet ? _buildWideLayout() : _buildNarrowLayout()),
      ),
    );
  }

  Widget _buildWideLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección informativa arriba de los contenedores
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: _kSpacing * 0.5,
                bottom: _kSpacing,
                left: _kSpacing * 2,
                right: _kSpacing * 2,
              ),
              child: _buildBottomSection(),
            ),
            const SizedBox(height: _kSpacing * 2),
            // Fila con 2 contenedores: Izquierda (formulario) y Derecha (carrusel)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contenedor 1: Izquierda - Formulario
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(_kSpacing * 2),
                    child: _buildFormSection(),
                  ),
                ),
                const SizedBox(width: _kSpacing * 2),
                // Contenedor 2: Derecha - Carrusel
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(_kSpacing * 2),
                    child: SizedBox(height: 500, child: _buildCarouselSection()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campos de ubicación
        _buildLocationField(
          label: 'Pickup location',
          controller: _pickupController,
          focusNode: _pickupFocusNode,
          isPickup: true,
        ),
        const SizedBox(height: _kSpacing),
        _buildLocationField(
          label: 'Dropoff location',
          controller: _dropoffController,
          focusNode: _dropoffFocusNode,
          isPickup: false,
        ),
        const SizedBox(height: _kSpacing * 2),

        // Campos de fecha, hora y pasajeros
        Row(
          children: [
            // Fecha de recogida
            Expanded(child: _buildDateField()),
            const SizedBox(width: _kSpacing),
            // Hora de recogida
            Expanded(child: _buildTimeField()),
          ],
        ),
        const SizedBox(height: _kSpacing),
        // Número de pasajeros
        _buildPassengersField(),
        const SizedBox(height: _kSpacing * 2),

        // Campos de distancia y precio (si están disponibles)
        if (_distanceKm != null || _estimatedPrice != null) ...[
          Row(
            children: [
              if (_distanceKm != null)
                Expanded(
                  child: _buildInfoField(
                    label: 'Distancia',
                    value: '${_distanceKm!.toStringAsFixed(2)} km',
                    icon: Icons.straighten,
                  ),
                ),
              if (_distanceKm != null && _estimatedPrice != null) const SizedBox(width: _kSpacing),
              if (_estimatedPrice != null)
                Expanded(
                  child: _buildInfoField(
                    label: 'Precio estimado',
                    value: '\$${_estimatedPrice!.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                  ),
                ),
            ],
          ),
          const SizedBox(height: _kSpacing * 2),
        ],

        // Botón See prices
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _navigateToRequestRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTextColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius)),
            ),
            child: const Text(
              'See prices',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Title - a todo el ancho, más arriba
        SizedBox(
          width: double.infinity,
          child: Text(
            'Tu viaje perfecto comienza aquí',
            style: GoogleFonts.exo(
              fontSize: isTablet ? 48 : 36,
              fontWeight: FontWeight.bold,
              color: _kTextColor,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: _kSpacing * 2),

        // Description - centrado
        SizedBox(
          width: double.infinity,
          child: Text(
            'Solicita tu viaje de manera rápida y segura. '
            'Disponible 24/7 para llevarte a donde necesites.',
            style: GoogleFonts.exo(
              fontSize: isTablet ? 18 : 16,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: _kSpacing * 2),

        // Features - en fila horizontal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _buildFeatureItem(Icons.check_circle, 'Reserva rápida y fácil')),
            const SizedBox(width: _kSpacing),
            Expanded(child: _buildFeatureItem(Icons.shield, 'Conductores verificados')),
            const SizedBox(width: _kSpacing),
            Expanded(child: _buildFeatureItem(Icons.payment, 'Múltiples métodos de pago')),
          ],
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección informativa arriba
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(_kSpacing * 2),
              child: _buildBottomSection(),
            ),
            const SizedBox(height: _kSpacing * 3),
            // Campos de ubicación
            _buildLocationField(
              label: 'Pickup location',
              controller: _pickupController,
              focusNode: _pickupFocusNode,
              isPickup: true,
            ),
            const SizedBox(height: _kSpacing),
            _buildLocationField(
              label: 'Dropoff location',
              controller: _dropoffController,
              focusNode: _dropoffFocusNode,
              isPickup: false,
            ),
            const SizedBox(height: _kSpacing * 2),

            // Campos de fecha, hora y pasajeros
            Row(
              children: [
                // Fecha de recogida
                Expanded(child: _buildDateField()),
                const SizedBox(width: _kSpacing),
                // Hora de recogida
                Expanded(child: _buildTimeField()),
              ],
            ),
            const SizedBox(height: _kSpacing),
            // Número de pasajeros
            _buildPassengersField(),
            const SizedBox(height: _kSpacing * 2),

            // Campos de distancia y precio (si están disponibles)
            if (_distanceKm != null || _estimatedPrice != null) ...[
              Row(
                children: [
                  if (_distanceKm != null)
                    Expanded(
                      child: _buildInfoField(
                        label: 'Distancia',
                        value: '${_distanceKm!.toStringAsFixed(2)} km',
                        icon: Icons.straighten,
                      ),
                    ),
                  if (_distanceKm != null && _estimatedPrice != null)
                    const SizedBox(width: _kSpacing),
                  if (_estimatedPrice != null)
                    Expanded(
                      child: _buildInfoField(
                        label: 'Precio estimado',
                        value: '\$${_estimatedPrice!.toStringAsFixed(2)}',
                        icon: Icons.attach_money,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: _kSpacing * 2),
            ],

            // Botón See prices
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToRequestRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTextColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kBorderRadius),
                  ),
                ),
                child: const Text(
                  'See prices',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: _kSpacing * 2),
            SizedBox(height: 350, child: _buildCarouselSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isPickup,
  }) {
    final fieldType = isPickup ? 'pickup' : 'dropoff';
    final isActive = _activeInputType == fieldType;

    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            readOnly: !isActive,
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
                child: Icon(
                  isPickup ? Icons.location_on : Icons.flag,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: isPickup ? '¿Dónde te recogemos?' : '¿A dónde vas?',
              hintStyle: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade400),
            ),
            onTap: () {
              setState(() {
                _activeInputType = fieldType;
              });
              focusNode.requestFocus();
            },
            onChanged: isActive ? (value) => _onAddressInputChanged(value, fieldType) : null,
          ),
          // Lista de resultados de autocompletado
          if (_autocompleteResults.isNotEmpty && isActive)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(_kBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
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
                  return _buildAutocompleteItem(result, fieldType);
                },
              ),
            ),
        ],
      ),
    );
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

  Widget _buildAutocompleteItem(Map<String, dynamic> result, String type) {
    final displayName = result['display_name'] as String;

    return InkWell(
      onTap: () => _selectAddressFromAutocomplete(result, type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.location_on, color: _kPrimaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: GoogleFonts.exo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kTextColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAddressFromAutocomplete(Map<String, dynamic> result, String type) {
    final address = result['display_name'] as String;
    final lat = result['lat'] as double;
    final lon = result['lon'] as double;

    if (type == 'pickup') {
      _pickupController.text = address;
      _pickupFocusNode.unfocus();
      if (lat != 0.0 && lon != 0.0) {
        _originCoords = LatLng(lat, lon);
      }
    } else {
      _dropoffController.text = address;
      _dropoffFocusNode.unfocus();
      if (lat != 0.0 && lon != 0.0) {
        _destinationCoords = LatLng(lat, lon);
      }
    }

    setState(() {
      _autocompleteResults = [];
      _activeInputType = null;
    });

    // Calcular distancia y precio si ambas coordenadas están disponibles
    if (_originCoords != null && _destinationCoords != null) {
      _calculateDistanceAndPrice();
    }
  }

  void _calculateDistanceAndPrice() {
    if (_originCoords == null || _destinationCoords == null) return;

    try {
      final distance = const Distance();
      final distanceInKm = distance.as(LengthUnit.Kilometer, _originCoords!, _destinationCoords!);

      // Calcular precio estimado (ejemplo: $0.50 por km)
      final estimatedPrice = distanceInKm * 0.5;

      setState(() {
        _distanceKm = distanceInKm;
        _estimatedPrice = estimatedPrice;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculando distancia: $e');
      }
    }
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _kPrimaryColor, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.exo(fontSize: 14, color: _kTextColor, fontWeight: FontWeight.w500),
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Método para construir el campo de fecha
  Widget _buildDateField() {
    final dateText = _pickupDate != null
        ? DateFormat('EEE, d MMM, yyyy', 'es').format(_pickupDate!)
        : 'Pickup date';

    return GestureDetector(
      onTap: _selectPickupDate,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(
            color: _pickupDate != null ? _kPrimaryColor.withValues(alpha: 0.3) : Colors.transparent,
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
                    'Pickup date',
                    style: GoogleFonts.exo(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateText,
                    style: GoogleFonts.exo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _pickupDate != null ? _kTextColor : Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_pickupDate != null) Icon(Icons.check_circle, color: _kPrimaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  // Método para construir el campo de hora (editable)
  Widget _buildTimeField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(
          color: _timeController.text.isNotEmpty
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
              controller: _timeController,
              style: GoogleFonts.exo(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextColor),
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
            ),
          ),
          IconButton(
            icon: Icon(Icons.access_time, color: _kPrimaryColor, size: 20),
            onPressed: _selectPickupTime,
            tooltip: 'Seleccionar hora',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // Método para construir el selector de pasajeros
  Widget _buildPassengersField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(
          color: _passengers > 0 ? _kPrimaryColor.withValues(alpha: 0.3) : Colors.transparent,
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
            child: Icon(Icons.people, color: _kPrimaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Passengers',
                style: GoogleFonts.exo(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$_passengers ${_passengers == 1 ? 'pasajero' : 'pasajeros'}',
                style: GoogleFonts.exo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kTextColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Botón menos
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _passengers > 1 ? () => setState(() => _passengers--) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _passengers > 1
                      ? _kPrimaryColor.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _passengers > 1
                        ? _kPrimaryColor.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.remove,
                  color: _passengers > 1 ? _kPrimaryColor : Colors.grey.shade400,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Número de pasajeros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_passengers',
              style: GoogleFonts.exo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kPrimaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Botón más
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _passengers < _maxPassengers ? () => setState(() => _passengers++) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _passengers < _maxPassengers
                      ? _kPrimaryColor.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _passengers < _maxPassengers
                        ? _kPrimaryColor.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  color: _passengers < _maxPassengers ? _kPrimaryColor : Colors.grey.shade400,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para seleccionar la fecha - Calendario personalizado
  Future<void> _selectPickupDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _pickupDate ?? now;

    await showDialog(
      context: context,
      builder: (context) => _CustomDatePickerDialog(
        initialDate: initialDate,
        firstDate: now,
        lastDate: DateTime.now().add(const Duration(days: 365)),
        onDateSelected: (date) {
          setState(() {
            _pickupDate = date;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // Método para seleccionar la hora - Selector personalizado
  Future<void> _selectPickupTime() async {
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
            // Actualizar el TextEditingController
            _timeController.text = DateFormat(
              'HH:mm',
            ).format(DateTime(2000, 1, 1, time.hour, time.minute));
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildCarouselSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Container(
      margin: EdgeInsets.all(isTablet ? 24.0 : 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kBorderRadius * 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kBorderRadius * 2),
        child: Column(
          children: [
            // Carousel con flechas de navegación
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _carouselController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentCarIndex = index;
                      });
                      // Reiniciar el timer cuando el usuario cambia manualmente
                      _startCarouselTimer();
                    },
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      return _buildCarItem(vehicle);
                    },
                  ),
                  // Flecha izquierda
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildNavigationArrow(
                        icon: Icons.chevron_left,
                        onPressed: _previousPage,
                        isLeft: true,
                      ),
                    ),
                  ),
                  // Flecha derecha
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildNavigationArrow(
                        icon: Icons.chevron_right,
                        onPressed: _nextPage,
                        isLeft: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Indicators
            Container(
              padding: const EdgeInsets.all(_kSpacing),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(_kBorderRadius * 2),
                  bottomRight: Radius.circular(_kBorderRadius * 2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _vehicles.length,
                  (index) => _buildIndicator(index == _currentCarIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousPage() {
    if (!_carouselController.hasClients) return;

    if (_currentCarIndex > 0) {
      _carouselController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Si está en la primera página, ir a la última
      _carouselController.animateToPage(
        _vehicles.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _startCarouselTimer();
  }

  void _nextPage() {
    if (!_carouselController.hasClients) return;

    if (_currentCarIndex < _vehicles.length - 1) {
      _carouselController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Si está en la última página, ir a la primera
      _carouselController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _startCarouselTimer();
  }

  Widget _buildNavigationArrow({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isLeft,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(icon, color: _kPrimaryColor, size: 28),
        ),
      ),
    );
  }

  Widget _buildCarItem(Map<String, dynamic> vehicle) {
    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Vehicle Image - Ampliada sin fondo
          Center(
            child: Transform.scale(
              scale: 0.8,
              child: Image.asset(
                vehicle['image'] as String,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Si la imagen no existe, mostrar placeholder
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car, size: 120, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          vehicle['name'] as String,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Vehicle Info Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(_kSpacing * 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle['name'] as String,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vehicle['description'] as String,
                    style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(Icons.people, '${vehicle['passengers']} Pasajeros'),
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.luggage, '${vehicle['luggage']} Equipajes'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? _kPrimaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Método para construir campo de información (distancia/precio)
  Widget _buildInfoField({required String label, required String value, required IconData icon}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.3), width: 1.5),
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
            child: Icon(icon, color: _kPrimaryColor, size: 20),
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
                  value,
                  style: GoogleFonts.exo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método para parsear tiempo desde texto HH:mm
  TimeOfDay? _parseTimeFromText(String text) {
    if (text.isEmpty) return null;
    try {
      final parts = text.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    } catch (e) {
      // Si hay error, retornar null
    }
    return null;
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
    _selectedMinute = widget.initialTime.minute > 59 ? 59 : widget.initialTime.minute;
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
