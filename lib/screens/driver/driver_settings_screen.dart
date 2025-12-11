import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'driver_profile_edit_screen.dart';
import 'driver_vehicle_info_screen.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Configuración', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          icon: CupertinoIcons.person,
                          title: 'Editar Perfil',
                          subtitle: 'Modificar información personal',
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => const DriverProfileEditScreen(),
                              ),
                            );
                            if (result == true) {
                              // Recargar si hubo cambios
                            }
                          },
                          isFirst: true,
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(left: 60),
                          color: CupertinoColors.separator,
                        ),
                        _buildSettingTile(
                          icon: CupertinoIcons.car,
                          title: 'Información del Vehículo',
                          subtitle: 'Gestionar datos del carro',
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => const DriverVehicleInfoScreen(),
                              ),
                            );
                            if (result == true) {
                              // Recargar si hubo cambios
                            }
                          },
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final iconColor = CupertinoColors.activeBlue;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isFirst ? 12 : 0),
            topRight: Radius.circular(isFirst ? 12 : 0),
            bottomLeft: Radius.circular(isLast ? 12 : 0),
            bottomRight: Radius.circular(isLast ? 12 : 0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.exo(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.exo(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null && onTap != null)
              Icon(CupertinoIcons.chevron_right, color: CupertinoColors.tertiaryLabel, size: 18),
          ],
        ),
      ),
    );
  }
}
