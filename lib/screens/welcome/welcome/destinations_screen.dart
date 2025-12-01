import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../navbar/welcome_navbar.dart';
import 'widgets/welcome_footer.dart';
import 'welcome_screen.dart';
import 'company_screen.dart';
import 'contacts_screen.dart';
import '../../../auth/login_screen.dart';
import '../../../widgets/app_logo_header.dart';

// Constants
const _kSpacing = 16.0;
const _kBorderRadius = 16.0;

// Datos de destinos
final List<Map<String, dynamic>> _destinations = [
  {
    'name': 'Roma',
    'airport': 'Aeroporto di Roma',
    'center': 'Roma Centro',
    'image': 'images/destinos/destination_1.jpg',
    'rating': 4,
  },
  {
    'name': 'Milano',
    'airport': 'Aeroporto di Milano',
    'center': 'Milano Centro',
    'image': 'images/destinos/destination_2.jpg',
    'rating': 4,
  },
  {
    'name': 'Firenze',
    'airport': 'Aeroporto di Firenze',
    'center': 'Firenze Centro',
    'image': 'images/destinos/destination_3.jpg',
    'rating': 4,
  },
  {
    'name': 'Bologna',
    'airport': 'Aeroporto di Bologna',
    'center': 'Bologna Centro',
    'image': 'images/destinos/destination_4.jpg',
    'rating': 4,
  },
  {
    'name': 'Pisa',
    'airport': 'Aeroporto di Pisa',
    'center': 'Pisa Centro',
    'image': 'images/destinos/destination_5.jpg',
    'rating': 4,
  },
];

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mi perfil (próximamente)')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
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
        onNavigateToDestination: _navigateToDestination,
        onNavigateToContacts: _navigateToContacts,
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
                      Text(
                        'Prenota subito il tuo taxi e viaggia comodamente!',
                        style: GoogleFonts.exo(
                          fontSize: isTablet ? 18 : 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.6,
                        ),
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Logo flotante
          const AppLogoHeader(),
        ],
      ),
    );
  }

  Widget _buildDestinationsGrid(bool isTablet) {
    if (!isTablet) {
      // En móvil, mostrar en columna simple
      return Column(
        children: _destinations
            .map(
              (dest) => Padding(
                padding: const EdgeInsets.only(bottom: _kSpacing * 2),
                child: _buildDestinationCard(dest),
              ),
            )
            .toList(),
      );
    }

    // En tablet: layout de 5 columnas, una por destino
    // Columnas 2 y 4 (índices 1 y 3) tienen info arriba, imagen abajo
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _destinations.length; i++) ...[
            if (i > 0) const SizedBox(width: _kSpacing * 1.5),
            Expanded(
              flex: 1,
              child: _buildDestinationCard(
                _destinations[i],
                reverseOrder: i == 1 || i == 3, // Milano (1) y Bologna (3)
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDestinationCard(Map<String, dynamic> destination, {bool reverseOrder = false}) {
    final imageWidget = ClipRRect(
      borderRadius: reverseOrder
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(_kBorderRadius),
              bottomRight: Radius.circular(_kBorderRadius),
            )
          : const BorderRadius.only(
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
                Text('Ranking', style: GoogleFonts.exo(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: _kSpacing * 0.75),
            // Descripción
            Text(
              'Prenota subito il tuo taxi e viaggia comodamente!',
              style: GoogleFonts.exo(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                child: Text(
                  'Prenotare',
                  style: GoogleFonts.exo(fontSize: 14, fontWeight: FontWeight.w600),
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
        children: reverseOrder
            ? [
                // Contenido arriba
                contentWidget,
                // Imagen abajo
                imageWidget,
              ]
            : [
                // Imagen arriba
                imageWidget,
                // Contenido abajo
                contentWidget,
              ],
      ),
    );
  }
}
