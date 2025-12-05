import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/whatsapp_floating_button.dart';
import '../../../../shared/widgets/welcome_footer.dart';
import '../../navbar/welcome_navbar.dart';
import '../../../../auth/login_screen.dart';
import '../welcome_screen.dart';
import 'company_screen.dart';
import 'servicios_screen.dart';
import 'acerca_de_screen.dart';
import 'destinations_screen.dart';
import 'contacts_screen.dart';
import 'tours_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

// Constants
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla de servicios para Matrimonios/Bodas
class WeddingsScreen extends StatefulWidget {
  const WeddingsScreen({super.key});

  @override
  State<WeddingsScreen> createState() => _WeddingsScreenState();
}

class _WeddingsScreenState extends State<WeddingsScreen> {
  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    bool firebaseInitialized = false;
    try {
      firebaseInitialized = Firebase.apps.isNotEmpty;
    } catch (e) {
      firebaseInitialized = false;
    }

    if (!firebaseInitialized) {
      _currentUser = null;
      return;
    }

    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (mounted) {
          setState(() => _currentUser = user);
        }
      });
    } catch (e) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n?.profileComingSoon ?? 'Mi perfil (próximamente)')),
    );
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
            content: Text('${l10n?.logoutError ?? 'Error al cerrar sesión'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToWelcomePath() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: WelcomeNavbar(
        isDarkBackground: false, // Texto negro para fondo claro
        currentUser: _currentUser,
        onNavigateToLogin: _navigateToLogin,
        onNavigateToProfile: _navigateToProfile,
        onHandleLogout: _handleLogout,
        onNavigateToWelcomePath: _navigateToWelcomePath,
        onNavigateToCompany: () {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const CompanyScreen()));
        },
        onNavigateToServices: () {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const ServiciosScreen()));
        },
        onNavigateToAbout: () {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const AcercaDeScreen()));
        },
        onNavigateToDestination: () {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const DestinationsScreen()));
        },
        onNavigateToContacts: () {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const ContactsScreen()));
        },
        onNavigateToTours: () {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const ToursScreen()));
        },
        onNavigateToWeddings: null, // Ya estamos en esta pantalla
        onNavigateToTerms: () {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const TermsScreen()));
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(context),
            const SizedBox(height: _kSpacing * 4),
            _buildServicesSection(context),
            const SizedBox(height: _kSpacing * 4),
            _buildPackagesSection(context),
            const SizedBox(height: _kSpacing * 4),
            // Footer
            WelcomeFooter(
              onNavigateToWelcome: _navigateToWelcomePath,
              onNavigateToDestination: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const DestinationsScreen()),
                );
              },
              onNavigateToCompany: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const CompanyScreen()),
                );
              },
              onNavigateToContacts: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ContactsScreen()),
                );
              },
              onNavigateToServices: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ServiciosScreen()),
                );
              },
              onNavigateToAbout: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AcercaDeScreen()),
                );
              },
              onNavigateToTerms: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const TermsScreen()),
                );
              },
              onNavigateToPrivacy: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return WhatsAppFloatingButton(
            prefilledMessage:
                l10n?.whatsappMessageWelcome ??
                'Hola, necesito información sobre servicios para bodas',
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: _kSpacing * 8, horizontal: _kSpacing * 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink.shade400, Colors.pink.shade600],
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.favorite, size: 80, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: _kSpacing * 2),
          Text(
            l10n?.weddingsTitle ?? 'Bodas & Eventos Especiales',
            style: GoogleFonts.exo(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacing),
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              l10n?.weddingsSubtitle ??
                  'Hacemos de tu día especial una experiencia inolvidable con nuestro servicio premium de transporte',
              style: GoogleFonts.exo(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.95),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final services = [
      {
        'icon': Icons.directions_car,
        'title': l10n?.weddingsServiceTransportTitle ?? 'Transporte de Novios',
        'description':
            l10n?.weddingsServiceTransportDesc ??
            'Vehículos de lujo para el traslado de los novios',
      },
      {
        'icon': Icons.airport_shuttle,
        'title': l10n?.weddingsServiceGuestsTitle ?? 'Traslado de Invitados',
        'description': l10n?.weddingsServiceGuestsDesc ?? 'Minibuses y vans para tus invitados',
      },
      {
        'icon': Icons.celebration,
        'title': l10n?.weddingsServiceReceptionTitle ?? 'Servicio de Recepción',
        'description':
            l10n?.weddingsServiceReceptionDesc ?? 'Transporte desde la ceremonia a la recepción',
      },
      {
        'icon': Icons.local_hotel,
        'title': l10n?.weddingsServiceHotelTitle ?? 'Traslado al Hotel',
        'description':
            l10n?.weddingsServiceHotelDesc ?? 'Servicio nocturno para novios e invitados',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _kSpacing * 3),
      child: Column(
        children: [
          Text(
            l10n?.weddingsOurServices ?? 'Nuestros Servicios',
            style: GoogleFonts.exo(fontSize: 36, fontWeight: FontWeight.bold, color: _kTextColor),
          ),
          const SizedBox(height: _kSpacing * 3),
          ...services.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: _kSpacing * 2),
              child: _buildServiceCard(service),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Container(
      padding: const EdgeInsets.all(_kSpacing * 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(_kBorderRadius),
            ),
            child: Icon(service['icon'], size: 35, color: Colors.pink.shade400),
          ),
          const SizedBox(width: _kSpacing * 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['title'],
                  style: GoogleFonts.exo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  service['description'],
                  style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_kSpacing * 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.pink.shade50, Colors.white],
        ),
      ),
      child: Column(
        children: [
          Text(
            l10n?.weddingsPackages ?? 'Paquetes Personalizados',
            style: GoogleFonts.exo(fontSize: 36, fontWeight: FontWeight.bold, color: _kTextColor),
          ),
          const SizedBox(height: _kSpacing),
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              l10n?.weddingsPackagesDesc ??
                  'Creamos paquetes a medida según el número de invitados y tus necesidades específicas',
              style: GoogleFonts.exo(fontSize: 16, color: Colors.grey.shade600, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: _kSpacing * 3),
          ElevatedButton.icon(
            onPressed: () {
              // Abrir WhatsApp para consultas
            },
            icon: const Icon(Icons.phone, size: 20),
            label: Text(
              l10n?.weddingsContactUs ?? 'Contáctanos para cotización',
              style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: _kSpacing * 3,
                vertical: _kSpacing * 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius)),
              elevation: 6,
            ),
          ),
        ],
      ),
    );
  }
}
