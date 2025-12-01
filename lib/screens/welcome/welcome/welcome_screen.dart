import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../auth/login_screen.dart';
import '../../../widgets/app_logo_header.dart';
import '../../../l10n/app_localizations.dart';
import 'request_ride_screen.dart';
import '../navbar/welcome_navbar.dart';
import '../form/welcome_form_section.dart';
import '../form/address_autocomplete_service.dart';
import '../form/ride_calculation_service.dart';
import '../carousel/vehicle/vehicle_carousel.dart';
import '../carousel/vehicle/vehicle_data.dart';
import '../carousel/background/background_carousel.dart';
import 'widgets/welcome_footer.dart';
import 'company_screen.dart';
import 'destinations_screen.dart';
import 'contacts_screen.dart';

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
  // Carrusel de imágenes de fondo

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

  // Tipo de vehículo seleccionado
  String _selectedVehicleType = 'sedan'; // sedan, business, van, luxury

  // Estado de carga para geocodificación
  bool _isGeocoding = false;

  // Lista de vehículos - ahora se obtiene de VehicleData
  List<Map<String, dynamic>> get _vehicles => VehicleData.vehicles;

  @override
  void initState() {
    super.initState();
    // Verificar usuario actual de forma segura
    // Primero verificar si Firebase está inicializado de forma segura
    bool firebaseInitialized = false;
    try {
      firebaseInitialized = Firebase.apps.isNotEmpty;
    } catch (e) {
      // Si hay error al verificar Firebase, asumir que no está inicializado
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Error verificando Firebase: $e');
      }
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint(
          '[WelcomeScreen] ⚠️ Firebase no inicializado: no se puede acceder a FirebaseAuth',
        );
      }
      _currentUser = null;
      return;
    }

    try {
      _currentUser = FirebaseAuth.instance.currentUser;

      // Escuchar cambios de autenticación
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (User? user) {
          if (mounted) {
            setState(() {
              _currentUser = user;
            });
          }
        },
        onError: (error) {
          // Manejo seguro de errores en el stream para Flutter Web
          if (kDebugMode) {
            debugPrint('[WelcomeScreen] ⚠️ Error en authStateChanges: $error');
          }
          if (mounted) {
            setState(() {
              _currentUser = null;
            });
          }
        },
      );
    } catch (e, stackTrace) {
      // Si Firebase no está inicializado, continuar sin usuario
      // Manejo seguro de excepciones para Flutter Web
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Firebase no inicializado: $e');
        debugPrint('[WelcomeScreen] Stack trace: $stackTrace');
      }
      _currentUser = null;
      _authSubscription = null;
    }

    // Agregar listeners a los FocusNodes para activar el campo cuando recibe focus
    // y geocodificar cuando pierde el foco
    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus) {
        _onAddressInputChanged('', 'pickup');
      } else {
        // Si el campo pierde el foco y hay texto, pero no hay coordenadas, intentar geocodificar
        if (_pickupController.text.trim().isNotEmpty) {
          if (_originCoords == null && _pickupController.text.trim().length >= 3) {
            _geocodeAddress(_pickupController.text.trim(), 'pickup');
          }
        }
      }
    });

    _dropoffFocusNode.addListener(() {
      if (_dropoffFocusNode.hasFocus) {
        _onAddressInputChanged('', 'dropoff');
      } else {
        // Si el campo pierde el foco y hay texto, pero no hay coordenadas, intentar geocodificar
        if (_dropoffController.text.trim().isNotEmpty) {
          if (_destinationCoords == null && _dropoffController.text.trim().length >= 3) {
            _geocodeAddress(_dropoffController.text.trim(), 'dropoff');
          }
        }
      }
    });
  }

  @override
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _authSubscription?.cancel();
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
    // Verificar si Firebase está inicializado antes de acceder
    bool firebaseInitialized = false;
    try {
      firebaseInitialized = Firebase.apps.isNotEmpty;
    } catch (e) {
      // Si hay error al verificar Firebase, asumir que no está inicializado
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Error verificando Firebase: $e');
      }
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Firebase no inicializado: no se puede hacer logout');
      }
      return;
    }

    try {
      // Cerrar sesión de Firebase de forma segura
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e, stackTrace) {
        // Manejo seguro de excepciones para Flutter Web
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] ⚠️ Error al cerrar sesión: $e');
          debugPrint('[WelcomeScreen] Stack trace: $stackTrace');
        }
      }

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

  Future<void> _navigateToRequestRide() async {
    // Verificar si Firebase está inicializado antes de acceder
    bool firebaseInitialized = false;
    try {
      firebaseInitialized = Firebase.apps.isNotEmpty;
    } catch (e) {
      // Si hay error al verificar Firebase, asumir que no está inicializado
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Error verificando Firebase: $e');
      }
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Firebase no inicializado: redirigiendo a login');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e, stackTrace) {
      // Manejo seguro de excepciones para Flutter Web
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Error obteniendo usuario: $e');
        debugPrint('[WelcomeScreen] Stack trace: $stackTrace');
      }
      user = null;
    }
    if (user == null) {
      // Si no está autenticado, mostrar diálogo
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
    } else {
      // Si está autenticado, verificar si necesitamos geocodificar antes de navegar
      final pickupText = _pickupController.text.trim();
      final dropoffText = _dropoffController.text.trim();
      bool needsGeocoding = false;

      // Verificar si hay texto pero no coordenadas
      if (pickupText.isNotEmpty && _originCoords == null) {
        needsGeocoding = true;
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] 🔍 Necesita geocodificar origen: "$pickupText"');
        }
      }
      if (dropoffText.isNotEmpty && _destinationCoords == null) {
        needsGeocoding = true;
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] 🔍 Necesita geocodificar destino: "$dropoffText"');
        }
      }

      // Si necesita geocodificar, hacerlo antes de navegar
      if (needsGeocoding) {
        setState(() {
          _isGeocoding = true;
        });

        try {
          // Geocodificar origen si es necesario (modo silencioso para no mostrar múltiples mensajes)
          if (pickupText.isNotEmpty && _originCoords == null) {
            if (kDebugMode) {
              debugPrint('[WelcomeScreen] 🔍 Geocodificando origen antes de navegar...');
            }
            await _geocodeAddress(pickupText, 'pickup', silent: true);
            // Esperar un poco para que se actualice el estado
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Geocodificar destino si es necesario (modo silencioso para no mostrar múltiples mensajes)
          if (dropoffText.isNotEmpty && _destinationCoords == null) {
            if (kDebugMode) {
              debugPrint('[WelcomeScreen] 🔍 Geocodificando destino antes de navegar...');
            }
            await _geocodeAddress(dropoffText, 'dropoff', silent: true);
            // Esperar un poco para que se actualice el estado
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Recalcular distancia y precio si ahora tenemos ambas coordenadas
          if (_originCoords != null && _destinationCoords != null) {
            await _calculateDistanceAndPrice();
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[WelcomeScreen] ❌ Error geocodificando antes de navegar: $e');
          }
          // Continuar navegando aunque haya error, pero mostrar mensaje
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Algunas direcciones no pudieron ser geocodificadas. El mapa puede no mostrar la ruta completa.',
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isGeocoding = false;
            });
          }
        }
      }

      // Navegar a solicitar viaje con los valores actualizados
      if (mounted) {
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
              initialDistanceKm: _distanceKm,
              initialOriginCoords: _originCoords,
              initialDestinationCoords: _destinationCoords,
              initialVehicleType: _selectedVehicleType,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Scaffold(
      extendBodyBehindAppBar: true, // Permite que el body se extienda detrás del AppBar
      backgroundColor: Colors.transparent, // Fondo transparente del Scaffold
      appBar: WelcomeNavbar(
        currentUser: _currentUser,
        onNavigateToLogin: _navigateToLogin,
        onNavigateToProfile: _navigateToProfile,
        onHandleLogout: _handleLogout,
        onNavigateToWelcomePath: _navigateToWelcomePath,
        onNavigateToCompany: _navigateToCompany,
        onNavigateToDestination: _navigateToDestination,
        onNavigateToContacts: _navigateToContacts,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Contenido principal (arriba) - Solo containers 1 y 2
              Expanded(
                child: Stack(
                  children: [
                    // Carrusel de imágenes de fondo solo para containers 1 y 2
                    Positioned.fill(child: const BackgroundCarousel()),
                    Container(
                      decoration: BoxDecoration(
                        // Overlay oscuro estilo "Premium/Lujo" más ligero para que se vean más las imágenes
                        // Opción 1: Negro Puro / Gris Carbón (estilo exclusivo)
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(
                              0xFF1C1C1C,
                            ).withValues(alpha: 0.4), // Gris Carbón más transparente
                            const Color(
                              0xFF000000,
                            ).withValues(alpha: 0.5), // Negro Puro más transparente
                          ],
                        ),
                        // Opción 2: Azul Marino Profundo (descomentar para usar)
                        // gradient: LinearGradient(
                        //   begin: Alignment.topCenter,
                        //   end: Alignment.bottomCenter,
                        //   colors: [
                        //     const Color(0xFF0A192F).withValues(alpha: 0.4), // Azul Marino Profundo
                        //     const Color(0xFF14213D).withValues(alpha: 0.5), // Azul Marino Oscuro
                        //   ],
                        // ),
                      ),
                      child: SafeArea(
                        child: Transform.translate(
                          offset: const Offset(0, -25),
                          child: isTablet ? _buildWideLayout() : _buildNarrowLayout(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppLogoHeader(),
        ],
      ),
    );
  }

  /// Navega a /welcome en web sin usar dart:html directamente
  void _navigateToWelcomePath() {
    if (kIsWeb) {
      // Usar una solución compatible que funcione en Flutter Web
      // Simplemente construir la URL y usar window.location a través de JS
      final uri = Uri.base.replace(path: '/welcome');
      // En Flutter Web, podemos usar una función helper que use JS interop
      // Por ahora, usar una solución simple que no requiera dart:html
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] Navegando a: ${uri.toString()}');
      }
      // Nota: Para una implementación completa, se recomienda usar package:web
      // o go_router para manejar la navegación en Flutter Web
      // Por ahora, esta función está preparada para futura implementación
    }
  }

  /// Navega a /empresa en web
  void _navigateToCompany() {
    if (kDebugMode) {
      debugPrint('[WelcomeScreen] _navigateToCompany llamado');
      debugPrint('[WelcomeScreen] Context mounted: $mounted');
    }

    if (!mounted) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Context no está montado, no se puede navegar');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] Navegando a CompanyScreen');
      }
      // Usar pushReplacement para reemplazar la pantalla actual
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const CompanyScreen()));
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ✅ Navegación iniciada');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ❌ Error navegando a CompanyScreen: $e');
        debugPrint('[WelcomeScreen] Stack trace: $stackTrace');
      }
      // Fallback: intentar con push normal
      try {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CompanyScreen()));
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] ❌ Error en fallback también: $e2');
        }
      }
    }
  }

  /// Navega a destinos
  void _navigateToDestination() {
    if (kDebugMode) {
      debugPrint('[WelcomeScreen] _navigateToDestination llamado');
      debugPrint('[WelcomeScreen] Context mounted: $mounted');
    }

    if (!mounted) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Context no está montado, no se puede navegar');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] Navegando a DestinationsScreen');
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const DestinationsScreen()));
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ✅ Navegación iniciada');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ❌ Error navegando a DestinationsScreen: $e');
        debugPrint('[WelcomeScreen] Stack trace: $stackTrace');
      }
      try {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const DestinationsScreen()));
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] ❌ Error en fallback también: $e2');
        }
      }
    }
  }

  /// Navega a contactos
  void _navigateToContacts() {
    if (kDebugMode) {
      debugPrint('[WelcomeScreen] _navigateToContacts llamado');
      debugPrint('[WelcomeScreen] Context mounted: $mounted');
    }

    if (!mounted) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Context no está montado, no se puede navegar');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] Navegando a ContactsScreen');
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const ContactsScreen()));
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ✅ Navegación iniciada');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ❌ Error navegando a ContactsScreen: $e');
        debugPrint('[WelcomeScreen] Stack trace: $stackTrace');
      }
      try {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ContactsScreen()));
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] ❌ Error en fallback también: $e2');
        }
      }
    }
  }

  /// Construye el carrusel de imágenes de fondo

  Widget _buildWideLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48.0, 48.0, 48.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contenedor 1: Logo e información superior
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: _kSpacing * 0.5,
                bottom: _kSpacing * 0.5,
                left: _kSpacing * 2,
                right: _kSpacing * 2,
              ),
              child: _buildBottomSection(),
            ),
            const SizedBox(height: _kSpacing * 0.25),
            // Fila con 2 contenedores: Izquierda (formulario) y Derecha (carrusel)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Formulario
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(_kSpacing * 2),
                    // Sin fondo en el container para que no se vea
                    child: _buildFormSection(),
                  ),
                ),
                const SizedBox(width: _kSpacing * 2),
                // Contenedor 2: Derecha - Carrusel
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: 0,
                      bottom: _kSpacing * 2,
                      left: _kSpacing * 2,
                      right: _kSpacing * 2,
                    ),
                    child: SizedBox(height: 425, child: VehicleCarousel(vehicles: _vehicles)),
                  ),
                ),
              ],
            ),
            // Contenedor 3: Información adicional - Continúa después de containers 1 y 2
            const SizedBox(height: _kSpacing * 3),
            _buildContainer3(),
            const SizedBox(height: _kSpacing * 2),
            // Footer
            WelcomeFooter(
              onNavigateToWelcome: _navigateToWelcomePath,
              onNavigateToDestination: _navigateToDestination,
              onNavigateToCompany: _navigateToCompany,
              onNavigateToContacts: _navigateToContacts,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return WelcomeFormSection(
      pickupController: _pickupController,
      dropoffController: _dropoffController,
      timeController: _timeController,
      pickupFocusNode: _pickupFocusNode,
      dropoffFocusNode: _dropoffFocusNode,
      activeInputType: _activeInputType,
      autocompleteResults: _autocompleteResults,
      pickupDate: _pickupDate,
      passengers: _passengers,
      maxPassengers: _maxPassengers,
      originCoords: _originCoords,
      destinationCoords: _destinationCoords,
      distanceKm: _distanceKm,
      estimatedPrice: _estimatedPrice,
      selectedVehicleType: _selectedVehicleType,
      isGeocoding: _isGeocoding,
      onVehicleTypeChanged: (vehicleType) {
        setState(() {
          _selectedVehicleType = vehicleType;
        });
        // Recalcular precio cuando cambia el tipo de vehículo
        if (_originCoords != null && _destinationCoords != null) {
          _calculateDistanceAndPrice();
        }
      },
      onAddressInputChanged: _onAddressInputChanged,
      onSelectAddress: _selectAddressFromAutocomplete,
      onGeocodeAddress: _geocodeAddress,
      onSelectPickupDate: _selectPickupDate,
      onSelectPickupTime: _selectPickupTime,
      onPassengersChanged: (value) => setState(() => _passengers = value),
      onNavigateToRequestRide: _navigateToRequestRide,
    );
  }

  Widget _buildBottomSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Title - a todo el ancho, más arriba
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return SizedBox(
              width: double.infinity,
              child: Text(
                l10n?.welcomeTitle ?? 'Tu viaje perfecto comienza aquí',
                style: GoogleFonts.exo(
                  fontSize: isTablet ? 48 : 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Cambiado a blanco para contraste con fondo oscuro
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
        const SizedBox(height: _kSpacing * 2),

        // Description - centrado
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return SizedBox(
              width: double.infinity,
              child: Text(
                l10n?.welcomeSubtitle ??
                    'Solicita tu viaje de manera rápida y segura. Disponible 24/7 para llevarte a donde necesites.',
                style: GoogleFonts.exo(
                  fontSize: isTablet ? 18 : 16,
                  color: Colors.white.withValues(alpha: 0.9), // Cambiado a blanco semi-transparente
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
        const SizedBox(height: _kSpacing * 2),

        // Features - en fila horizontal
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildFeatureItem(
                    Icons.check_circle,
                    l10n?.quickBooking ?? 'Reserva rápida y fácil',
                  ),
                ),
                const SizedBox(width: _kSpacing),
                Expanded(
                  child: _buildFeatureItem(
                    Icons.shield,
                    (l10n?.verifiedDrivers != null && !l10n!.verifiedDrivers.startsWith('form.'))
                        ? l10n.verifiedDrivers
                        : 'Conductores verificados',
                  ),
                ),
                const SizedBox(width: _kSpacing),
                Expanded(
                  child: _buildFeatureItem(
                    Icons.payment,
                    l10n?.featurePayment ?? 'Múltiples métodos de pago',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 84.0, 24.0, 24.0),
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
            _buildFormSection(),
            const SizedBox(height: _kSpacing * 2),
            SizedBox(height: 298, child: VehicleCarousel(vehicles: _vehicles)),
            const SizedBox(height: _kSpacing * 2),
            // Contenedor 3: Información adicional - Continúa después de containers 1 y 2
            _buildContainer3(),
            const SizedBox(height: _kSpacing * 2),
            // Footer
            WelcomeFooter(
              onNavigateToWelcome: _navigateToWelcomePath,
              onNavigateToDestination: _navigateToDestination,
              onNavigateToCompany: _navigateToCompany,
              onNavigateToContacts: _navigateToContacts,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAddressInputChanged(String query, String type) async {
    _debounceTimer?.cancel();

    // Actualizar el campo activo siempre, incluso si la query es corta
    setState(() {
      _activeInputType = type;
    });

    if (kDebugMode) {
      debugPrint(
        '[WelcomeScreen] _onAddressInputChanged: type=$type, query="$query", length=${query.length}',
      );
    }

    if (query.length < 2) {
      setState(() {
        _autocompleteResults = [];
      });
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] Query muy corta, limpiando resultados');
      }
      return;
    }

    // Aumentar debounce a 500ms para reducir peticiones y cumplir con rate limiting
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] Buscando direcciones para: "$query"');
        }
        final results = await AddressAutocompleteService.searchAddresses(query);
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] Resultados encontrados: ${results.length}');
        }
        if (mounted && _activeInputType == type) {
          setState(() {
            _autocompleteResults = results;
          });
          if (kDebugMode) {
            debugPrint(
              '[WelcomeScreen] Autocompletado actualizado: ${results.length} resultados para $type',
            );
          }
        } else if (kDebugMode) {
          debugPrint(
            '[WelcomeScreen] No actualizando: mounted=$mounted, activeInputType=$_activeInputType, type=$type',
          );
        }
      } catch (e) {
        // Manejo seguro de excepciones para Flutter Web
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] Error en autocompletado: $e');
        }
        if (mounted && _activeInputType == type) {
          setState(() {
            _autocompleteResults = [];
          });
        }
      }
    });
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

    if (lat == null || lon == null || lat == 0.0 || lon == 0.0) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ⚠️ Coordenadas inválidas: lat=$latValue, lon=$lonValue');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[WelcomeScreen] ✅ Seleccionando dirección: $address');
      debugPrint('[WelcomeScreen] Coordenadas: lat=$lat, lon=$lon');
    }

    final point = LatLng(lat, lon);

    // Obtener el texto actual del usuario antes de reemplazarlo
    final currentText = type == 'pickup' ? _pickupController.text : _dropoffController.text;

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

    if (type == 'pickup') {
      _pickupController.text = finalAddress;
      _pickupFocusNode.unfocus();
      _originCoords = point;
      if (kDebugMode) {
        debugPrint(
          '[WelcomeScreen] ✅ Origen actualizado: ${_originCoords?.latitude}, ${_originCoords?.longitude}',
        );
      }
    } else {
      _dropoffController.text = finalAddress;
      _dropoffFocusNode.unfocus();
      _destinationCoords = point;
      if (kDebugMode) {
        debugPrint(
          '[WelcomeScreen] ✅ Destino actualizado: ${_destinationCoords?.latitude}, ${_destinationCoords?.longitude}',
        );
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

  Future<void> _geocodeAddress(String address, String type, {bool silent = false}) async {
    if (address.trim().length < 3) return;

    if (kDebugMode) {
      debugPrint(
        '[WelcomeScreen] 🔍 Geocodificando dirección: "$address" (type: $type, silent: $silent)',
      );
    }

    try {
      // Usar el servicio de autocompletado para buscar la dirección
      final results = await AddressAutocompleteService.searchAddresses(address);

      if (results.isNotEmpty) {
        // Tomar el primer resultado (el más relevante)
        final result = results[0];
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] ✅ Dirección geocodificada: ${result['display_name']}');
        }
        // Seleccionar automáticamente el primer resultado
        _selectAddressFromAutocomplete(result, type);
      } else {
        if (kDebugMode) {
          debugPrint('[WelcomeScreen] ⚠️ No se encontraron resultados para: "$address"');
        }
        // Solo mostrar mensaje si no es modo silencioso
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo encontrar la dirección: $address'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WelcomeScreen] ❌ Error geocodificando dirección: $e');
      }
      // Solo mostrar mensaje si no es modo silencioso
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al buscar la dirección: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // Re-lanzar el error para que el llamador pueda manejarlo
      rethrow;
    }
  }

  Future<void> _calculateDistanceAndPrice() async {
    if (_originCoords == null || _destinationCoords == null) return;

    final result = await RideCalculationService.calculateDistanceAndPrice(
      _originCoords,
      _destinationCoords,
      vehicleType: _selectedVehicleType,
      useFixedPlaces: true,
    );

    if (mounted) {
      setState(() {
        _distanceKm = result['distance'];
        _estimatedPrice = result['price'];
      });
    }
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 24), // Cambiado a blanco
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.exo(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ), // Cambiado a blanco
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildContainer3() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? _kSpacing * 1.5 : _kSpacing,
        vertical: _kSpacing * 0.5,
      ),
      padding: EdgeInsets.all(isTablet ? _kSpacing * 2 : _kSpacing * 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(_kBorderRadius * 1.5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Center(
                child: Text(
                  l10n?.featuresTitle ?? 'Características',
                  style: GoogleFonts.exo(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          const SizedBox(height: _kSpacing * 0.5),
          // Subtítulo
          Center(
            child: Text(
              'Descubre por qué somos tu mejor opción para viajar',
              style: GoogleFonts.exo(
                fontSize: isTablet ? 13 : 12,
                color: Colors.black87,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: _kSpacing * (isTablet ? 3 : 2)),
          // Grid de características
          isTablet ? _buildFeaturesWideLayout(isTablet) : _buildFeaturesNarrowLayout(),
        ],
      ),
    );
  }

  Widget _buildFeaturesWideLayout(bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildFeatureCard(1, 'Viaje', _getFeature1Text(), isTablet)),
        SizedBox(width: _kSpacing * 3),
        Expanded(child: _buildFeatureCard(2, 'Experiencia', _getFeature2Text(), isTablet)),
        SizedBox(width: _kSpacing * 3),
        Expanded(child: _buildFeatureCard(3, 'Relax', _getFeature3Text(), isTablet)),
      ],
    );
  }

  Widget _buildFeaturesNarrowLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Column(
      children: [
        _buildFeatureCard(1, 'Viaje', _getFeature1Text(), isTablet),
        SizedBox(height: _kSpacing * 2.5),
        _buildFeatureCard(2, 'Experiencia', _getFeature2Text(), isTablet),
        SizedBox(height: _kSpacing * 2.5),
        _buildFeatureCard(3, 'Relax', _getFeature3Text(), isTablet),
      ],
    );
  }

  Widget _buildFeatureCard(int number, String title, String description, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Número grande en blanco
        Text(
          number.toString().padLeft(2, '0'),
          style: GoogleFonts.exo(
            fontSize: isTablet ? 48 : 40,
            fontWeight: FontWeight.w300,
            color: Colors.white,
            height: 1.0,
            letterSpacing: -2,
          ),
        ),
        SizedBox(height: _kSpacing * 0.5),
        // Título
        Text(
          title,
          style: GoogleFonts.exo(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: _kSpacing),
        // Descripción
        Text(
          description,
          style: GoogleFonts.exo(
            fontSize: isTablet ? 12 : 11,
            color: Colors.black87,
            height: 1.6,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  String _getFeature1Text() {
    return 'Un viaje con nuestro servicio es mucho más que un simple desplazamiento, es una experiencia llena de comodidad y atención personalizada. Cada destino se convierte en un viaje de relajación y descubrimiento único.';
  }

  String _getFeature2Text() {
    return 'Descubre un mundo en el que cada viaje se transforma en una oportunidad de conexión. Vivirás momentos irrepetibles, disfrutando de un servicio impecable, destinos extraordinarios y una atención que cuida cada detalle.';
  }

  String _getFeature3Text() {
    return 'Cada viaje es una escapada creada para renovar cuerpo y alma. Disfruta de destinos exclusivos, servicios de alta gama y una atención especial pensada para hacerte vivir el relax total que mereces.';
  }

  // Métodos eliminados - ahora se usan los componentes de form/
  // _buildDateField, _buildTimeField, _buildPassengersField, _buildInfoField
  // se movieron a lib/screens/welcome/form/

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
                    child: Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.select ?? 'Seleccionar',
                          style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
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
                    child: Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.select ?? 'Seleccionar',
                          style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
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
