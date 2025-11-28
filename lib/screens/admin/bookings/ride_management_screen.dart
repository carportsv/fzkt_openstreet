import 'package:flutter/material.dart';
import '../../../widgets/app_logo_header.dart';

// Modelo para las tarjetas de estadísticas
class _StatCardItem {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _StatCardItem({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class RideManagementScreen extends StatelessWidget {
  const RideManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de tarjetas de estadísticas
    final List<_StatCardItem> stats = [
      _StatCardItem(
        title: 'Pendientes',
        count: '0',
        icon: Icons.hourglass_top,
        color: Colors.orange,
        onTap: () {},
      ),
      _StatCardItem(
        title: 'Aceptados',
        count: '0',
        icon: Icons.check_circle,
        color: Colors.cyan,
        onTap: () {},
      ),
      _StatCardItem(
        title: 'En Progreso',
        count: '0',
        icon: Icons.directions_car,
        color: Colors.blue,
        onTap: () {},
      ),
      _StatCardItem(
        title: 'Completados',
        count: '0',
        icon: Icons.flag,
        color: Colors.green,
        onTap: () {},
      ),
      _StatCardItem(
        title: 'Cancelados',
        count: '0',
        icon: Icons.cancel,
        color: Colors.red,
        onTap: () {},
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Viajes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Botón para Crear Viaje
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Nuevo Viaje'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                // Cuadrícula de estadísticas
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) {
                    final stat = stats[index];
                    return Card(
                      elevation: 2.0,
                      child: InkWell(
                        onTap: stat.onTap,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(stat.icon, size: 40, color: stat.color),
                              const SizedBox(height: 8),
                              Text(
                                stat.count,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(stat.title, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
