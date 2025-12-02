import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../navbar/welcome_navbar.dart';
import 'widgets/welcome_footer.dart';
import 'welcome_screen.dart';
import 'destinations_screen.dart';
import 'company_screen.dart';
import 'contacts_screen.dart';
import 'servicios_screen.dart';
import '../../../auth/login_screen.dart';
import '../../../widgets/app_logo_header.dart';
import '../../../l10n/app_localizations.dart';

// Constants
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla "Acerca de" de la empresa
class AcercaDeScreen extends StatefulWidget {
  const AcercaDeScreen({super.key});

  @override
  State<AcercaDeScreen> createState() => _AcercaDeScreenState();
}

class _AcercaDeScreenState extends State<AcercaDeScreen> {
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
        debugPrint('[AcercaDeScreen] ⚠️ Error verificando Firebase: $e');
      }
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint('[AcercaDeScreen] ⚠️ Firebase no inicializado');
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
        debugPrint('[AcercaDeScreen] ⚠️ Error obteniendo usuario: $e');
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
      debugPrint('[AcercaDeScreen] _navigateToWelcomePath llamado');
    }

    if (!mounted) return;

    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AcercaDeScreen] ❌ Error navegando a WelcomeScreen: $e');
        debugPrint('[AcercaDeScreen] Stack trace: $stackTrace');
      }
      try {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[AcercaDeScreen] ❌ Error en fallback también: $e2');
        }
      }
    }
  }

  void _navigateToCompany() {
    if (kDebugMode) {
      debugPrint('[AcercaDeScreen] _navigateToCompany llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const CompanyScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AcercaDeScreen] ❌ Error navegando a CompanyScreen: $e');
      }
    }
  }

  void _navigateToServices() {
    if (kDebugMode) {
      debugPrint('[AcercaDeScreen] _navigateToServices llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const ServiciosScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AcercaDeScreen] ❌ Error navegando a ServiciosScreen: $e');
      }
    }
  }

  void _navigateToDestination() {
    if (kDebugMode) {
      debugPrint('[AcercaDeScreen] _navigateToDestination llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const DestinationsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AcercaDeScreen] ❌ Error navegando a DestinationsScreen: $e');
      }
    }
  }

  void _navigateToContacts() {
    if (kDebugMode) {
      debugPrint('[AcercaDeScreen] _navigateToContacts llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const ContactsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AcercaDeScreen] ❌ Error navegando a ContactsScreen: $e');
      }
    }
  }

  void _navigateToAbout() {
    // Ya estamos en la pantalla de Acerca de
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1C1C1C).withValues(alpha: 0.95),
                const Color(0xFF000000).withValues(alpha: 0.95),
              ],
            ),
          ),
          child: WelcomeNavbar(
            currentUser: _currentUser,
            onNavigateToLogin: _navigateToLogin,
            onNavigateToProfile: _navigateToProfile,
            onHandleLogout: _handleLogout,
            onNavigateToWelcomePath: _navigateToWelcomePath,
            onNavigateToCompany: _navigateToCompany,
            onNavigateToServices: _navigateToServices,
            onNavigateToDestination: _navigateToDestination,
            onNavigateToContacts: _navigateToContacts,
            onNavigateToAbout: _navigateToAbout,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Contenido principal
              Expanded(
                child: Stack(
                  children: [
                    // Imagen de fondo
                    Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/cars/flote.png'),
                          fit: BoxFit.cover,
                          opacity: 0.3,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 48.0 : 24.0,
                            isTablet ? 140.0 : 120.0,
                            isTablet ? 48.0 : 24.0,
                            8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Contenido principal
                              isTablet ? _buildWideLayout() : _buildNarrowLayout(),
                              const SizedBox(height: _kSpacing * 2),
                              // Footer
                              WelcomeFooter(
                                onNavigateToWelcome: _navigateToWelcomePath,
                                onNavigateToDestination: _navigateToDestination,
                                onNavigateToCompany: _navigateToCompany,
                                onNavigateToContacts: _navigateToContacts,
                                onNavigateToServices: _navigateToServices,
                                onNavigateToAbout: _navigateToAbout,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Logo flotante
          AppLogoHeader(onTap: _navigateToWelcomePath),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imagen a la izquierda
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kBorderRadius),
              child: Image.asset(
                'assets/images/empresa/driver.png',
                fit: BoxFit.cover,
                height: 500,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 500,
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: _kSpacing * 3),
        // Contenido a la derecha
        Expanded(flex: 1, child: _buildContent()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imagen arriba
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            child: Image.asset(
              'assets/images/empresa/driver.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 300,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: _kSpacing * 2),
        // Contenido abajo
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              l10n?.aboutTitle ?? 'We are here to make your journey simple and exciting for you',
              style: GoogleFonts.exo(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A202C),
                height: 1.3,
              ),
            ),
            const SizedBox(height: _kSpacing * 2),
            // Primer párrafo
            Text(
              l10n?.aboutParagraph1 ??
                  'Reliable, executive, and safe transportation services are a rare commodity nowadays. The good news is that Eugenia Travel Consultancy taxi is just a call away.',
              style: GoogleFonts.exo(
                fontSize: 16,
                color: const Color(0xFF1A202C),
                height: 1.7,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: _kSpacing * 1.5),
            // Segundo párrafo
            Text(
              l10n?.aboutParagraph2 ??
                  'Ever been in a position where you were running late and had to catch a plane at the last minute? Well, Eugenia Travel Consultancy is available for you, with a reliable taxi company number for you to dial and get your needs sorted. With us, you are assured of timely arrival. The last-minute savior indeed!',
              style: GoogleFonts.exo(
                fontSize: 16,
                color: const Color(0xFF1A202C),
                height: 1.7,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: _kSpacing * 2.5),
            // Lista de características
            _buildFeaturesList(),
          ],
        );
      },
    );
  }

  Widget _buildFeaturesList() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final features = [
          l10n?.aboutLongExperience ?? 'Long-Standing Experience',
          l10n?.aboutTopDrivers ?? 'Top-Notch Drivers',
          l10n?.aboutFirstClassServices ?? 'First-Class Services',
          l10n?.aboutAlwaysOnTime ?? 'Always On Time',
          l10n?.aboutAllAirportTransfers ?? 'All Airport Transfers',
        ];

        return Column(
          children: features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: _kSpacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkmark verde
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: _kSpacing),
                    child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                  ),
                  // Texto
                  Expanded(
                    child: Text(
                      feature,
                      style: GoogleFonts.exo(
                        fontSize: 16,
                        color: const Color(0xFF1A202C),
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
