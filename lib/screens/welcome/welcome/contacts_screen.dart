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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 64.0 : 24.0,
                            isTablet ? 12.0 : 8.0,
                            isTablet ? 64.0 : 24.0,
                            8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40), // Espacio para el navbar
                              Text(
                                '¿Tienes alguna pregunta?',
                                style: GoogleFonts.exo(
                                  fontSize: isTablet ? 28 : 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: _kSpacing * 0.25),
                              Text(
                                'Estamos aquí para ayudarte',
                                style: GoogleFonts.exo(
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: isTablet ? _kSpacing * 0.25 : _kSpacing * 0.5),
                              // Contactos
                              Expanded(child: _buildContactSection(isTablet)),
                            ],
                          ),
                        ),
                      ),
                      // Footer
                      WelcomeFooter(
                        onNavigateToWelcome: _navigateToWelcomePath,
                        onNavigateToDestination: _navigateToDestination,
                        onNavigateToCompany: _navigateToCompany,
                        onNavigateToContacts: _navigateToContacts,
                      ),
                    ],
                  );
                },
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
    final maxWidth = isTablet ? 1200.0 : double.infinity;

    if (isTablet) {
      // Layout de 4 columnas en tablet
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildContactColumn(
                  icon: Icons.phone_rounded,
                  title: 'Teléfono',
                  content: '(+39) 392 1774905',
                  onTap: () => _launchUrl('tel:+393921774905'),
                  isTablet: isTablet,
                ),
              ),
              Expanded(
                child: _buildContactColumn(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  content: 'info@eugeniastravelconsultancy.com',
                  onTap: () => _launchUrl('mailto:info@lasiciliatour.com'),
                  isTablet: isTablet,
                ),
              ),
              Expanded(
                child: _buildContactColumn(
                  icon: Icons.language_rounded,
                  title: 'Sitio Web',
                  content: 'www.eugeniastravelconsultancy.com',
                  onTap: () => _launchUrl('https://www.eugeniastravelconsultancy.com/'),
                  isTablet: isTablet,
                ),
              ),
              Expanded(
                child: _buildContactColumn(
                  icon: Icons.location_on_rounded,
                  title: 'Ubicación',
                  content: 'Sicilia, Italia',
                  onTap: () {},
                  isTablet: isTablet,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Layout de columna única en móvil
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: [
            _buildContactColumn(
              icon: Icons.phone_rounded,
              title: 'Teléfono',
              content: '(+39) 392 1774905',
              onTap: () => _launchUrl('tel:+393921774905'),
              isTablet: isTablet,
            ),
            const SizedBox(height: _kSpacing * 2),
            _buildContactColumn(
              icon: Icons.email_rounded,
              title: 'Email',
              content: 'info@eugeniastravelconsultancy.com',
              onTap: () => _launchUrl('mailto:info@lasiciliatour.com'),
              isTablet: isTablet,
            ),
            const SizedBox(height: _kSpacing * 2),
            _buildContactColumn(
              icon: Icons.language_rounded,
              title: 'Sitio Web',
              content: 'www.eugeniastravelconsultancy.com',
              onTap: () => _launchUrl('https://www.eugeniastravelconsultancy.com/'),
              isTablet: isTablet,
            ),
            const SizedBox(height: _kSpacing * 2),
            _buildContactColumn(
              icon: Icons.location_on_rounded,
              title: 'Ubicación',
              content: 'Sicilia, Italia',
              onTap: () {},
              isTablet: isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactColumn({
    required IconData icon,
    required String title,
    required String content,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? _kSpacing : _kSpacing * 0.75,
          vertical: _kSpacing,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono circular
            Container(
              width: isTablet ? 70 : 56,
              height: isTablet ? 70 : 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: isTablet ? 36 : 28),
            ),
            SizedBox(height: isTablet ? _kSpacing : _kSpacing * 0.75),
            // Título
            Text(
              title,
              style: GoogleFonts.exo(
                fontSize: isTablet ? 16 : 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? _kSpacing * 0.75 : _kSpacing * 0.5),
            // Contenido
            Text(
              content,
              style: GoogleFonts.exo(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
