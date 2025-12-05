import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../l10n/app_localizations.dart';

// Constants
const _kSpacing = 16.0;
const _kFooterBgColor = Color(0xFF2C3E50);

/// Footer para WelcomeScreen
class WelcomeFooter extends StatelessWidget {
  final VoidCallback? onNavigateToWelcome;
  final VoidCallback? onNavigateToDestination;
  final VoidCallback? onNavigateToCompany;
  final VoidCallback? onNavigateToContacts;
  final VoidCallback? onNavigateToServices;
  final VoidCallback? onNavigateToAbout;
  final VoidCallback? onNavigateToTerms;
  final VoidCallback? onNavigateToPrivacy;

  const WelcomeFooter({
    super.key,
    this.onNavigateToWelcome,
    this.onNavigateToDestination,
    this.onNavigateToCompany,
    this.onNavigateToContacts,
    this.onNavigateToServices,
    this.onNavigateToAbout,
    this.onNavigateToTerms,
    this.onNavigateToPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 900;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _kFooterBgColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(30),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? _kSpacing * 4 : _kSpacing * 2,
          vertical: _kSpacing * 0.002,
        ),
        child: Column(
          children: [
            // Contenido principal del footer
            isTablet ? _buildWideLayout(context) : _buildNarrowLayout(context),
            const SizedBox(height: _kSpacing * 0.002),
            // Línea divisoria
            Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
            const SizedBox(height: _kSpacing * 0.002),
            // Copyright
            _buildCopyright(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Columna 1: Logo - 20%
            SizedBox(
              width: totalWidth * 0.20,
              child: Align(
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/logo_21.png',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 30),
                    );
                  },
                ),
              ),
            ),
            // Columna 2: Solo iconos de redes sociales - 40%
            SizedBox(
              width: totalWidth * 0.40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_buildSocialMedia(context)],
              ),
            ),
            // Columna 3: Descripción en 2 filas + Términos debajo - 40%
            SizedBox(
              width: totalWidth * 0.40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Fila 1: Primera descripción
                  Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.footerDescription1 ??
                            'Tu solución definitiva para traslados confiables, elegantes y personalizados.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.6,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: _kSpacing * 0.5),
                  // Fila 2: Segunda descripción
                  Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.footerDescription2 ??
                            'Disponible 24/7 para llevarte a donde necesites.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.6,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: _kSpacing * 1.5),
                  // Fila 3: Iconos de Términos y Privacy Policy (lado a lado)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Términos y Condiciones
                      if (onNavigateToTerms != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onNavigateToTerms,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Builder(
                                    builder: (context) {
                                      final l10n = AppLocalizations.of(context);
                                      return Text(
                                        l10n?.termsTitle ?? 'Términos',
                                        style: GoogleFonts.exo(
                                          fontSize: 13,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white.withValues(alpha: 0.7),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 20),
                      // Privacy Policy (NUEVO)
                      if (onNavigateToPrivacy != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onNavigateToPrivacy,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.privacy_tip_outlined,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Builder(
                                    builder: (context) {
                                      final l10n = AppLocalizations.of(context);
                                      return Text(
                                        l10n?.privacyTitle ?? 'Privacy',
                                        style: GoogleFonts.exo(
                                          fontSize: 13,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white.withValues(alpha: 0.7),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo arriba
        Image.asset(
          'assets/images/logo_21.png',
          width: 130,
          height: 130,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 30),
            );
          },
        ),
        const SizedBox(height: _kSpacing * 1),
        // 4 filas abajo
        _buildRightColumn(context),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Descripción
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Text(
              '${l10n?.footerDescription1 ?? 'Tu solución definitiva para traslados confiables, elegantes y personalizados.'} ${l10n?.footerDescription2 ?? 'Disponible 24/7 para llevarte a donde necesites.'}',
              style: GoogleFonts.exo(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.6,
              ),
            );
          },
        ),
        const SizedBox(height: _kSpacing * 1),
        // Redes sociales
        _buildSocialMedia(context),
      ],
    );
  }

  Widget _buildSocialMedia(BuildContext context) {
    return Wrap(
      spacing: _kSpacing * 3,
      runSpacing: _kSpacing * 3,
      alignment: WrapAlignment.start,
      children: [
        _buildSocialButton(
          icon: FontAwesomeIcons.facebook,
          onTap: () => _launchUrl('https://www.facebook.com/mytransfertrip'),
        ),
        _buildSocialButton(
          icon: FontAwesomeIcons.instagram,
          onTap: () => _launchUrl('https://www.instagram.com/eugeniastravel_'),
        ),
        _buildSocialButton(
          icon: FontAwesomeIcons.xTwitter,
          onTap: () => _launchUrl('https://x.com/lasiciliatourr'),
        ),
        _buildSocialButton(
          icon: FontAwesomeIcons.tiktok,
          onTap: () => _launchUrl('https://www.tiktok.com/@eugeniastravel'),
        ),
        _buildSocialButton(
          icon: FontAwesomeIcons.linkedin,
          onTap: () => _launchUrl(
            'https://www.linkedin.com/in/eugenia-s-travel-la-sicilia-tour-group-8627a2202/',
          ),
        ),
        _buildSocialButton(
          icon: FontAwesomeIcons.whatsapp,
          onTap: () => _launchUrl('http://wa.me/393921774905'),
        ),
      ],
    );
  }

  Widget _buildSocialButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
          ),
          child: Center(child: FaIcon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }

  Widget _buildCopyright(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.exo(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: l10n != null
                  ? l10n.footerCopyright(DateTime.now().year)
                  : 'Copyright © ${DateTime.now().year} Todos los derechos reservados | desarrollado por ',
            ),
            TextSpan(
              text: 'carportsv',
              style: GoogleFonts.exo(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.5,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl('https://www.linkedin.com/in/carportsv/'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
