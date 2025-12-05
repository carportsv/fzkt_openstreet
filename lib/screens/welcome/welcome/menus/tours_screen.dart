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
import 'weddings_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla de Tours turísticos
class ToursScreen extends StatefulWidget {
  const ToursScreen({super.key});

  @override
  State<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends State<ToursScreen> {
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
            content: Text('${l10n?.logoutError ?? 'Error al cerrar sesión'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToWelcomePath() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
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
        onNavigateToTours: null,
        onNavigateToWeddings: () {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const WeddingsScreen()));
        },
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
            _buildToursGrid(context),
            const SizedBox(height: _kSpacing * 4),
            _buildWhyChooseUs(context),
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
                Navigator.of(
                  context,
                ).pushReplacement(MaterialPageRoute(builder: (context) => const CompanyScreen()));
              },
              onNavigateToContacts: () {
                Navigator.of(
                  context,
                ).pushReplacement(MaterialPageRoute(builder: (context) => const ContactsScreen()));
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
              onNavigateToTerms: () {
                Navigator.of(
                  context,
                ).pushReplacement(MaterialPageRoute(builder: (context) => const TermsScreen()));
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
                l10n?.whatsappMessageWelcome ?? 'Hola, necesito información sobre tours',
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: _kSpacing * 6, horizontal: _kSpacing * 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimaryColor, _kPrimaryColor.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.tour, size: 80, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: _kSpacing * 2),
          Text(
            l10n?.toursTitle ?? 'Tours Turísticos',
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
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              l10n?.toursSubtitle ??
                  'Descubre la belleza de Sicilia con nuestros tours personalizados',
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

  Widget _buildToursGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    final tours = [
      {
        'icon': Icons.location_city,
        'title': l10n?.toursCityTitle ?? 'Tour por la Ciudad',
        'description': l10n?.toursCityDesc ?? 'Explora los lugares más emblemáticos de Sicilia',
        'duration': l10n?.toursDuration ?? '4 horas',
        'color': Colors.blue,
      },
      {
        'icon': Icons.museum,
        'title': l10n?.toursHistoricalTitle ?? 'Tour Histórico',
        'description': l10n?.toursHistoricalDesc ?? 'Descubre la rica historia y cultura siciliana',
        'duration': l10n?.toursDuration ?? '6 horas',
        'color': Colors.orange,
      },
      {
        'icon': Icons.restaurant,
        'title': l10n?.toursGastronomicTitle ?? 'Tour Gastronómico',
        'description': l10n?.toursGastronomicDesc ?? 'Degusta la auténtica cocina siciliana',
        'duration': l10n?.toursDuration ?? '5 horas',
        'color': Colors.red,
      },
      {
        'icon': Icons.beach_access,
        'title': l10n?.toursCoastalTitle ?? 'Tour Costero',
        'description': l10n?.toursCoastalDesc ?? 'Disfruta de las playas más hermosas',
        'duration': l10n?.toursDuration ?? '8 horas',
        'color': Colors.teal,
      },
      {
        'icon': Icons.landscape,
        'title': l10n?.toursNatureTitle ?? 'Tour Natural',
        'description': l10n?.toursNatureDesc ?? 'Explora la naturaleza y paisajes sicilianos',
        'duration': l10n?.toursDuration ?? '7 horas',
        'color': Colors.green,
      },
      {
        'icon': Icons.wine_bar,
        'title': l10n?.toursWineTitle ?? 'Tour de Vinos',
        'description': l10n?.toursWineDesc ?? 'Visita viñedos y cata vinos locales',
        'duration': l10n?.toursDuration ?? '5 horas',
        'color': Colors.purple,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _kSpacing * 3),
      child: Column(
        children: [
          Text(
            l10n?.toursOurTours ?? 'Nuestros Tours',
            style: GoogleFonts.exo(fontSize: 36, fontWeight: FontWeight.bold, color: _kTextColor),
          ),
          const SizedBox(height: _kSpacing),
          Text(
            l10n?.toursOurToursDesc ?? 'Experiencias únicas diseñadas para ti',
            style: GoogleFonts.exo(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: _kSpacing * 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : (screenWidth > 600 ? 2 : 1),
              crossAxisSpacing: _kSpacing * 2,
              mainAxisSpacing: _kSpacing * 2,
              childAspectRatio: isWide ? 0.85 : 0.9,
            ),
            itemCount: tours.length,
            itemBuilder: (context, index) => _buildTourCard(tours[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildTourCard(Map<String, dynamic> tour) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kBorderRadius * 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con ícono y color
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tour['color'], (tour['color'] as Color).withValues(alpha: 0.7)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(_kBorderRadius * 1.5),
                topRight: Radius.circular(_kBorderRadius * 1.5),
              ),
            ),
            child: Center(child: Icon(tour['icon'], size: 80, color: Colors.white)),
          ),
          // Contenido
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(_kSpacing * 1.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tour['title'],
                    style: GoogleFonts.exo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _kTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: _kSpacing * 0.5),
                  Text(
                    tour['description'],
                    style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        tour['duration'],
                        style: GoogleFonts.exo(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseUs(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_kSpacing * 4),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            l10n?.toursWhyChooseUs ?? '¿Por qué elegirnos?',
            style: GoogleFonts.exo(fontSize: 32, fontWeight: FontWeight.bold, color: _kTextColor),
          ),
          const SizedBox(height: _kSpacing * 3),
          Wrap(
            spacing: _kSpacing * 3,
            runSpacing: _kSpacing * 3,
            alignment: WrapAlignment.center,
            children: [
              _buildFeature(
                Icons.verified_user,
                l10n?.toursFeature1Title ?? 'Guías Profesionales',
                l10n?.toursFeature1Desc ?? 'Expertos locales certificados',
              ),
              _buildFeature(
                Icons.groups,
                l10n?.toursFeature2Title ?? 'Grupos Pequeños',
                l10n?.toursFeature2Desc ?? 'Experiencia personalizada',
              ),
              _buildFeature(
                Icons.star,
                l10n?.toursFeature3Title ?? 'Mejor Valoración',
                l10n?.toursFeature3Desc ?? '5 estrellas en reseñas',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return SizedBox(
      width: 250,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _kPrimaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: _kPrimaryColor),
          ),
          const SizedBox(height: _kSpacing),
          Text(
            title,
            style: GoogleFonts.exo(fontSize: 18, fontWeight: FontWeight.bold, color: _kTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacing * 0.5),
          Text(
            description,
            style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
