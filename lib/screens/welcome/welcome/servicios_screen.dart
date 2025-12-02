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
import 'acerca_de_screen.dart';
import '../../../auth/login_screen.dart';
import '../../../widgets/app_logo_header.dart';
import '../../../l10n/app_localizations.dart';

// Constants
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;
const _kPrimaryColor = Color(0xFF1D4ED8);

// Card dimensions - Fácil de editar
// Formato: ancho x alto (ejemplo: 60x30 significa 60 de ancho por 30 de alto)
// childAspectRatio = ancho / alto
// Valores más altos en height = tarjetas más altas (más espacio abajo)
// Valores más bajos en height = tarjetas más bajas (menos espacio abajo)
//
// Para WEB/TABLET (pantallas > 900px):
const _kCardWidthTablet = 60.0; // Ancho relativo para tablet/web
const _kCardHeightTablet = 25.0; // Alto relativo para tablet/web (reducir para menos espacio abajo)
const _kCardAspectRatioTablet = _kCardWidthTablet / _kCardHeightTablet; // ~1.50

// Para MÓVIL (pantallas <= 900px):
const _kCardWidthMobile = 60.0; // Ancho relativo para móvil
const _kCardHeightMobile = 25.0; // Alto relativo para móvil (reducir para menos espacio abajo)
const _kCardAspectRatioMobile = _kCardWidthMobile / _kCardHeightMobile; // ~1.20

/// Pantalla de servicios de la empresa
class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key});

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
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
        debugPrint('[ServiciosScreen] ⚠️ Error verificando Firebase: $e');
      }
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint('[ServiciosScreen] ⚠️ Firebase no inicializado');
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
        debugPrint('[ServiciosScreen] ⚠️ Error obteniendo usuario: $e');
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
      debugPrint('[ServiciosScreen] _navigateToWelcomePath llamado');
    }

    if (!mounted) return;

    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ServiciosScreen] ❌ Error navegando a WelcomeScreen: $e');
        debugPrint('[ServiciosScreen] Stack trace: $stackTrace');
      }
      try {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[ServiciosScreen] ❌ Error en fallback también: $e2');
        }
      }
    }
  }

  void _navigateToCompany() {
    if (kDebugMode) {
      debugPrint('[ServiciosScreen] _navigateToCompany llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const CompanyScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiciosScreen] ❌ Error navegando a CompanyScreen: $e');
      }
    }
  }

  void _navigateToDestination() {
    if (kDebugMode) {
      debugPrint('[ServiciosScreen] _navigateToDestination llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const DestinationsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiciosScreen] ❌ Error navegando a DestinationsScreen: $e');
      }
    }
  }

  void _navigateToContacts() {
    if (kDebugMode) {
      debugPrint('[ServiciosScreen] _navigateToContacts llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const ContactsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiciosScreen] ❌ Error navegando a ContactsScreen: $e');
      }
    }
  }

  void _navigateToServices() {
    // Ya estamos en la pantalla de servicios
  }

  void _navigateToAbout() {
    if (kDebugMode) {
      debugPrint('[ServiciosScreen] _navigateToAbout llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const AcercaDeScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ServiciosScreen] ❌ Error navegando a AcercaDeScreen: $e');
      }
    }
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
            onNavigateToAbout: _navigateToAbout,
            onNavigateToDestination: _navigateToDestination,
            onNavigateToContacts: _navigateToContacts,
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
                    // Fondo blanco/gris claro
                    Container(color: Colors.white),
                    SafeArea(
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
                              const SizedBox(height: _kSpacing), // Espacio para el navbar
                              // Contenido principal
                              _buildIntroSection(isTablet),
                              SizedBox(height: _kSpacing * (isTablet ? 2 : 1.5)),
                              _buildServicesGrid(isTablet),
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

  Widget _buildIntroSection(bool isTablet) {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isTablet ? 1500 : double.infinity),
            child: Text(
              l10n?.servicesIntro ??
                  'Eugenia Travel Consultancy Taxi is the leading taxi booking website that has been helping tourists and residents to find reliable airport transport services. We have been working in the market for many years, we understand the needs & demands of customers and also the expectations of taxi drivers.',
              style: GoogleFonts.exo(
                fontSize: isTablet ? 18 : 16,
                color: const Color(0xFF1A202C),
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildServicesGrid(bool isTablet) {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final services = [
          {
            'icon': Icons.star_outline,
            'title': l10n?.servicesPrivateTransferTitle ?? 'Private Transfer Specialists',
            'description':
                l10n?.servicesPrivateTransferDescription ??
                'Eugenia Travel Consultancy is the airport transfer service providers who have managed the highly interactive and simple to use taxi booking website.',
          },
          {
            'icon': Icons.search,
            'title': l10n?.servicesSimpleBookingTitle ?? 'Simple Booking System',
            'description':
                l10n?.servicesSimpleBookingDescription ??
                'Eugenia Travel Consultancy booking website has the simplest cab booking services. Here is the 3-step process that you have to follow to book your next cab.',
          },
          {
            'icon': Icons.sentiment_satisfied_alt,
            'title': l10n?.servicesCustomerSatisfactionTitle ?? '100% Customer Satisfaction',
            'description':
                l10n?.servicesCustomerSatisfactionDescription ??
                'Our customer is our biggest asset. We will assure that you will be satisfied with the services that you acquire.',
          },
          {
            'icon': Icons.access_time,
            'title': l10n?.servicesWaitingTimeTitle ?? 'Waiting Time',
            'description':
                l10n?.servicesWaitingTimeDescription ??
                'Our customer is our biggest asset. We will assure that you will be satisfied with the services that you acquire.',
          },
          {
            'icon': Icons.handshake_outlined,
            'title': l10n?.servicesMeetGreetTitle ?? 'Meet And Greet Service',
            'description':
                l10n?.servicesMeetGreetDescription ??
                'All pickups from airport comes with Meet and Greet service, it will allow you to easily get out of the airport and be in the cab.',
          },
          {
            'icon': Icons.thumb_up_outlined,
            'title': l10n?.servicesSpecialServicesTitle ?? 'Special Services',
            'description':
                l10n?.servicesSpecialServicesDescription ??
                'All our services are available at a most affordable rate to assure that you will not have to worry about your budget.',
          },
        ];

        if (isTablet) {
          // Grid de 3 columnas en tablet
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: _kSpacing * 2,
              mainAxisSpacing: _kSpacing * 2,
              childAspectRatio: _kCardAspectRatioTablet,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) => _buildServiceCard(services[index], isTablet),
          );
        } else {
          // Grid de 2 columnas en móvil
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: _kSpacing,
              mainAxisSpacing: _kSpacing,
              childAspectRatio: _kCardAspectRatioMobile,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) => _buildServiceCard(services[index], isTablet),
          );
        }
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(isTablet ? _kSpacing * 1.5 : _kSpacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icono circular con fondo azul claro
          Container(
            width: isTablet ? 80 : 64,
            height: isTablet ? 80 : 64,
            decoration: BoxDecoration(
              color: _kPrimaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(
              service['icon'] as IconData,
              color: _kPrimaryColor,
              size: isTablet ? 36 : 28,
            ),
          ),
          SizedBox(height: _kSpacing * 1.2),
          // Título
          Text(
            service['title'] as String,
            style: GoogleFonts.exo(
              fontSize: isTablet ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A202C),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _kSpacing * 0.8),
          // Descripción
          Text(
            service['description'] as String,
            style: GoogleFonts.exo(
              fontSize: isTablet ? 13 : 11,
              color: Colors.grey.shade700,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
