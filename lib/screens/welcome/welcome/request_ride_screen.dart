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
import '../../../l10n/app_localizations.dart';
import '../form/address_autocomplete_service.dart';
import '../form/ride_calculation_service.dart';
import 'welcome_screen.dart';
import 'payment_confirmation_screen.dart';

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
  final double? initialDistanceKm;
  final LatLng? initialOriginCoords;
  final LatLng? initialDestinationCoords;
  final String? initialVehicleType;

  const RequestRideScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
    this.initialDate,
    this.initialTime,
    this.initialPassengers,
    this.initialEstimatedPrice,
    this.initialDistanceKm,
    this.initialOriginCoords,
    this.initialDestinationCoords,
    this.initialVehicleType,
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

  // Form State
  String _selectedPriority = 'normal';
  String _selectedVehicleType = 'sedan';
  int _passengerCount = 1;
  int _childSeats = 0;
  int _handLuggage = 0;
  int _checkInLuggage = 0;

  // Map State
  final MapController _mapController = MapController();
  bool _isMapReady = false; // Flag para saber si el mapa está listo
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

    // Agregar listeners a los FocusNodes para geocodificar cuando pierden el foco
    _originFocusNode.addListener(() {
      if (!_originFocusNode.hasFocus && _originController.text.trim().isNotEmpty) {
        // Si el campo pierde el foco y hay texto, pero no hay coordenadas, intentar geocodificar
        if (_originCoords == null && _originController.text.trim().length >= 3) {
          _geocodeAddress(_originController.text.trim(), 'origin');
        }
      }
    });

    _destinationFocusNode.addListener(() {
      if (!_destinationFocusNode.hasFocus && _destinationController.text.trim().isNotEmpty) {
        // Si el campo pierde el foco y hay texto, pero no hay coordenadas, intentar geocodificar
        if (_destinationCoords == null && _destinationController.text.trim().length >= 3) {
          _geocodeAddress(_destinationController.text.trim(), 'destination');
        }
      }
    });

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
      // Validar que el valor esté en el rango válido (1-8)
      final passengers = widget.initialPassengers!;
      _passengerCount = passengers >= 1 && passengers <= 8 ? passengers : 1;
    }
    if (widget.initialEstimatedPrice != null) {
      _priceController.text = widget.initialEstimatedPrice!.toStringAsFixed(2);
    }
    // Inicializar distancia si viene desde WelcomeScreen
    if (widget.initialDistanceKm != null) {
      _distanceController.text = widget.initialDistanceKm!.toStringAsFixed(2);
    }

    // Inicializar tipo de vehículo si viene desde WelcomeScreen
    if (widget.initialVehicleType != null) {
      _selectedVehicleType = widget.initialVehicleType!;
    }

    // Inicializar coordenadas si vienen desde WelcomeScreen
    if (widget.initialOriginCoords != null) {
      _originCoords = widget.initialOriginCoords;
      _originMarker = Marker(
        point: _originCoords!,
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 30),
        ),
      );
      if (kDebugMode) {
        debugPrint(
          '[RequestRideScreen] ✅ Marcador de origen inicializado en initState: ${_originCoords!.latitude}, ${_originCoords!.longitude}',
        );
      }
      // Forzar actualización del estado para mostrar el marcador
      if (mounted) {
        setState(() {});
      }
    }
    if (widget.initialDestinationCoords != null) {
      _destinationCoords = widget.initialDestinationCoords;
      _destinationMarker = Marker(
        point: _destinationCoords!,
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.flag, color: Colors.white, size: 30),
        ),
      );
      if (kDebugMode) {
        debugPrint(
          '[RequestRideScreen] ✅ Marcador de destino inicializado en initState: ${_destinationCoords!.latitude}, ${_destinationCoords!.longitude}',
        );
      }
      // Forzar actualización del estado para mostrar el marcador
      if (mounted) {
        setState(() {});
      }
    }

    // Asegurar que el precio se muestre si existe
    // Pero si hay coordenadas iniciales, se recalculará en onMapReady
    if (widget.initialEstimatedPrice != null &&
        (widget.initialOriginCoords == null || widget.initialDestinationCoords == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _priceController.text.isEmpty) {
          setState(() {
            _priceController.text = widget.initialEstimatedPrice!.toStringAsFixed(2);
            if (kDebugMode) {
              debugPrint(
                '[RequestRideScreen] 💰 Precio inicial establecido: ${widget.initialEstimatedPrice}',
              );
            }
          });
        }
      });
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
              '${AppLocalizations.of(context)?.logoutError ?? 'Error al cerrar sesión'}: ${e is Exception ? e.toString() : AppLocalizations.of(context)?.requestRideUnknownError ?? 'Error desconocido'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Text(l10n?.profileComingSoon ?? 'Mi perfil (próximamente)');
          },
        ),
      ),
    );
  }

  void _showValidationErrorDialog(String errorMessage, List<String> missingFields) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius * 2)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(_kBorderRadius * 2),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(_kSpacing * 2),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de error
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Icon(Icons.error_outline, size: 40, color: Colors.red.shade600),
              ),
              const SizedBox(height: _kSpacing * 2),
              // Título
              Text(
                'Campos Requeridos',
                style: GoogleFonts.exo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _kTextColor,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _kSpacing),
              // Mensaje
              Text(
                errorMessage,
                style: GoogleFonts.exo(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              if (missingFields.isNotEmpty) ...[
                const SizedBox(height: _kSpacing),
                Container(
                  padding: const EdgeInsets.all(_kSpacing),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(_kBorderRadius),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campos faltantes:',
                        style: GoogleFonts.exo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...missingFields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.circle, size: 6, color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Text(
                                field,
                                style: GoogleFonts.exo(fontSize: 13, color: Colors.red.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: _kSpacing * 2.5),
              // Botón
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shadowColor: Colors.red.shade600.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kBorderRadius),
                    ),
                  ),
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.commonUnderstood ?? 'Entendido',
                        style: GoogleFonts.exo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius * 2)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(_kBorderRadius * 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(_kSpacing * 2),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono decorativo con gradiente
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _kPrimaryColor.withValues(alpha: 0.15),
                      _kPrimaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2), width: 2),
                ),
                child: Icon(Icons.person_add_alt_1, size: 40, color: _kPrimaryColor),
              ),
              const SizedBox(height: _kSpacing * 2),
              // Título
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n?.accountRequired ?? 'Cuenta requerida',
                    style: GoogleFonts.exo(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _kTextColor,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: _kSpacing),
              // Mensaje
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n?.accountRequiredMessage ??
                        'Necesitas iniciar sesión o crear una cuenta para solicitar viajes.',
                    style: GoogleFonts.exo(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
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
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                      ),
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(
                            l10n?.cancel ?? 'Cancelar',
                            style: GoogleFonts.exo(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: _kSpacing),
                  // Botón iniciar sesión / crear cuenta
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
                        elevation: 4,
                        shadowColor: _kPrimaryColor.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_kBorderRadius),
                        ),
                      ),
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          final text = l10n != null
                              ? (l10n.loginOrCreateAccount.isNotEmpty &&
                                        l10n.loginOrCreateAccount != 'form.loginOrCreateAccount'
                                    ? l10n.loginOrCreateAccount
                                    : 'Iniciar sesión / Crear cuenta')
                              : 'Iniciar sesión / Crear cuenta';
                          return Text(
                            text,
                            style: GoogleFonts.exo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_back, color: _kTextColor),
          ),
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
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _currentUser!.photoURL != null
                              ? NetworkImage(_currentUser!.photoURL!)
                              : null,
                          child: _currentUser!.photoURL == null
                              ? Icon(Icons.person, color: _kTextColor, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        // Nombre del usuario
                        Text(
                          _currentUser!.displayName ??
                              _currentUser!.email?.split('@').first ??
                              'Usuario',
                          style: GoogleFonts.exo(
                            color: _kTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, color: _kTextColor, size: 20),
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
                              Builder(
                                builder: (context) {
                                  final l10n = AppLocalizations.of(context);
                                  return Text(
                                    l10n?.requestRideSignOut ?? 'Cerrar sesión',
                                    style: GoogleFonts.exo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade600,
                                    ),
                                  );
                                },
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
          // Fondo gris claro (sin imágenes de fondo)
          Container(decoration: BoxDecoration(color: Colors.grey.shade100)),
          SafeArea(
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n?.requestRideRequestNewRide ?? 'Solicitar Nuevo Viaje',
                      style: GoogleFonts.exo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _kTextColor,
                        letterSpacing: -0.5,
                      ),
                    );
                  },
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
            label: AppLocalizations.of(context)?.formOriginRequired ?? 'Origen *',
            controller: _originController,
            focusNode: _originFocusNode,
            icon: Icons.location_on,
            type: 'origin',
            validator: _validateRequiredField,
          ),

          _buildAddressField(
            label: AppLocalizations.of(context)?.formDestinationRequired ?? 'Destino *',
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
                  label: AppLocalizations.of(context)?.formPassenger ?? 'Passenger',
                  value: _passengerCount.toString(),
                  items: List.generate(8, (i) => (i + 1).toString()),
                  onChanged: (val) => setState(() => _passengerCount = int.parse(val!)),
                ),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: _buildDropdownFormField(
                  label: AppLocalizations.of(context)?.formHandLuggage ?? 'Hand Luggage',
                  value: _handLuggage.toString(),
                  items: List.generate(5, (i) => i.toString()),
                  onChanged: (val) => setState(() => _handLuggage = int.parse(val!)),
                ),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: _buildDropdownFormField(
                  label: AppLocalizations.of(context)?.formCheckInLuggage ?? 'Check-in Luggage',
                  value: _checkInLuggage.toString(),
                  items: List.generate(6, (i) => i.toString()),
                  onChanged: (val) => setState(() => _checkInLuggage = int.parse(val!)),
                ),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: _buildDropdownFormField(
                  label: AppLocalizations.of(context)?.formChildSeats ?? 'Child Seats',
                  value: _childSeats.toString(),
                  items: List.generate(4, (i) => i.toString()),
                  onChanged: (val) => setState(() => _childSeats = int.parse(val!)),
                ),
              ),
            ],
          ),

          const SizedBox(height: _kSpacing * 1.5),

          // Passenger Details Section
          _buildSectionHeader('Passenger Details'),
          const SizedBox(height: _kSpacing),
          _buildTextFormField(
            label: '${AppLocalizations.of(context)?.requestRideFullName ?? 'Nombre completo'} *',
            controller: _clientNameController,
            validator: _validateRequiredField,
          ),
          _buildTextFormField(
            label: '${AppLocalizations.of(context)?.requestRideEmailAddress ?? 'Email address'} *',
            controller: _clientEmailController,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          _buildTextFormField(
            label:
                '${AppLocalizations.of(context)?.requestRideContactNumber ?? 'Contact number'} *',
            controller: _clientPhoneController,
            keyboardType: TextInputType.phone,
            validator: _validateRequiredField,
          ),

          const SizedBox(height: _kSpacing * 1.5),

          // Price & Distance Row
          Row(
            children: [
              Expanded(
                child: _buildTextFormField(
                  label: AppLocalizations.of(context)?.formDistanceKm ?? 'Distancia (km)',
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
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return _buildDatePickerField(
                      label: l10n?.requestRideTripDate ?? 'Fecha del Viaje *',
                      controller: _dateController,
                      validator: _validateRequiredDate,
                    );
                  },
                ),
              ),
              const SizedBox(width: _kSpacing),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return _buildTimePickerField(
                      label: l10n?.requestRideTripTime ?? 'Hora del Viaje *',
                      controller: _timeController,
                      validator: _validateRequiredTime,
                    );
                  },
                ),
              ),
            ],
          ),

          // Priority Dropdown
          _buildDropdownFormField(
            label: AppLocalizations.of(context)?.formPriority ?? 'Prioridad',
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

          // Fare Display Section
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return _buildSectionHeader(l10n?.requestRideTripCost ?? 'Costo del Viaje');
            },
          ),
          const SizedBox(height: _kSpacing),
          _buildFareDisplay(),

          // Action Buttons
          const SizedBox(height: _kSpacing * 1.5),
          _buildActionButtons(),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius * 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
        // Reducir altura un 10% (multiplicar por 0.9)
        final baseHeight = constraints.maxHeight > 0 ? constraints.maxHeight : 600;
        final reducedHeight = baseHeight * 0.9;
        return Container(
          height: reducedHeight,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            child: _currentLocation == null && _isLoadingLocation
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.commonGettingLocation ?? 'Obteniendo ubicación...',
                              style: const TextStyle(color: Colors.grey),
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : FlutterMap(
                    key: ValueKey(
                      'map-${_originMarker?.point}-${_destinationMarker?.point}',
                    ), // Key única para forzar reconstrucción cuando cambian los marcadores
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
                      onMapReady: () {
                        // Marcar el mapa como listo cuando se renderiza por primera vez
                        if (kDebugMode) {
                          debugPrint('[RequestRideScreen] ✅ Mapa listo para usar');
                        }
                        setState(() {
                          _isMapReady = true;
                        });
                        // Si hay coordenadas iniciales, centrar el mapa ahora que está listo
                        if (widget.initialOriginCoords != null &&
                            widget.initialDestinationCoords != null) {
                          if (kDebugMode) {
                            debugPrint(
                              '[RequestRideScreen] 🗺️ Inicializando mapa con origen y destino desde WelcomeScreen',
                            );
                          }
                          // Esperar un poco más para asegurar que el mapa esté completamente renderizado
                          Future.delayed(const Duration(milliseconds: 200), () async {
                            if (mounted) {
                              // Forzar actualización del mapa para mostrar los marcadores
                              setState(() {});
                              // Esperar un frame más para que los marcadores se rendericen
                              await Future.delayed(const Duration(milliseconds: 50));
                              if (mounted) {
                                _centerMapOnPoints();
                                await _calculateRoute();
                                await _recalculatePriceForVehicleType(forceRecalculate: true);
                                // Forzar actualización final del mapa
                                if (mounted) {
                                  setState(() {
                                    if (kDebugMode) {
                                      debugPrint(
                                        '[RequestRideScreen] ✅ Mapa actualizado con marcadores, ruta y precio',
                                      );
                                    }
                                  });
                                }
                              }
                            }
                          });
                        } else if (widget.initialOriginCoords != null ||
                            widget.initialDestinationCoords != null) {
                          // Si solo hay una coordenada, centrar el mapa cuando esté listo
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted) {
                              setState(() {});
                              _centerMapOnPoints();
                            }
                          });
                        }
                      },
                      onTap: _handleMapTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.fzkt_openstreet',
                      ),
                      // Mostrar la ruta primero (debajo de los marcadores)
                      if (_routePolyline != null) PolylineLayer(polylines: [_routePolyline!]),
                      // Mostrar los marcadores encima de la ruta
                      if (_originMarker != null) MarkerLayer(markers: [_originMarker!]),
                      if (_destinationMarker != null) MarkerLayer(markers: [_destinationMarker!]),
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
            readOnly: false, // Siempre editable
            style: GoogleFonts.exo(fontSize: 16, color: _kTextColor, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.exo(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kBorderRadius),
                borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kBorderRadius),
                borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
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
              suffixIcon: IconButton(
                icon: Icon(Icons.map, size: 20, color: _kPrimaryColor),
                tooltip:
                    AppLocalizations.of(context)?.commonSelectFromMap ?? 'Seleccionar del mapa',
                onPressed: () => _selectFromMap(type),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText:
                  AppLocalizations.of(context)?.commonWriteOrSelectAddress ??
                  'Escribe o selecciona una dirección',
              hintStyle: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade400),
            ),
            validator: validator,
            onChanged: (value) => _onAddressInputChanged(value, type),
            onEditingComplete: () {
              // Cuando el usuario presiona Enter, intentar geocodificar la dirección
              final address = controller.text.trim();
              if (address.isNotEmpty && address.length >= 3) {
                _geocodeAddress(address, type);
              }
              focusNode.unfocus();
            },
            onFieldSubmitted: (value) {
              // Cuando el usuario presiona Enter, intentar geocodificar la dirección
              final address = value.trim();
              if (address.isNotEmpty && address.length >= 3) {
                _geocodeAddress(address, type);
              }
              focusNode.unfocus();
            },
          ),
          if (_autocompleteResults.isNotEmpty && _activeInputType == type)
            Builder(
              builder: (context) {
                if (kDebugMode) {
                  debugPrint(
                    '[RequestRideScreen] Mostrando ${_autocompleteResults.length} resultados de autocompletado para $type',
                  );
                }
                return Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(_kBorderRadius),
                  child: Container(
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
                        if (kDebugMode && index == 0) {
                          debugPrint(
                            '[RequestRideScreen] Construyendo item 0: display_name="$address"',
                          );
                        }
                        return InkWell(
                          onTap: () => _selectAddressFromAutocomplete(result, type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade100,
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
                );
              },
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
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(
                  l10n?.cancel ?? 'Cancelar',
                  style: GoogleFonts.exo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                );
              },
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
            onPressed: _handleCreateRide,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 20),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n?.requestRideRequestRide ?? 'Solicitar Viaje',
                      style: GoogleFonts.exo(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
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
        style: GoogleFonts.exo(fontSize: 16, color: _kTextColor, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.exo(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: _kPrimaryColor, width: 2),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          prefixIcon: icon != null ? Icon(icon, color: _kPrimaryColor) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
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
      child: FormField<String>(
        initialValue: controller.text,
        validator: validator,
        builder: (field) {
          final hasError = field.hasError;
          // Actualizar el estado del FormField cuando cambia el controlador
          if (controller.text != field.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              field.didChange(controller.text);
            });
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  await _showDatePicker();
                  // Actualizar el FormField después de seleccionar la fecha
                  field.didChange(controller.text);
                  field.validate();
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_kBorderRadius),
                    border: Border.all(
                      color: hasError
                          ? Colors.red.shade400
                          : (selectedDate != null ? _kPrimaryColor : Colors.grey.shade400),
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
                            Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  selectedDate != null
                                      ? DateFormat('dd/MM/yyyy').format(selectedDate)
                                      : l10n?.requestRideSelectDate ?? 'Seleccionar fecha',
                                  style: GoogleFonts.exo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selectedDate != null
                                        ? _kTextColor
                                        : Colors.grey.shade400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (selectedDate != null)
                        Icon(Icons.check_circle, color: _kPrimaryColor, size: 20),
                    ],
                  ),
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 16),
                  child: Text(
                    field.errorText ?? '',
                    style: GoogleFonts.exo(fontSize: 12, color: Colors.red.shade600),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(
            color: controller.text.isNotEmpty ? _kPrimaryColor : Colors.grey.shade400,
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
                validator:
                    validator ??
                    ((value) {
                      if (value == null || value.isEmpty) {
                        return null; // Campo opcional si no hay validador
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
                    }),
              ),
            ),
            IconButton(
              icon: Icon(Icons.access_time, color: _kPrimaryColor, size: 20),
              onPressed: _showTimePicker,
              tooltip: AppLocalizations.of(context)?.requestRideSelectTime ?? 'Seleccionar hora',
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
    // Convertir items a DropdownMenuItem y extraer los valores
    final dropdownItems = items.map<DropdownMenuItem<String>>((item) {
      if (item is DropdownMenuItem<String?>) {
        return DropdownMenuItem<String>(value: item.value, child: item.child);
      } else if (item is String) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: GoogleFonts.exo(fontSize: 16, color: _kTextColor, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
      return DropdownMenuItem<String>(
        value: item.toString(),
        child: Text(
          item.toString(),
          style: GoogleFonts.exo(fontSize: 16, color: _kTextColor, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    // Extraer los valores de los items
    final itemValues = dropdownItems.map((item) => item.value).whereType<String>().toList();

    // Validar que el valor inicial exista en los items, si no, usar null
    final validValue = (value != null && itemValues.contains(value)) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: _kSpacing),
      child: DropdownButtonFormField<String>(
        key: ValueKey(
          '$label-$validValue',
        ), // Key única para forzar reconstrucción cuando el valor cambia
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.exo(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            borderSide: BorderSide(color: _kPrimaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        initialValue: validValue, // Usar 'initialValue' para establecer el valor inicial
        hint: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Text(
              l10n?.commonSelectOption ?? 'Seleccione una opción',
              style: GoogleFonts.exo(color: Colors.grey.shade600, fontSize: 16),
            );
          },
        ),
        items: dropdownItems,
        onChanged: onChanged,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: GoogleFonts.exo(fontSize: 16, color: _kTextColor, fontWeight: FontWeight.w500),
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
      {
        'type': 'business',
        'name': 'Business',
        'passengers': 6,
        'handLuggage': 2,
        'checkInLuggage': 2,
      },
      {
        'type': 'van',
        'name': 'Minivan 7pax',
        'passengers': 8,
        'handLuggage': 3,
        'checkInLuggage': 4,
      },
      {
        'type': 'luxury',
        'name': 'Minivan Luxury 6pax',
        'passengers': 6,
        'handLuggage': 2,
        'checkInLuggage': 1,
      },
      {
        'type': 'minibus_8pax',
        'name': 'Minibus 8pax',
        'passengers': 8,
        'handLuggage': 4,
        'checkInLuggage': 6,
      },
      {
        'type': 'bus_16pax',
        'name': 'Bus 16pax',
        'passengers': 16,
        'handLuggage': 8,
        'checkInLuggage': 12,
      },
      {
        'type': 'bus_19pax',
        'name': 'Bus 19pax',
        'passengers': 19,
        'handLuggage': 10,
        'checkInLuggage': 15,
      },
      {
        'type': 'bus_50pax',
        'name': 'Bus 50pax',
        'passengers': 50,
        'handLuggage': 25,
        'checkInLuggage': 30,
      },
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
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Text(
                l10n?.commonVehicle ?? 'Vehicle:-',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              );
            },
          ),
          const SizedBox(width: 12),
          // Vehicle icon placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      selectedVehicle['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 16),
                      Text('${selectedVehicle['passengers']}'),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.luggage, size: 16),
                      Text('${selectedVehicle['handLuggage']}'),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
          Flexible(
            child: Container(
              constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedVehicleType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                ),
                isExpanded: true,
                items: vehicles
                    .map(
                      (v) => DropdownMenuItem<String>(
                        value: v['type'] as String,
                        child: Text(v['name'] as String, overflow: TextOverflow.ellipsis),
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
                    // Recalcular precio cuando cambia el tipo de vehículo
                    _recalculatePriceForVehicleType(forceRecalculate: true);
                  }
                },
              ),
            ),
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
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Text(
                l10n?.commonJourneyFare ?? 'Journey Fare',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              );
            },
          ),
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

    // Reset form state
    setState(() {
      _selectedPriority = 'normal';
      _selectedVehicleType = 'sedan';
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
      // Identificar qué campos están vacíos o inválidos
      final missingFields = <String>[];

      final l10n = AppLocalizations.of(context);
      if (_originController.text.trim().isEmpty) {
        missingFields.add(l10n?.formOrigin ?? 'Origen');
      }
      if (_destinationController.text.trim().isEmpty) {
        missingFields.add(l10n?.formDestination ?? 'Destino');
      }
      if (_clientNameController.text.trim().isEmpty) {
        missingFields.add(l10n?.requestRideFullName ?? 'Nombre completo');
      }
      if (_clientEmailController.text.trim().isEmpty) {
        missingFields.add(l10n?.requestRideEmailAddress ?? 'Email address');
      }
      if (_clientPhoneController.text.trim().isEmpty) {
        missingFields.add(l10n?.requestRideContactNumber ?? 'Contact number');
      }
      if (_dateController.text.trim().isEmpty) {
        missingFields.add(l10n?.requestRideTripDate ?? 'Fecha del Viaje');
      }
      if (_timeController.text.trim().isEmpty) {
        missingFields.add(l10n?.requestRideTripTime ?? 'Hora del Viaje');
      }

      // Mostrar mensaje de error con los campos faltantes
      final errorMessage = missingFields.isEmpty
          ? 'Por favor complete todos los campos requeridos'
          : 'Por favor complete los siguientes campos: ${missingFields.join(', ')}';

      // Mostrar diálogo modal con el error
      if (mounted) {
        _showValidationErrorDialog(errorMessage, missingFields);
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Text(
                l10n?.commonPriceMustBeGreaterThanZero ?? 'El precio debe ser mayor a cero',
              );
            },
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Preparar fecha programada si existe
    DateTime? scheduledDateTime;
    if (scheduledDate.isNotEmpty && scheduledTime.isNotEmpty) {
      try {
        scheduledDateTime = DateTime.parse('${scheduledDate}T$scheduledTime');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(
                  l10n?.commonInvalidDateTimeFormat ?? 'Formato de fecha u hora inválido',
                );
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Navegar a la pantalla de confirmación de pago
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaymentConfirmationScreen(
            originAddress: originAddress,
            destinationAddress: destinationAddress,
            price: price,
            distanceKm: distance,
            clientName: clientName,
            clientEmail: _clientEmailController.text.trim().isNotEmpty
                ? _clientEmailController.text.trim()
                : null,
            clientPhone: _clientPhoneController.text.trim().isNotEmpty
                ? _clientPhoneController.text.trim()
                : null,
            originCoords: _originCoords,
            destinationCoords: _destinationCoords,
            priority: _selectedPriority,
            vehicleType: _selectedVehicleType,
            passengerCount: _passengerCount,
            childSeats: _childSeats,
            handLuggage: _handLuggage,
            checkInLuggage: _checkInLuggage,
            notes: notes.isNotEmpty ? notes : null,
            scheduledDateTime: scheduledDateTime,
          ),
        ),
      );
    }
  }

  // ========== Validation Methods ==========

  String? _validateRequiredField(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingrese un email válido';
    }
    return null;
  }

  String? _validateRequiredDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }
    return null;
  }

  String? _validateRequiredTime(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }
    // Validar formato HH:mm
    final l10n = AppLocalizations.of(context);
    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5]?[0-9])$');
    if (!timeRegex.hasMatch(value)) {
      return l10n?.requestRideInvalidFormatWithExample ?? 'Formato inválido. Use HH:mm (ej: 08:30)';
    }
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return l10n?.requestRideInvalidFormat ?? 'Formato inválido';
    }
    if (hour < 0 || hour > 23) {
      return 'La hora debe estar entre 00 y 23';
    }
    if (minute < 0 || minute > 59) {
      return 'Los minutos deben estar entre 00 y 59';
    }
    return null;
  }

  // ========== Map and Address Methods ==========

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
    if (kDebugMode) {
      debugPrint(
        '[RequestRideScreen] 📍 Actualizando marcador de origen: ${point.latitude}, ${point.longitude}',
      );
    }
    setState(() {
      _originMarker = Marker(
        point: point,
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 30),
        ),
      );
    });
    if (kDebugMode) {
      debugPrint('[RequestRideScreen] ✅ Marcador de origen creado: $_originMarker');
    }
    // Forzar actualización del mapa después de crear el marcador
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _centerMapOnPoints();
      });
    });
  }

  void _updateDestinationMarker(LatLng point) {
    if (kDebugMode) {
      debugPrint(
        '[RequestRideScreen] 🎯 Actualizando marcador de destino: ${point.latitude}, ${point.longitude}',
      );
    }
    setState(() {
      _destinationMarker = Marker(
        point: point,
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.flag, color: Colors.white, size: 30),
        ),
      );
    });
    if (kDebugMode) {
      debugPrint('[RequestRideScreen] ✅ Marcador de destino creado: $_destinationMarker');
    }
    // Forzar actualización del mapa después de crear el marcador
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _centerMapOnPoints();
      });
    });
  }

  void _centerMapOnPoints() {
    // Verificar que el mapa esté listo antes de usar el MapController
    if (!_isMapReady) {
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] ⏳ Mapa aún no está listo, esperando...');
      }
      // Reintentar después de un delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _centerMapOnPoints();
        }
      });
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[RequestRideScreen] 🗺️ Centrando mapa - Origen: $_originCoords, Destino: $_destinationCoords',
      );
    }

    try {
      if (_originCoords != null && _destinationCoords != null) {
        final centerLat = (_originCoords!.latitude + _destinationCoords!.latitude) / 2;
        final centerLon = (_originCoords!.longitude + _destinationCoords!.longitude) / 2;
        final center = LatLng(centerLat, centerLon);

        // Usar la distancia real de la ruta si está disponible, sino calcular distancia en línea recta
        double distanceInKm;
        final distanceText = _distanceController.text.trim();
        if (distanceText.isNotEmpty) {
          final parsedDistance = double.tryParse(distanceText);
          if (parsedDistance != null && parsedDistance > 0) {
            distanceInKm = parsedDistance; // Usar distancia real de la ruta
          } else {
            // Si no hay distancia válida, calcular en línea recta
            const distance = Distance();
            distanceInKm = distance.as(LengthUnit.Kilometer, _originCoords!, _destinationCoords!);
          }
        } else {
          // Si no hay distancia en el controlador, calcular en línea recta
          const distance = Distance();
          distanceInKm = distance.as(LengthUnit.Kilometer, _originCoords!, _destinationCoords!);
        }

        // Calcular zoom para asegurar que ambos marcadores sean visibles con margen
        // Usar la distancia real de la ruta para un zoom más preciso
        double zoom;
        if (distanceInKm < 1) {
          zoom = 15.0;
        } else if (distanceInKm < 5) {
          zoom = 13.0;
        } else if (distanceInKm < 20) {
          zoom = 11.0;
        } else if (distanceInKm < 50) {
          zoom = 9.0;
        } else if (distanceInKm < 100) {
          zoom = 10.5; // Zoom más cercano para rutas de 50-100 km (Syracuse-Catania ~65 km)
        } else {
          zoom = 9.0; // Zoom para distancias > 100 km
        }

        if (kDebugMode) {
          debugPrint(
            '[RequestRideScreen] 🗺️ Moviendo mapa a centro: $center, zoom: $zoom (distancia: ${distanceInKm.toStringAsFixed(2)} km)',
          );
        }
        _mapController.move(center, zoom);
      } else if (_originCoords != null) {
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] 🗺️ Moviendo mapa a origen: $_originCoords');
        }
        _mapController.move(_originCoords!, 15.0);
      } else if (_destinationCoords != null) {
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] 🗺️ Moviendo mapa a destino: $_destinationCoords');
        }
        _mapController.move(_destinationCoords!, 15.0);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] ❌ Error moviendo mapa: $e');
      }
      // Si hay error, el mapa aún no está listo, reintentar
      _isMapReady = false;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _centerMapOnPoints();
        }
      });
    }
  }

  Future<void> _onAddressInputChanged(String query, String type) async {
    _debounceTimer?.cancel();

    // Activar automáticamente el campo cuando el usuario escribe
    if (_activeInputType != type) {
      setState(() {
        _activeInputType = type;
      });
    }

    if (query.length < 2) {
      setState(() {
        _autocompleteResults = [];
      });
      return;
    }

    if (kDebugMode) {
      debugPrint('[RequestRideScreen] Buscando direcciones para: "$query" (type: $type)');
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _searchAddresses(query);
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] Resultados recibidos: ${results.length}');
        }
        if (mounted && _activeInputType == type) {
          setState(() {
            _autocompleteResults = results;
          });
          if (kDebugMode) {
            debugPrint(
              '[RequestRideScreen] Autocompletado actualizado: ${results.length} resultados',
            );
          }
        } else if (kDebugMode) {
          debugPrint(
            '[RequestRideScreen] No actualizando: mounted=$mounted, activeInputType=$_activeInputType, type=$type',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] Error buscando direcciones: $e');
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
      // Usar el servicio de autocompletado con fallback
      final results = await AddressAutocompleteService.searchAddresses(query);
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] Resultados encontrados: ${results.length}');
      }
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] Error en búsqueda de direcciones: $e');
      }
      return [];
    }
  }

  void _selectAddressFromAutocomplete(Map<String, dynamic> result, String type) {
    final address = result['display_name'] as String? ?? '';

    // Extraer coordenadas de forma segura (pueden venir como double, num, o String)
    final latValue = result['lat'];
    final lonValue = result['lon'];

    double? lat;
    double? lon;

    if (latValue is double) {
      lat = latValue;
    } else if (latValue is num) {
      lat = latValue.toDouble();
    } else if (latValue is String) {
      lat = double.tryParse(latValue);
    }

    if (lonValue is double) {
      lon = lonValue;
    } else if (lonValue is num) {
      lon = lonValue.toDouble();
    } else if (lonValue is String) {
      lon = double.tryParse(lonValue);
    }

    if (lat == null || lon == null) {
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] ⚠️ Coordenadas inválidas: lat=$latValue, lon=$lonValue');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[RequestRideScreen] ✅ Seleccionando dirección: $address');
      debugPrint('[RequestRideScreen] Coordenadas: lat=$lat, lon=$lon');
    }

    final point = LatLng(lat, lon);

    // Obtener el texto actual del usuario antes de reemplazarlo
    final currentText = type == 'origin' ? _originController.text : _destinationController.text;

    // Si el usuario escribió una dirección más completa o detallada que el display_name,
    // mantener su texto original. Esto preserva el formato que el usuario escribió.
    final userTextLower = currentText.toLowerCase().trim();
    final displayNameLower = address.toLowerCase().trim();

    // Comparar si el texto del usuario contiene información más específica
    // Si el texto del usuario es significativamente más largo o contiene más detalles,
    // mantenerlo. De lo contrario, usar el display_name de la API.
    bool shouldKeepUserText = false;

    if (userTextLower.length > displayNameLower.length * 1.2) {
      // El texto del usuario es significativamente más largo
      shouldKeepUserText = true;
    } else if (userTextLower.length > 30 &&
        displayNameLower.contains(userTextLower.substring(0, 20))) {
      // El texto del usuario es largo y el display_name contiene el inicio del texto del usuario
      shouldKeepUserText = true;
    } else if (userTextLower.split(' ').length > displayNameLower.split(' ').length + 2) {
      // El texto del usuario tiene significativamente más palabras
      shouldKeepUserText = true;
    }

    final finalAddress = shouldKeepUserText ? currentText : address;

    if (type == 'origin') {
      _originController.text = finalAddress;
      _originCoords = point;
      _updateOriginMarker(point);
      if (kDebugMode) {
        debugPrint(
          '[RequestRideScreen] ✅ Origen actualizado: ${_originCoords?.latitude}, ${_originCoords?.longitude}',
        );
      }
    } else {
      _destinationController.text = finalAddress;
      _destinationCoords = point;
      _updateDestinationMarker(point);
      if (kDebugMode) {
        debugPrint(
          '[RequestRideScreen] ✅ Destino actualizado: ${_destinationCoords?.latitude}, ${_destinationCoords?.longitude}',
        );
      }
    }

    setState(() {
      _autocompleteResults = [];
      _activeInputType = null; // Cerrar el modo de edición después de seleccionar
    });

    // Forzar actualización del mapa después de actualizar los marcadores
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Actualizar el mapa para mostrar los marcadores
      if (_originCoords != null || _destinationCoords != null) {
        _centerMapOnPoints();
      }

      // Calcular ruta si ambos puntos están establecidos
      if (_originCoords != null && _destinationCoords != null) {
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] 🗺️ Calculando ruta entre origen y destino...');
        }
        _calculateRoute();
      } else if (kDebugMode) {
        debugPrint(
          '[RequestRideScreen] ⏳ Esperando ${type == 'origin' ? 'destino' : 'origen'} para calcular ruta',
        );
      }
    });
  }

  Future<void> _geocodeAddress(String address, String type) async {
    if (address.trim().length < 3) return;

    if (kDebugMode) {
      debugPrint('[RequestRideScreen] 🔍 Geocodificando dirección: "$address" (type: $type)');
    }

    try {
      // Usar el servicio de autocompletado para buscar la dirección
      final results = await AddressAutocompleteService.searchAddresses(address);

      if (results.isNotEmpty) {
        // Tomar el primer resultado (el más relevante)
        final result = results[0];
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] ✅ Dirección geocodificada: ${result['display_name']}');
        }
        // Seleccionar automáticamente el primer resultado
        _selectAddressFromAutocomplete(result, type);
      } else {
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] ⚠️ No se encontraron resultados para: "$address"');
        }
        // Mostrar mensaje al usuario
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n != null
                        ? l10n.commonAddressNotFoundWithAddress(address)
                        : 'No se pudo encontrar la dirección: $address',
                  );
                },
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] ❌ Error geocodificando dirección: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(
                  l10n != null
                      ? l10n.commonErrorSearchingAddress(e.toString())
                      : 'Error al buscar la dirección: $e',
                );
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
    if (_originCoords == null || _destinationCoords == null) {
      if (kDebugMode) {
        debugPrint(
          '[RequestRideScreen] ⚠️ No se puede calcular ruta: origen=$_originCoords, destino=$_destinationCoords',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[RequestRideScreen] 🗺️ Calculando ruta desde ${_originCoords!.latitude},${_originCoords!.longitude} hasta ${_destinationCoords!.latitude},${_destinationCoords!.longitude}',
      );
    }

    try {
      // Calcular distancia directa
      final distance = const Distance();
      final distanceInKm = distance.as(LengthUnit.Kilometer, _originCoords!, _destinationCoords!);
      _distanceController.text = distanceInKm.toStringAsFixed(2);

      if (kDebugMode) {
        debugPrint(
          '[RequestRideScreen] 📏 Distancia directa: ${distanceInKm.toStringAsFixed(2)} km',
        );
      }

      // Intentar obtener ruta real usando OSRM
      try {
        final response = await http
            .get(
              Uri.parse(
                'https://router.project-osrm.org/route/v1/driving/'
                '${_originCoords!.longitude},${_originCoords!.latitude};'
                '${_destinationCoords!.longitude},${_destinationCoords!.latitude}?'
                'overview=full&geometries=geojson',
              ),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes[0] as Map<String, dynamic>;
            final geometry = route['geometry'] as Map<String, dynamic>?;
            final coordinates = geometry?['coordinates'] as List<dynamic>?;

            if (coordinates != null && coordinates.isNotEmpty) {
              final points = coordinates.map((coord) {
                final coordList = coord as List<dynamic>;
                return LatLng(coordList[1] as double, coordList[0] as double);
              }).toList();

              // Actualizar distancia con la ruta real
              final distanceInMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
              final distanceInKmReal = distanceInMeters / 1000.0;
              _distanceController.text = distanceInKmReal.toStringAsFixed(2);

              setState(() {
                _routePolyline = Polyline(points: points, strokeWidth: 4.0, color: Colors.blue);
              });

              // Recalcular precio usando rutas predefinidas
              _recalculatePriceForVehicleType(forceRecalculate: true);
              _centerMapOnPoints();
              return;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[RequestRideScreen] Error obteniendo ruta OSRM: $e');
        }
      }

      // Fallback: línea recta si OSRM falla
      // Calcular distancia en línea recta
      const distanceCalculator = Distance();
      final distanceInKmStraight = distanceCalculator.as(
        LengthUnit.Kilometer,
        _originCoords!,
        _destinationCoords!,
      );
      _distanceController.text = distanceInKmStraight.toStringAsFixed(2);

      setState(() {
        _routePolyline = Polyline(
          points: [_originCoords!, _destinationCoords!],
          strokeWidth: 3.0,
          color: Colors.blue,
        );
      });

      // Recalcular precio usando rutas predefinidas (siempre recalcular para asegurar que se muestre)
      await _recalculatePriceForVehicleType(forceRecalculate: true);
      _centerMapOnPoints();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculando ruta: $e');
      }
    }
  }

  /// Recalcula el precio basado en la distancia y el tipo de vehículo
  Future<void> _recalculatePriceForVehicleType({bool forceRecalculate = false}) async {
    if (_originCoords == null || _destinationCoords == null) {
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] ⚠️ No se puede calcular precio: origen o destino faltante');
      }
      return;
    }

    // Si hay precio inicial y no se fuerza recalcular, mantenerlo (pero asegurar que se muestre)
    if (widget.initialEstimatedPrice != null && !forceRecalculate) {
      if (_priceController.text.isEmpty) {
        setState(() {
          _priceController.text = widget.initialEstimatedPrice!.toStringAsFixed(2);
        });
      }
      return;
    }

    // Usar RideCalculationService que incluye rutas predefinidas y lugares con precio fijo
    final price = await RideCalculationService.calculatePriceWithFixedPlaces(
      _originCoords,
      _destinationCoords,
      vehicleType: _selectedVehicleType,
    );

    if (price != null) {
      if (kDebugMode) {
        debugPrint('[RequestRideScreen] 💰 Precio calculado: $price para $_selectedVehicleType');
      }
      setState(() {
        _priceController.text = price.toStringAsFixed(2);
      });
    } else {
      // Fallback: calcular basado en distancia si no hay precio predefinido
      final distanceText = _distanceController.text;
      if (distanceText.isNotEmpty) {
        final distanceInKm = double.tryParse(distanceText) ?? 0.0;
        if (distanceInKm > 0) {
          // Precios base por tipo de vehículo (por km) - solo como fallback
          final vehiclePrices = {
            'sedan': 0.5,
            'business': 0.7,
            'van': 0.9,
            'luxury': 1.2,
            'minibus_8pax': 1.0,
            'bus_16pax': 1.5,
            'bus_19pax': 1.8,
            'bus_50pax': 2.5,
          };

          final pricePerKm = vehiclePrices[_selectedVehicleType] ?? 0.5;
          final calculatedPrice = distanceInKm * pricePerKm;

          // Precio mínimo según tipo de vehículo
          final minPrices = {
            'sedan': 2.0,
            'business': 3.0,
            'van': 4.0,
            'luxury': 5.0,
            'minibus_8pax': 6.0,
            'bus_16pax': 10.0,
            'bus_19pax': 12.0,
            'bus_50pax': 15.0,
          };

          final minPrice = minPrices[_selectedVehicleType] ?? 2.0;
          final finalPrice = calculatedPrice < minPrice ? minPrice : calculatedPrice;

          setState(() {
            _priceController.text = finalPrice.toStringAsFixed(2);
          });
        }
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
