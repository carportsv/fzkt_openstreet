import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../navbar/welcome_navbar.dart';
import 'widgets/welcome_footer.dart';
import 'welcome_screen.dart';
import 'company_screen.dart';
import 'destinations_screen.dart';
import '../../../auth/login_screen.dart';
import '../../../widgets/app_logo_header.dart';

// Constants
const _kSpacing = 16.0;

/// Pantalla de contactos
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
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
        debugPrint('[ContactsScreen] ⚠️ Error verificando Firebase: $e');
      }
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint('[ContactsScreen] ⚠️ Firebase no inicializado');
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
        debugPrint('[ContactsScreen] ⚠️ Error obteniendo usuario: $e');
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
      debugPrint('[ContactsScreen] _navigateToWelcomePath llamado');
      debugPrint('[ContactsScreen] Context mounted: $mounted');
    }

    if (!mounted) {
      if (kDebugMode) {
        debugPrint('[ContactsScreen] ⚠️ Context no está montado, no se puede navegar');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[ContactsScreen] Navegando a WelcomeScreen');
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      if (kDebugMode) {
        debugPrint('[ContactsScreen] ✅ Navegación iniciada');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ContactsScreen] ❌ Error navegando a WelcomeScreen: $e');
        debugPrint('[ContactsScreen] Stack trace: $stackTrace');
      }
      try {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[ContactsScreen] ❌ Error en fallback también: $e2');
        }
      }
    }
  }

  void _navigateToCompany() {
    if (kDebugMode) {
      debugPrint('[ContactsScreen] _navigateToCompany llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const CompanyScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ContactsScreen] ❌ Error navegando a CompanyScreen: $e');
      }
    }
  }

  void _navigateToDestination() {
    if (kDebugMode) {
      debugPrint('[ContactsScreen] _navigateToDestination llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const DestinationsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ContactsScreen] ❌ Error navegando a DestinationsScreen: $e');
      }
    }
  }

  void _navigateToContacts() {
    // Ya estamos en la pantalla de contactos
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
                      const SizedBox(height: _kSpacing * 2),
                      // Título
                      Text(
                        '¿Tienes alguna pregunta?',
                        style: GoogleFonts.exo(
                          fontSize: isTablet ? 42 : 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: _kSpacing * 3),
                      // Contactos
                      _buildContactSection(isTablet),
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

  Widget _buildContactSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Telefono
        _buildContactItem(
          icon: Icons.phone,
          label: 'Telefono:',
          text: '(+39) 392 1774905',
          onTap: () => _launchUrl('tel:+393921774905'),
          isTablet: isTablet,
        ),
        const SizedBox(height: _kSpacing * 2),
        // Email
        _buildContactItem(
          icon: Icons.email,
          label: 'Email:',
          text: 'info@lasiciliatour.com  -  info@eugeniastravelconsultancy.com',
          onTap: () => _launchUrl('mailto:info@lasiciliatour.com'),
          isTablet: isTablet,
        ),
        const SizedBox(height: _kSpacing * 2),
        // Sito web
        _buildContactItem(
          icon: Icons.language,
          label: 'Sito web:',
          text: 'www.eugeniastravelconsultancy.com/',
          onTap: () => _launchUrl('https://www.eugeniastravelconsultancy.com/'),
          isTablet: isTablet,
        ),
        const SizedBox(height: _kSpacing * 2),
        // Dirección
        _buildContactItem(
          icon: Icons.location_on,
          label: 'Dirección:',
          text: 'Sicilia, Italia',
          onTap: () {},
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String text,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: isTablet ? 24 : 20),
          const SizedBox(width: _kSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.exo(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: GoogleFonts.exo(
                    fontSize: isTablet ? 16 : 14,
                    color: const Color(0xFF4CAF50), // Verde
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
