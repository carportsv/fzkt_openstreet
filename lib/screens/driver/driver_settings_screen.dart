import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración', style: GoogleFonts.exo()),
        backgroundColor: Colors.teal[700],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingTile(
            icon: Icons.notifications,
            title: 'Notificaciones',
            subtitle: 'Recibir notificaciones de viajes',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingTile(
            icon: Icons.person,
            title: 'Editar Perfil',
            subtitle: 'Modificar información personal',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pantalla de perfil en desarrollo', style: GoogleFonts.exo()),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingTile(
            icon: Icons.directions_car,
            title: 'Información del Vehículo',
            subtitle: 'Gestionar datos del carro',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pantalla de vehículo en desarrollo', style: GoogleFonts.exo()),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[700]),
        ),
        title: Text(title, style: GoogleFonts.exo(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: GoogleFonts.exo(fontSize: 14, color: Colors.grey[600])),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
