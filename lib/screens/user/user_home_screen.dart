import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_logo_header.dart';
import '../welcome/welcome/welcome_screen.dart';
import '../welcome/welcome/request_ride_screen.dart';

// Constants
const _kPrimaryColor = Color(0xFF1D4ED8);
const _kTextColor = Color(0xFF1A202C);
const _kSpacing = 16.0;
const _kBorderRadius = 12.0;

/// Pantalla principal del usuario
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  void _checkAuthentication() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && mounted) {
      // Si no está autenticado, redirigir a WelcomeScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => const WelcomeScreen()));
        }
      });
    }
  }

  // Handle logout with proper error handling
  Future<void> _handleLogout(BuildContext context) async {
    try {
      debugPrint('[UserHomeScreen] Iniciando cierre de sesión...');

      // 1. Cerrar sesión de Firebase primero
      await FirebaseAuth.instance.signOut();
      debugPrint('[UserHomeScreen] ✅ Sesión de Firebase cerrada');

      // 2. Esperar un momento para que Firebase procese el logout
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Cerrar sesión de Google Sign-In también
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        await googleSignIn.signOut();
        debugPrint('[UserHomeScreen] ✅ Sesión de Google Sign-In cerrada');
      } catch (e) {
        debugPrint('[UserHomeScreen] ⚠️ Error al cerrar sesión de Google: ${e.toString()}');
        // Continuar aunque falle Google Sign-In
      }

      // 4. Esperar un momento adicional para asegurar que todo se limpie
      await Future.delayed(const Duration(milliseconds: 300));

      // 5. Navegar a WelcomeScreen y limpiar el stack de navegación
      if (context.mounted) {
        debugPrint('[UserHomeScreen] 🚀 Navegando a WelcomeScreen...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Show error message if logout fails
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: _kPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Historial de Viajes',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Historial de viajes (próximamente)')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: 'Mi Perfil',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Mi perfil (próximamente)')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, _kPrimaryColor.withValues(alpha: 0.03)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    _buildHeader(context),
                    const SizedBox(height: _kSpacing * 3),

                    // Main Content - Botón para solicitar viaje
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(_kSpacing * 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_kBorderRadius * 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: _kPrimaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.directions_car, size: 50, color: _kPrimaryColor),
                          ),
                          const SizedBox(height: _kSpacing * 2),
                          Text(
                            '¿Listo para tu próximo viaje?',
                            style: GoogleFonts.exo(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _kTextColor,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: _kSpacing),
                          Text(
                            'Solicita un viaje de manera rápida y fácil',
                            style: GoogleFonts.exo(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: _kSpacing * 3),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const RequestRideScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kPrimaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(_kBorderRadius),
                                ),
                                elevation: 3,
                                shadowColor: _kPrimaryColor.withValues(alpha: 0.4),
                              ),
                              child: Text(
                                'Solicitar Viaje',
                                style: GoogleFonts.exo(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: _kSpacing * 3),

                    // Features Section
                    _buildFeaturesSection(),
                  ],
                ),
              ),
            ),
          ),
          const AppLogoHeader(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email?.split('@').first ?? 'Usuario';

    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _kPrimaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: user?.photoURL != null
              ? ClipOval(
                  child: Image.network(
                    user!.photoURL!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.person, color: _kPrimaryColor, size: 30);
                    },
                  ),
                )
              : Icon(Icons.person, color: _kPrimaryColor, size: 30),
        ),
        const SizedBox(width: _kSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $userName',
                style: GoogleFonts.exo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _kTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestiona tus viajes desde aquí',
                style: GoogleFonts.exo(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accesos rápidos',
          style: GoogleFonts.exo(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextColor),
        ),
        const SizedBox(height: _kSpacing),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.history,
                title: 'Historial',
                subtitle: 'Ver viajes',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Historial de viajes (próximamente)')),
                  );
                },
              ),
            ),
            const SizedBox(width: _kSpacing),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.person,
                title: 'Perfil',
                subtitle: 'Mi cuenta',
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Mi perfil (próximamente)')));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_kBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(_kSpacing),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _kPrimaryColor, size: 24),
            ),
            const SizedBox(height: _kSpacing),
            Text(
              title,
              style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.bold, color: _kTextColor),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.exo(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
