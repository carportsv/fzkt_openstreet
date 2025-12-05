import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navbar/welcome_navbar.dart';
import '../../../../shared/widgets/welcome_footer.dart';
import '../welcome_screen.dart';
import 'company_screen.dart';
import 'contacts_screen.dart';
import 'servicios_screen.dart';
import 'acerca_de_screen.dart';
import 'tours_screen.dart';
import 'weddings_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import '../../../../auth/login_screen.dart';
import '../../../../shared/widgets/app_logo_header.dart';
import '../../../../l10n/app_localizations.dart';

// Constants
const _kSpacing = 16.0;
const _kBorderRadius = 16.0;

// Datos de destinos (sin localización - se obtiene dinámicamente)
final List<Map<String, dynamic>> _destinationsData = [
  {'name': 'Roma', 'key': 'rome', 'image': 'assets/images/destinos/destination_1.jpg', 'rating': 4},
  {
    'name': 'Milano',
    'key': 'milan',
    'image': 'assets/images/destinos/destination_2.jpg',
    'rating': 4,
  },
  {
    'name': 'Firenze',
    'key': 'florence',
    'image': 'assets/images/destinos/destination_3.jpg',
    'rating': 4,
  },
  {
    'name': 'Bologna',
    'key': 'bologna',
    'image': 'assets/images/destinos/destination_4.jpg',
    'rating': 4,
  },
  {'name': 'Pisa', 'key': 'pisa', 'image': 'assets/images/destinos/destination_5.jpg', 'rating': 4},
  {'name': 'Bergamo', 'key': 'bergamo', 'image': 'assets/images/destinos/bergamo.png', 'rating': 4},
  {'name': 'Catania', 'key': 'catania', 'image': 'assets/images/destinos/catania.png', 'rating': 4},
  {
    'name': 'Milano Linate',
    'key': 'linate',
    'image': 'assets/images/destinos/linate.jpg',
    'rating': 4,
  },
  {'name': 'Palermo', 'key': 'palermo', 'image': 'assets/images/destinos/palermo.png', 'rating': 4},
  {'name': 'Torino', 'key': 'torino', 'image': 'assets/images/destinos/torino.png', 'rating': 4},
];

List<Map<String, dynamic>> _getDestinations(AppLocalizations? l10n) {
  if (l10n == null) {
    // Fallback a italiano si no hay localización
    return _destinationsData
        .map(
          (dest) => {
            'name': dest['name'],
            'airport': 'Aeroporto di ${dest['name']}',
            'center': '${dest['name']} Centro',
            'image': dest['image'],
            'rating': dest['rating'],
          },
        )
        .toList();
  }

  return _destinationsData.map((dest) {
    final key = dest['key'] as String;
    String airport;
    String center;

    switch (key) {
      case 'rome':
        airport = l10n.destinationsRomeAirport;
        center = l10n.destinationsRomeCenter;
        break;
      case 'milan':
        airport = l10n.destinationsMilanAirport;
        center = l10n.destinationsMilanCenter;
        break;
      case 'florence':
        airport = l10n.destinationsFlorenceAirport;
        center = l10n.destinationsFlorenceCenter;
        break;
      case 'bologna':
        airport = l10n.destinationsBolognaAirport;
        center = l10n.destinationsBolognaCenter;
        break;
      case 'pisa':
        airport = l10n.destinationsPisaAirport;
        center = l10n.destinationsPisaCenter;
        break;
      case 'bergamo':
        airport = l10n.destinationsBergamoAirport;
        center = l10n.destinationsBergamoCenter;
        break;
      case 'catania':
        airport = l10n.destinationsCataniaAirport;
        center = l10n.destinationsCataniaCenter;
        break;
      case 'linate':
        airport = l10n.destinationsLinateAirport;
        center = l10n.destinationsLinateCenter;
        break;
      case 'palermo':
        airport = l10n.destinationsPalermoAirport;
        center = l10n.destinationsPalermoCenter;
        break;
      case 'torino':
        airport = l10n.destinationsTorinoAirport;
        center = l10n.destinationsTorinoCenter;
        break;
      default:
        airport = 'Aeroporto di ${dest['name']}';
        center = '${dest['name']} Centro';
    }

    return {
      'name': dest['name'],
      'airport': airport,
      'center': center,
      'image': dest['image'],
      'rating': dest['rating'],
    };
  }).toList();
}

/// Pantalla de destinos disponibles
class DestinationsScreen extends StatefulWidget {
  const DestinationsScreen({super.key});

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Verificar usuario actual de forma segura
    bool firebaseInitialized = false;
    try {
      firebaseInitialized = Firebase.apps.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ⚠️ Error verificando Firebase: $e');
      }
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ⚠️ Firebase no inicializado');
      }
      _currentUser = null;
      return;
    }

    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      // Escuchar cambios en la autenticación
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ⚠️ Error obteniendo usuario: $e');
      }
      _currentUser = null;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _navigateToProfile() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n?.profileComingSoon ?? 'Mi perfil (próximamente)')));
  }

  Future<void> _handleLogout() async {
    if (!mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n?.logoutError ?? 'Error al cerrar sesión'}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToWelcomePath() {
    if (kDebugMode) {
      debugPrint('[DestinationsScreen] _navigateToWelcomePath llamado');
      debugPrint('[DestinationsScreen] Context mounted: $mounted');
    }

    if (!mounted) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ⚠️ Context no está montado, no se puede navegar');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] Navegando a WelcomeScreen');
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ✅ Navegación iniciada');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a WelcomeScreen: $e');
        debugPrint('[DestinationsScreen] Stack trace: $stackTrace');
      }
      try {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[DestinationsScreen] ❌ Error en fallback también: $e2');
        }
      }
    }
  }

  void _navigateToDestination() {
    // Ya estamos en la pantalla de destinos
  }

  void _navigateToCompany() {
    if (kDebugMode) {
      debugPrint('[DestinationsScreen] _navigateToCompany llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const CompanyScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a CompanyScreen: $e');
      }
    }
  }

  void _navigateToContacts() {
    if (kDebugMode) {
      debugPrint('[DestinationsScreen] _navigateToContacts llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const ContactsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a ContactsScreen: $e');
      }
    }
  }

  void _navigateToTours() {
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const ToursScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a ToursScreen: $e');
      }
    }
  }

  void _navigateToWeddings() {
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const WeddingsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a WeddingsScreen: $e');
      }
    }
  }

  void _navigateToTerms() {
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const TermsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a TermsScreen: $e');
      }
    }
  }

  void _navigateToPrivacy() {
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a PrivacyPolicyScreen: $e');
      }
    }
  }

  void _navigateToServices() {
    if (kDebugMode) {
      debugPrint('[DestinationsScreen] _navigateToServices llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const ServiciosScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a ServiciosScreen: $e');
      }
    }
  }

  void _navigateToAbout() {
    if (kDebugMode) {
      debugPrint('[DestinationsScreen] _navigateToAbout llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const AcercaDeScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DestinationsScreen] ❌ Error navegando a AcercaDeScreen: $e');
      }
    }
  }

  void _onBookDestination(Map<String, dynamic> destination) {
    // Navegar a welcome screen para reservar
    _navigateToWelcomePath();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: WelcomeNavbar(
        currentUser: _currentUser,
        onNavigateToLogin: _navigateToLogin,
        onNavigateToProfile: _navigateToProfile,
        onHandleLogout: _handleLogout,
        onNavigateToWelcomePath: _navigateToWelcomePath,
        onNavigateToCompany: _navigateToCompany,
        onNavigateToServices: _navigateToServices,
        onNavigateToAbout: _navigateToAbout,
        onNavigateToDestination: null, // Ya estamos en esta pantalla
        onNavigateToContacts: _navigateToContacts,
        onNavigateToTours: _navigateToTours,
        onNavigateToWeddings: _navigateToWeddings,
        onNavigateToTerms: _navigateToTerms,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              // Gradiente profesional elegante
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E3A8A), // Azul oscuro profesional
                  const Color(0xFF3B82F6), // Azul medio
                  const Color(0xFF1D4ED8), // Azul primario de la app
                  const Color(0xFF0F172A), // Azul muy oscuro
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 48.0 : 24.0,
                    isTablet ? 24.0 : 16.0,
                    isTablet ? 48.0 : 24.0,
                    8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60), // Espacio para el navbar
                      const SizedBox(height: _kSpacing * 1),
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(
                            l10n?.destinationsSubtitle ??
                                'Reserva ahora tu taxi y viaja cómodamente',
                            style: GoogleFonts.exo(
                              fontSize: isTablet ? 18 : 16,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.6,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: _kSpacing * 1.5),
                      // Grid de destinos
                      _buildDestinationsGrid(isTablet),
                      const SizedBox(height: _kSpacing * 3),
                      // Footer
                      WelcomeFooter(
                        onNavigateToWelcome: _navigateToWelcomePath,
                        onNavigateToDestination: _navigateToDestination,
                        onNavigateToCompany: _navigateToCompany,
                        onNavigateToContacts: _navigateToContacts,
                        onNavigateToServices: _navigateToServices,
                        onNavigateToAbout: _navigateToAbout,
                        onNavigateToTerms: _navigateToTerms,
                        onNavigateToPrivacy: _navigateToPrivacy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Logo flotante
          AppLogoHeader(onTap: _navigateToWelcomePath),
        ],
      ),
    );
  }

  Widget _buildDestinationsGrid(bool isTablet) {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final destinations = _getDestinations(l10n);

        if (!isTablet) {
          // En móvil, mostrar en columna simple
          return Column(
            children: destinations
                .map(
                  (dest) => Padding(
                    padding: const EdgeInsets.only(bottom: _kSpacing * 2),
                    child: _buildDestinationCard(dest),
                  ),
                )
                .toList(),
          );
        }

        // En tablet: layout de 5 columnas con 2 filas
        // Primera fila: 5 destinos
        // Segunda fila: 5 destinos
        // Todas las tarjetas tienen imagen arriba y texto abajo
        return Column(
          children: [
            // Primera fila - 5 destinos
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < 5 && i < destinations.length; i++) ...[
                    if (i > 0) const SizedBox(width: _kSpacing * 1.5),
                    Expanded(flex: 1, child: _buildDestinationCard(destinations[i])),
                  ],
                ],
              ),
            ),
            if (destinations.length > 5) ...[
              const SizedBox(height: _kSpacing * 2),
              // Segunda fila - 5 destinos restantes
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 5; i < destinations.length; i++) ...[
                      if (i > 5) const SizedBox(width: _kSpacing * 1.5),
                      Expanded(flex: 1, child: _buildDestinationCard(destinations[i])),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDestinationCard(Map<String, dynamic> destination) {
    final imageWidget = ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(_kBorderRadius),
        topRight: Radius.circular(_kBorderRadius),
      ),
      child: Image.asset(
        destination['image'] as String,
        fit: BoxFit.cover,
        height: 280,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 280,
            color: Colors.grey.shade300,
            child: const Center(
              child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
            ),
          );
        },
      ),
    );

    final contentWidget = Flexible(
      child: Padding(
        padding: const EdgeInsets.all(_kSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nombre del aeropuerto
            Text(
              destination['airport'] as String,
              style: GoogleFonts.exo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A202C),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Centro
            Text(
              destination['center'] as String,
              style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: _kSpacing * 0.75),
            // Rating
            Row(
              children: [
                ...List.generate(
                  5,
                  (index) => Icon(
                    index < (destination['rating'] as int) ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n?.destinationsRanking ?? 'Ranking',
                      style: GoogleFonts.exo(fontSize: 12, color: Colors.grey.shade600),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: _kSpacing * 0.75),
            // Descripción
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(
                  l10n?.destinationsSubtitle ?? 'Reserva ahora tu taxi y viaja cómodamente',
                  style: GoogleFonts.exo(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            const SizedBox(height: _kSpacing),
            // Botón
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _onBookDestination(destination),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      l10n?.destinationsBookButton ?? 'Reservar',
                      style: GoogleFonts.exo(fontSize: 14, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kBorderRadius),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen siempre arriba
          imageWidget,
          // Contenido siempre abajo
          contentWidget,
        ],
      ),
    );
  }
}
