import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/locale_provider.dart';
import 'hoverable_nav_item.dart';
import 'language_selector.dart';

// Constants (copiadas de welcome_screen.dart)
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);

/// Navbar para WelcomeScreen
/// Extraída del welcome_screen.dart para mejor organización
class WelcomeNavbar extends StatelessWidget implements PreferredSizeWidget {
  final User? currentUser;
  final VoidCallback onNavigateToLogin;
  final VoidCallback onNavigateToProfile;
  final Future<void> Function() onHandleLogout;
  final VoidCallback onNavigateToWelcomePath;
  final VoidCallback? onNavigateToCompany;
  final VoidCallback? onNavigateToServices;
  final VoidCallback? onNavigateToAbout;
  final VoidCallback? onNavigateToDestination;
  final VoidCallback? onNavigateToContacts;
  final VoidCallback? onNavigateToTours;
  final VoidCallback? onNavigateToWeddings;
  final VoidCallback? onNavigateToTerms;
  final bool isDarkBackground; // Si es true, usa texto blanco; si es false, usa texto negro

  const WelcomeNavbar({
    super.key,
    required this.currentUser,
    required this.onNavigateToLogin,
    required this.onNavigateToProfile,
    required this.onHandleLogout,
    required this.onNavigateToWelcomePath,
    this.onNavigateToCompany,
    this.onNavigateToServices,
    this.onNavigateToAbout,
    this.onNavigateToDestination,
    this.onNavigateToContacts,
    this.onNavigateToTours,
    this.onNavigateToWeddings,
    this.onNavigateToTerms,
    this.isDarkBackground = true, // Por defecto texto blanco
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Widget _buildNavItem(String text, VoidCallback onTap) {
    return HoverableNavItem(
      text: text,
      onTap: onTap,
      textColor: isDarkBackground ? Colors.white : Colors.black87,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtener idioma seleccionado del LocaleProvider (escuchar cambios)
    final localeProvider = Provider.of<LocaleProvider>(context, listen: true);
    final selectedLanguage = localeProvider.locale.languageCode;

    // Widget común para selector de idioma (siempre visible)
    final languageSelector = Padding(
      padding: const EdgeInsets.only(right: 12),
      child: LanguageSelectorWidget(
        selectedLanguage: selectedLanguage,
        onLanguageChanged: (language) {
          // Cambiar el idioma globalmente usando LocaleProvider
          final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
          localeProvider.setLocaleFromCode(language);
          if (kDebugMode) {
            debugPrint('[WelcomeNavbar] Idioma cambiado a: $language');
          }
        },
      ),
    );

    // Widget común para botones de login/registro (siempre visibles)
    final textColor = isDarkBackground ? Colors.white : Colors.black87;
    final loginButtons = Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onNavigateToLogin,
              child: Text(
                l10n?.register ?? 'Regístrate',
                style: GoogleFonts.exo(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onNavigateToLogin,
              child: Text(
                l10n?.login ?? 'Iniciar sesión',
                style: GoogleFonts.exo(
                  color: textColor,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      },
    );

    return AppBar(
      backgroundColor: Colors.transparent, // Navbar transparente
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Barra de estado transparente
        statusBarIconBrightness: Brightness.light, // Iconos claros para barra de estado
      ),
      title: LayoutBuilder(
        builder: (context, constraints) {
          // En pantallas pequeñas, ocultar el menú de navegación
          if (constraints.maxWidth < 600) {
            return const SizedBox.shrink();
          }
          // En pantallas grandes, mostrar el menú de navegación a la derecha
          final l10n = AppLocalizations.of(context);
          // Validar que las traducciones no sean claves (empiezan con 'nav.' o 'form.')
          final navHome = (l10n != null && !l10n.navHome.startsWith('nav.'))
              ? l10n.navHome
              : 'Inicio';
          final navCompany = (l10n != null && !l10n.navCompany.startsWith('nav.'))
              ? l10n.navCompany
              : 'Empresa';
          final navService = (l10n != null && !l10n.navService.startsWith('nav.'))
              ? l10n.navService
              : 'Servicios';
          final navRates = (l10n != null && !l10n.navRates.startsWith('nav.'))
              ? l10n.navRates
              : 'Profesionalismo';
          final navDestination = (l10n != null && !l10n.navDestination.startsWith('nav.'))
              ? l10n.navDestination
              : 'Destinos';
          final navContacts = (l10n != null && !l10n.navContacts.startsWith('nav.'))
              ? l10n.navContacts
              : 'Contactos';
          final navTours = (l10n != null && !l10n.navTours.startsWith('nav.'))
              ? l10n.navTours
              : 'Tours';
          final navWeddings = (l10n != null && !l10n.navWeddings.startsWith('nav.'))
              ? l10n.navWeddings
              : 'Bodas';

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 1. Inicio
              _buildNavItem(navHome, () {
                onNavigateToWelcomePath();
              }),
              const SizedBox(width: 20),
              // 2. Destinos
              _buildNavItem(navDestination, () {
                if (onNavigateToDestination != null) {
                  onNavigateToDestination!();
                }
              }),
              const SizedBox(width: 20),
              // 3. Servicios
              _buildNavItem(navService, () {
                if (onNavigateToServices != null) {
                  onNavigateToServices!();
                }
              }),
              const SizedBox(width: 20),
              // 4. Tours
              _buildNavItem(navTours, () {
                if (onNavigateToTours != null) {
                  onNavigateToTours!();
                }
              }),
              const SizedBox(width: 20),
              // 5. Bodas/Matrimoni
              _buildNavItem(navWeddings, () {
                if (onNavigateToWeddings != null) {
                  onNavigateToWeddings!();
                }
              }),
              const SizedBox(width: 20),
              // 6. Profesionalidad (Acerca de)
              _buildNavItem(navRates, () {
                if (onNavigateToAbout != null) {
                  onNavigateToAbout!();
                }
              }),
              const SizedBox(width: 20),
              // 7. Empresa
              _buildNavItem(navCompany, () {
                if (onNavigateToCompany != null) {
                  onNavigateToCompany!();
                }
              }),
              const SizedBox(width: 20),
              // 8. Contactos
              _buildNavItem(navContacts, () {
                if (onNavigateToContacts != null) {
                  onNavigateToContacts!();
                }
              }),
            ],
          );
        },
      ),
      actions: [
        // Si hay usuario autenticado, mostrar menú de usuario
        if (currentUser != null) ...[
          // Menú de usuario con estilo profesional mejorado
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Foto de perfil o icono con borde
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: textColor.withValues(alpha: 0.5), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: textColor.withValues(alpha: 0.2),
                      backgroundImage: currentUser!.photoURL != null
                          ? NetworkImage(currentUser!.photoURL!)
                          : null,
                      onBackgroundImageError: (exception, stackTrace) {
                        // Manejar errores de carga de imagen silenciosamente
                      },
                      child: currentUser!.photoURL == null
                          ? Icon(Icons.person, color: textColor, size: 20)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Nombre del usuario
                  Text(
                    currentUser!.displayName ?? currentUser!.email?.split('@').first ?? 'Usuario',
                    style: GoogleFonts.exo(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: textColor.withValues(alpha: 0.9),
                    size: 20,
                  ),
                ],
              ),
            ),
            itemBuilder: (BuildContext context) => [
              // Header con información del usuario - mejorado
              PopupMenuItem<String>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _kPrimaryColor.withValues(alpha: 0.05),
                        _kPrimaryColor.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Avatar más grande con sombra
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _kPrimaryColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: _kPrimaryColor.withValues(alpha: 0.1),
                          backgroundImage: currentUser!.photoURL != null
                              ? NetworkImage(currentUser!.photoURL!)
                              : null,
                          onBackgroundImageError: (exception, stackTrace) {},
                          child: currentUser!.photoURL == null
                              ? Icon(Icons.person, color: _kPrimaryColor, size: 32)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser!.displayName ??
                                  currentUser!.email?.split('@').first ??
                                  'Usuario',
                              style: GoogleFonts.exo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _kTextColor,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentUser!.email != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      currentUser!.email!,
                                      style: GoogleFonts.exo(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                        letterSpacing: 0.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Separador elegante
              PopupMenuDivider(height: 1, color: Colors.grey.shade200),
              // Opción Perfil - mejorada
              PopupMenuItem<String>(
                value: 'profile',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context);
                      onNavigateToProfile();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _kPrimaryColor.withValues(alpha: 0.15),
                                  _kPrimaryColor.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_outline, color: _kPrimaryColor, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n?.myProfile ?? 'Mi Perfil',
                                  style: GoogleFonts.exo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _kTextColor,
                                    letterSpacing: 0.2,
                                  ),
                                );
                              },
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Opción Cerrar sesión - mejorada
              PopupMenuItem<String>(
                value: 'logout',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context);
                      onHandleLogout();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade50,
                                  Colors.red.shade50.withValues(alpha: 0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n?.logout ?? 'Cerrar sesión',
                                  style: GoogleFonts.exo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade600,
                                    letterSpacing: 0.2,
                                  ),
                                );
                              },
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            onSelected: (String value) {
              if (value == 'profile') {
                onNavigateToProfile();
              } else if (value == 'logout') {
                onHandleLogout();
              }
            },
          ),
          const SizedBox(width: 12),
        ],
        // Botones de login/registro (solo si NO hay usuario autenticado)
        if (currentUser == null) ...[loginButtons, const SizedBox(width: 12)],
        // Selector de idioma (siempre visible)
        languageSelector,
      ],
    );
  }
}
