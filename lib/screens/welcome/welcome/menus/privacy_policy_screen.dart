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
import 'weddings_screen.dart';
import 'terms_screen.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla de Privacy Policy
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
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
      backgroundColor: Colors.white,
      appBar: WelcomeNavbar(
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
            _buildHeader(context),
            const SizedBox(height: _kSpacing * 3),
            _buildContent(context),
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
              onNavigateToPrivacy: null, // Ya estamos aquí
            ),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return WhatsAppFloatingButton(
            prefilledMessage:
                l10n?.whatsappMessageWelcome ?? 'Hola, tengo una consulta sobre privacidad',
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: _kSpacing * 5, horizontal: _kSpacing * 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Column(
        children: [
          Icon(Icons.privacy_tip_outlined, size: 60, color: _kPrimaryColor),
          const SizedBox(height: _kSpacing * 2),
          Text(
            l10n?.privacyTitle ?? 'Privacy Policy',
            style: GoogleFonts.exo(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: _kTextColor,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacing),
          Text(
            l10n?.privacyLastUpdate ?? 'Last update: December 2024',
            style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      padding: const EdgeInsets.symmetric(horizontal: _kSpacing * 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Introduction
          _buildSection(
            l10n?.privacyPolicyTitle ?? 'The Policy',
            l10n?.privacyIntro ??
                'This privacy policy notice is served by Eugenia Travel Consultancy & Italy under the website https://www.eugeniastravelconsultancy.com. The purpose of this policy is to explain to you how we control, process, handle and protect your personal information through the business and while you browse or use this website.',
          ),
          const SizedBox(height: _kSpacing * 3),

          // Definitions
          _buildSection(
            l10n?.privacyDefinitionsTitle ?? 'Policy Key Definitions',
            '',
          ),
          _buildBullet(l10n?.privacyDefWe ?? '"I", "our", "us", or "we" refer to the business, Eugenia Travel Consultancy.'),
          _buildBullet(l10n?.privacyDefYou ?? '"you", "the user" refer to the person(s) using this website.'),
          _buildBullet(l10n?.privacyDefGDPR ?? 'GDPR means General Data Protection Act.'),
          _buildBullet(l10n?.privacyDefPECR ?? 'PECR means Privacy & Electronic Communications Regulation.'),
          _buildBullet(l10n?.privacyDefCookies ?? 'Cookies mean small files stored on a users computer or device.'),
          const SizedBox(height: _kSpacing * 3),

          // GDPR Principles
          _buildSection(
            l10n?.privacyGDPRTitle ?? 'Key Principles of GDPR',
            l10n?.privacyGDPRContent ?? 'Our privacy policy embodies the following key principles: (a) Lawfulness, fairness and transparency, (b) Purpose limitation, (c) Data minimisation, (d) Accuracy, (e) Storage limitation, (f) Integrity and confidence, (g) Accountability.',
          ),
          const SizedBox(height: _kSpacing * 3),

          // Your Rights
          _buildSection(
            l10n?.privacyRightsTitle ?? 'Your Individual Rights',
            l10n?.privacyRightsIntro ?? 'Under the GDPR your rights are as follows:',
          ),
          _buildBullet(l10n?.privacyRight1 ?? 'the right to be informed'),
          _buildBullet(l10n?.privacyRight2 ?? 'the right of access'),
          _buildBullet(l10n?.privacyRight3 ?? 'the right to rectification'),
          _buildBullet(l10n?.privacyRight4 ?? 'the right to erasure'),
          _buildBullet(l10n?.privacyRight5 ?? 'the right to restrict processing'),
          _buildBullet(l10n?.privacyRight6 ?? 'the right to data portability'),
          _buildBullet(l10n?.privacyRight7 ?? 'the right to object'),
          _buildBullet(l10n?.privacyRight8 ?? 'the right not to be subject to automated decision-making including profiling'),
          const SizedBox(height: _kSpacing * 3),

          // Cookies
          _buildSection(
            l10n?.privacyCookiesTitle ?? 'Internet Cookies',
            l10n?.privacyCookiesContent ?? 'We use cookies on this website to provide you with a better user experience. We do this by placing a small text file on your device / computer hard drive to track how you use the website, to record or log whether you have seen particular messages that we display, to keep you logged into the website where applicable, to display relevant adverts or content.',
          ),
          const SizedBox(height: _kSpacing * 3),

          // Data Security
          _buildSection(
            l10n?.privacySecurityTitle ?? 'Data Security and Protection',
            l10n?.privacySecurityContent ?? 'We ensure the security of any personal information we hold by using secure data storage technologies and precise procedures in how we store, access and manage that information. Our methods meet the GDPR compliance requirement.',
          ),
          const SizedBox(height: _kSpacing * 3),

          // Email Marketing
          _buildSection(
            l10n?.privacyEmailTitle ?? 'Email Marketing Messages & Subscription',
            l10n?.privacyEmailContent ?? 'Under the GDPR we use the consent lawful basis for anyone subscribing to our newsletter or marketing mailing list. We only collect certain data about you. Any email marketing messages we send are done so through an EMS, email marketing service provider.',
          ),
          const SizedBox(height: _kSpacing * 4),

          _buildContactBox(context),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.exo(fontSize: 22, fontWeight: FontWeight.bold, color: _kTextColor),
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: _kSpacing),
          Text(
            content,
            style: GoogleFonts.exo(fontSize: 15, color: Colors.grey.shade700, height: 1.8),
            textAlign: TextAlign.justify,
          ),
        ],
      ],
    );
  }

  Widget _buildBullet(String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.exo(fontSize: 15, color: Colors.grey.shade700)),
          Expanded(
            child: Text(
              content,
              style: GoogleFonts.exo(fontSize: 15, color: Colors.grey.shade700, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactBox(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_kSpacing * 3),
      decoration: BoxDecoration(
        color: _kPrimaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(_kBorderRadius),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.contact_support, size: 50, color: _kPrimaryColor),
          const SizedBox(height: _kSpacing),
          Text(
            l10n?.privacyQuestions ?? '¿Preguntas sobre privacidad?',
            style: GoogleFonts.exo(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacing),
          Text(
            l10n?.privacyContactUs ?? 'Contáctanos y estaremos encantados de ayudarte',
            style: GoogleFonts.exo(fontSize: 15, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

