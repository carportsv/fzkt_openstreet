import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverRideScreen extends StatefulWidget {
  final String rideId;

  const DriverRideScreen({super.key, required this.rideId});

  @override
  State<DriverRideScreen> createState() => _DriverRideScreenState();
}

class _DriverRideScreenState extends State<DriverRideScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Viaje Activo', style: GoogleFonts.exo()),
        backgroundColor: Colors.teal[700],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car, size: 80, color: Colors.blue[700]),
            const SizedBox(height: 16),
            Text(
              'Viaje ID: ${widget.rideId}',
              style: GoogleFonts.exo(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pantalla de gestión de viaje en desarrollo',
              style: GoogleFonts.exo(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
