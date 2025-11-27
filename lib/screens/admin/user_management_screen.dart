import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/user_service.dart';
import '../../auth/supabase_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();
  final SupabaseService _supabaseService = SupabaseService();
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Material(
      color: Colors.white,
      child: Container(
        color: Colors.white, // White background for the content area
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Users List - Active',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A202C),
                  fontSize: isTablet ? null : 20,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 16),
              _buildControls(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              Expanded(child: _buildUserList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        if (isNarrow) {
          // Layout vertical para pantallas pequeñas
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                elevation: 0,
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButton<int>(
                    value: 10,
                    underline: const SizedBox(),
                    isExpanded: true,
                    items: [10, 25, 50]
                        .map(
                          (int value) =>
                              DropdownMenuItem<int>(value: value, child: Text('$value Records')),
                        )
                        .toList(),
                    onChanged: (newValue) {},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                elevation: 0,
                color: Colors.transparent,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _searchTerm = value.toLowerCase()),
                ),
              ),
            ],
          );
        }

        // Layout horizontal para pantallas grandes
        return Row(
          children: [
            Material(
              elevation: 0,
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: DropdownButton<int>(
                  value: 10,
                  underline: const SizedBox(),
                  items: [10, 25, 50]
                      .map(
                        (int value) =>
                            DropdownMenuItem<int>(value: value, child: Text('$value Records')),
                      )
                      .toList(),
                  onChanged: (newValue) {},
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: isTablet ? 300 : constraints.maxWidth * 0.4,
              child: Material(
                elevation: 0,
                color: Colors.transparent,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _searchTerm = value.toLowerCase()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showSyncUserDialog,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sincronizar Usuario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final email = data['email']?.toString().toLowerCase() ?? '';
          return email.contains(_searchTerm);
        }).toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => _buildUserCard(users[index]),
        );
      },
    );
  }

  Widget _buildUserCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isNarrow = screenWidth < 400;

    // Supabase usa 'id' como primary key, pero también tenemos 'firebase_uid'
    final userId = data['firebase_uid']?.toString() ?? doc.id;
    final status = data['status']?.toString() ?? 'inactive';

    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 16.0 : 12.0),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
        child: isNarrow
            ? _buildNarrowCardLayout(userId, data, status)
            : _buildWideCardLayout(userId, data, status, isTablet),
      ),
    );
  }

  Widget _buildNarrowCardLayout(String userId, Map<String, dynamic> data, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
              child: const Icon(Icons.person_outline, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['display_name'] ?? data['name'] ?? data['email'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['email'] ?? 'N/A',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  onPressed: () => _showEditDialog(userId, data),
                  tooltip: 'Edit User',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _showDeleteConfirmation(userId, data['email'] ?? 'user'),
                  tooltip: 'Delete User',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWideCardLayout(
    String userId,
    Map<String, dynamic> data,
    String status,
    bool isTablet,
  ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
          child: const Icon(Icons.person_outline, color: Color(0xFF1D4ED8)),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data['display_name'] ?? data['name'] ?? data['email'] ?? 'N/A',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                data['email'] ?? 'N/A',
                style: TextStyle(color: Colors.grey, fontSize: isTablet ? 14 : 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(width: isTablet ? 16 : 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 12 : 10,
            ),
          ),
        ),
        SizedBox(width: isTablet ? 16 : 8),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
          onPressed: () => _showEditDialog(userId, data),
          tooltip: 'Edit User',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(userId, data['email'] ?? 'user'),
          tooltip: 'Delete User',
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'suspended':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }

  void _showEditDialog(String userId, Map<String, dynamic> userData) {
    // ... (Dialog code remains the same)
    // Supabase usa 'display_name' en lugar de 'name'
    final nameController = TextEditingController(
      text: userData['display_name'] ?? userData['name'] ?? '',
    );
    String currentRole = userData['role'] ?? 'user';
    String currentStatus = userData['status'] ?? 'inactive';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdown('Type', currentRole, [
                      'admin',
                      'user',
                      'driver',
                    ], (val) => setState(() => currentRole = val!)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(text: userData['email'] ?? ''),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFf2f2f2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown('Status', currentStatus, [
                      'active',
                      'inactive',
                      'suspended',
                    ], (val) => setState(() => currentStatus = val!)),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      icon: const Icon(Icons.lock_reset, size: 16),
                      label: const Text('Send Password Reset'),
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        _userService.sendPasswordResetEmail(userData['email'] ?? '').then((
                          success,
                        ) {
                          if (!mounted) return;
                          navigator.pop();
                          if (!mounted) return;
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Password reset email sent successfully.'
                                    : 'Failed to send email.',
                              ),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8)),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                final updates = {
                  'display_name': nameController.text, // Supabase usa display_name
                  'role': currentRole,
                  'status': currentStatus,
                };

                bool success = await _userService.updateUserProfile(uid: userId, updates: updates);

                if (!mounted) return;
                navigator.pop();

                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'User updated successfully!' : 'Update failed.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown(
    String label,
    String currentValue,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          value: currentValue,
          items: items
              .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String userId, String userIdentifier) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete $userIdentifier?'),
        actions: <Widget>[
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              _userService.deleteUser(userId);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSyncUserDialog() {
    final firebaseUidController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sincronizar Usuario de Firebase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el UID de Firebase del usuario que deseas sincronizar con Supabase.\n\n'
                'Puedes encontrar el UID en Firebase Console > Authentication > Users.\n\n'
                'NOTA: Solo puedes sincronizar el usuario actualmente autenticado. '
                'Para sincronizar otros usuarios, usa el script SQL proporcionado.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: firebaseUidController,
                decoration: const InputDecoration(
                  labelText: 'Firebase UID',
                  hintText: 'Ej: o4orlaSxvqfp2NuUZxzQfkGaX...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (opcional)',
                  hintText: 'Ej: usuario@ejemplo.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final firebaseUid = firebaseUidController.text.trim();
              if (firebaseUid.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa el Firebase UID'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }

              // Intentar obtener el usuario de Firebase
              // NOTA: En Flutter no podemos obtener usuarios por UID directamente
              // Solo podemos sincronizar el usuario actual
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null || currentUser.uid != firebaseUid) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se puede sincronizar este usuario.\n'
                        'Solo puedes sincronizar el usuario actualmente autenticado.\n'
                        'Para sincronizar otros usuarios, usa el script SQL en expo/database/sync-firebase-users-to-supabase.sql',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 6),
                    ),
                  );
                }
                return;
              }

              // Sincronizar usuario actual
              try {
                final success = await _supabaseService.syncUserWithSupabase(currentUser);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Usuario sincronizado exitosamente'
                            : 'Error al sincronizar usuario',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Sincronizar'),
          ),
        ],
      ),
    );
  }
}
