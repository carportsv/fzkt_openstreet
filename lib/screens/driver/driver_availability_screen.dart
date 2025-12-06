import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverAvailabilityScreen extends StatefulWidget {
  const DriverAvailabilityScreen({super.key});

  @override
  State<DriverAvailabilityScreen> createState() => _DriverAvailabilityScreenState();
}

class _DriverAvailabilityScreenState extends State<DriverAvailabilityScreen> {
  bool _isAvailable = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Disponibilidad', style: GoogleFonts.exo()),
        backgroundColor: Colors.teal[700],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isAvailable ? Icons.toggle_on : Icons.toggle_off,
              size: 120,
              color: _isAvailable ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              _isAvailable ? 'Disponible' : 'No Disponible',
              style: GoogleFonts.exo(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isAvailable ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isAvailable
                  ? 'Estás recibiendo solicitudes de viajes'
                  : 'No estás recibiendo solicitudes de viajes',
              style: GoogleFonts.exo(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() => _isAvailable = !_isAvailable);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isAvailable ? 'Disponibilidad activada' : 'Disponibilidad desactivada',
                      style: GoogleFonts.exo(),
                    ),
                    backgroundColor: _isAvailable ? Colors.green : Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAvailable ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _isAvailable ? 'Desactivar Disponibilidad' : 'Activar Disponibilidad',
                style: GoogleFonts.exo(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
