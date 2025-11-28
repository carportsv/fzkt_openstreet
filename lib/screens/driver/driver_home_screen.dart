import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_logo_header.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  // Correctly handle logout using Firebase Auth
  void _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // The AuthGate, listening to authStateChanges, will handle navigation.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del Conductor'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_taxi, size: 80, color: Colors.blueGrey),
                SizedBox(height: 20),
                Text(
                  'Bienvenido, Conductor!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const AppLogoHeader(),
        ],
      ),
    );
  }
}
