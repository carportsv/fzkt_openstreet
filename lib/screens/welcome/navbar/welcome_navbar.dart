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
const _kBorderRadius = 12.0;

/// Navbar para WelcomeScreen
/// Extraída del welcome_screen.dart para mejor organización
class WelcomeNavbar extends StatelessWidget implements PreferredSizeWidget {
  final User? currentUser;
  final VoidCallback onNavigateToLogin;
  final VoidCallback onNavigateToProfile;
  final Future<void> Function() onHandleLogout;
  final VoidCallback onNavigateToWelcomePath;

  const WelcomeNavbar({
    super.key,
    required this.currentUser,
    required this.onNavigateToLogin,
    required this.onNavigateToProfile,
    required this.onHandleLogout,
    required this.onNavigateToWelcomePath,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Widget _buildNavItem(String text, VoidCallback onTap) {
    return HoverableNavItem(text: text, onTap: onTap);
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
                style: GoogleFonts.exo(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onNavigateToLogin,
              child: Text(
                l10n?.login ?? 'Iniciar sesión',
                style: GoogleFonts.exo(
                  color: Colors.white,
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
              : 'Servicio';
          final navRates = (l10n != null && !l10n.navRates.startsWith('nav.'))
              ? l10n.navRates
              : 'Tarifas';
          final navDestination = (l10n != null && !l10n.navDestination.startsWith('nav.'))
              ? l10n.navDestination
              : 'Destino';
          final navContacts = (l10n != null && !l10n.navContacts.startsWith('nav.'))
              ? l10n.navContacts
              : 'Contactos';

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildNavItem(navHome, () {
                // Navegar a /welcome
                if (kIsWeb) {
                  // En web, simplemente recargar la página si ya estamos en /welcome
                  // o navegar usando el método estándar
                  final currentPath = Uri.base.path;
                  if (currentPath == '/welcome' || currentPath.endsWith('/welcome')) {
                    // Si ya estamos en /welcome, no hacer nada
                    return;
                  } else {
                    // Navegar a /welcome usando una solución compatible
                    // Usar un método que no requiera dart:html directamente
                    onNavigateToWelcomePath();
                  }
                }
              }),
              const SizedBox(width: 20),
              _buildNavItem(navCompany, () {}),
              const SizedBox(width: 20),
              _buildNavItem(navService, () {}),
              const SizedBox(width: 20),
              _buildNavItem(navRates, () {}),
              const SizedBox(width: 20),
              _buildNavItem(navDestination, () {}),
              const SizedBox(width: 20),
              _buildNavItem(navContacts, () {}),
            ],
          );
        },
      ),
      actions: [
        // Si hay usuario autenticado, mostrar menú de usuario
        if (currentUser != null) ...[
          // Menú de usuario con estilo profesional
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kBorderRadius)),
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Foto de perfil o icono
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: currentUser!.photoURL != null
                        ? NetworkImage(currentUser!.photoURL!)
                        : null,
                    onBackgroundImageError: (exception, stackTrace) {
                      // Manejar errores de carga de imagen silenciosamente
                      // El fallback (child) se mostrará automáticamente
                    },
                    child: currentUser!.photoURL == null
                        ? const Icon(Icons.person, color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // Nombre del usuario
                  Text(
                    currentUser!.displayName ?? currentUser!.email?.split('@').first ?? 'Usuario',
                    style: GoogleFonts.exo(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                ],
              ),
            ),
            itemBuilder: (BuildContext context) => [
              // Información del usuario
              PopupMenuItem<String>(
                enabled: false,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _kPrimaryColor.withValues(alpha: 0.1),
                      backgroundImage: currentUser!.photoURL != null
                          ? NetworkImage(currentUser!.photoURL!)
                          : null,
                      onBackgroundImageError: (exception, stackTrace) {
                        // Manejar errores de carga de imagen silenciosamente
                        // El fallback (child) se mostrará automáticamente
                      },
                      child: currentUser!.photoURL == null
                          ? Icon(Icons.person, color: _kPrimaryColor, size: 24)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser!.displayName ??
                                currentUser!.email?.split('@').first ??
                                'Usuario',
                            style: GoogleFonts.exo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _kTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (currentUser!.email != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              currentUser!.email!,
                              style: GoogleFonts.exo(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuDivider(height: 1, color: Colors.grey.shade200),
              // Opción Perfil
              PopupMenuItem<String>(
                value: 'profile',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.person, color: _kPrimaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.myProfile ?? 'Mi Perfil',
                              style: GoogleFonts.exo(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _kTextColor,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Opción Cerrar sesión
              PopupMenuItem<String>(
                value: 'logout',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.logout ?? 'Cerrar sesión',
                              style: GoogleFonts.exo(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade600,
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
