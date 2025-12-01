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
import 'contacts_screen.dart';
import '../../../auth/login_screen.dart';
import '../../../widgets/app_logo_header.dart';

// Constants
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla de información de la empresa
class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
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
        debugPrint('[CompanyScreen] ⚠️ Error verificando Firebase: $e');
      }
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint('[CompanyScreen] ⚠️ Firebase no inicializado');
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
        debugPrint('[CompanyScreen] ⚠️ Error obteniendo usuario: $e');
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
      debugPrint('[CompanyScreen] _navigateToWelcomePath llamado');
      debugPrint('[CompanyScreen] Context mounted: $mounted');
    }

    if (!mounted) {
      if (kDebugMode) {
        debugPrint('[CompanyScreen] ⚠️ Context no está montado, no se puede navegar');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[CompanyScreen] Navegando a WelcomeScreen');
      }
      // Usar pushReplacement para reemplazar la pantalla actual
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      if (kDebugMode) {
        debugPrint('[CompanyScreen] ✅ Navegación iniciada');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[CompanyScreen] ❌ Error navegando a WelcomeScreen: $e');
        debugPrint('[CompanyScreen] Stack trace: $stackTrace');
      }
      // Fallback: intentar con push normal
      try {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[CompanyScreen] ❌ Error en fallback también: $e2');
        }
      }
    }
  }

  void _navigateToCompany() {
    // Ya estamos en la pantalla de empresa
  }

  void _navigateToDestination() {
    // Navegar a destinos si es necesario
    if (kDebugMode) {
      debugPrint('[CompanyScreen] _navigateToDestination llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const DestinationsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CompanyScreen] ❌ Error navegando a DestinationsScreen: $e');
      }
    }
  }

  void _navigateToContacts() {
    if (kDebugMode) {
      debugPrint('[CompanyScreen] _navigateToContacts llamado');
    }
    if (!mounted) return;
    try {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => const ContactsScreen()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CompanyScreen] ❌ Error navegando a ContactsScreen: $e');
      }
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
          Column(
            children: [
              // Contenido principal
              Expanded(
                child: Stack(
                  children: [
                    // Imagen de fondo
                    Positioned.fill(
                      child: Image.asset(
                        'images/empresa/pared.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade800,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey.shade600,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Imagen no disponible',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Overlay oscuro para mejor legibilidad
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF1C1C1C).withValues(alpha: 0.4),
                            const Color(0xFF000000).withValues(alpha: 0.5),
                          ],
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
                                // Contenido principal
                                isTablet ? _buildWideLayout() : _buildNarrowLayout(),
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Logo flotante
          const AppLogoHeader(),
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
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kBorderRadius),
              child: Image.asset(
                'images/empresa/oficina.png',
                fit: BoxFit.cover,
                height: 350,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 350,
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
        // Texto a la derecha
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
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kBorderRadius),
            child: Image.asset(
              'images/empresa/oficina.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
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
        // Texto abajo
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'La nostra azienda',
          style: GoogleFonts.exo(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: _kSpacing * 2),
        Text(
          'Benvenuto a Eugenia\'s Travel Consultancy, la tua soluzione definitiva per trasferimenti affidabili, eleganti e personalizzati. Con radici in Sicilia, Italia, portiamo la calda ospitalità siciliana e il fascino mediterraneo in ogni viaggio. Ci specializziamo nel fornire esperienze di trasporto eccezionali che combinano comfort, efficienza e attenzione ai dettagli.',
          style: GoogleFonts.exo(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.8,
          ),
        ),
        const SizedBox(height: _kSpacing * 2),
        // Características
        _buildFeatures(),
      ],
    );
  }

  Widget _buildFeatures() {
    return Column(
      children: [
        _buildFeature(
          icon: Icons.access_time,
          title: 'Puntualità',
          description:
              'La puntualità riflette impegno ed efficienza, assicurando che i servizi vengano rispettati con precisione al momento stabilito.',
        ),
        const SizedBox(height: _kSpacing * 2),
        _buildFeature(
          icon: Icons.person_outline,
          title: 'Autisti Professionisti',
          description:
              'I nostri autisti professionisti si distinguono per esperienza e dedizione, offrendo un servizio sicuro e di alta qualità.',
        ),
        const SizedBox(height: _kSpacing * 2),
        _buildFeature(
          icon: Icons.security,
          title: 'Sicurezza',
          description:
              'La sicurezza nei viaggi e nella logistica integrale riflette il nostro impegno per la tranquillità e il benessere dei nostri clienti.',
        ),
        const SizedBox(height: _kSpacing * 2),
        _buildFeature(
          icon: Icons.verified,
          title: 'Azienda Affidabile',
          description:
              'Siamo un\'azienda affidabile che unisce esperienza e professionalità per offrire un servizio di qualità e garantire la soddisfazione dei nostri clienti.',
        ),
      ],
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(width: _kSpacing * 1.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.exo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: _kSpacing * 0.5),
              Text(
                description,
                style: GoogleFonts.exo(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
