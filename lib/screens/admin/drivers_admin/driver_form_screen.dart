import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../auth/supabase_service.dart';

class DriverFormScreen extends StatefulWidget {
  final Map<String, dynamic>? driverData;

  const DriverFormScreen({super.key, this.driverData});

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carPlateController = TextEditingController();
  final _carYearController = TextEditingController();

  String _selectedStatus = 'active';
  bool _isAvailable = true;
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _driverId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.driverData != null;
    if (_isEditMode) {
      _loadDriverData();
    }
  }

  void _loadDriverData() {
    final driver = widget.driverData!;
    _driverId = driver['id'] as String?;
    
    final user = driver['user'] as Map<String, dynamic>?;
    if (user != null) {
      _userId = user['id'] as String?;
      _nameController.text = user['display_name']?.toString() ?? '';
      _emailController.text = user['email']?.toString() ?? '';
      _phoneController.text = user['phone_number']?.toString() ?? '';
    }

    final carInfo = driver['car_info'] as Map<String, dynamic>?;
    if (carInfo != null) {
      _carModelController.text = carInfo['model']?.toString() ?? '';
      _carPlateController.text = carInfo['plate']?.toString() ?? '';
      _carYearController.text = carInfo['year']?.toString() ?? '';
    }

    final status = driver['status']?.toString() ?? 'active';
    _selectedStatus = status;
    _isAvailable = driver['is_available'] as bool? ?? true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _carModelController.dispose();
    _carPlateController.dispose();
    _carYearController.dispose();
    super.dispose();
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabaseClient = _supabaseService.client;

      if (_isEditMode) {
        await _updateDriver(supabaseClient);
      } else {
        await _createDriver(supabaseClient);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Conductor actualizado exitosamente' : 'Conductor creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createDriver(dynamic supabaseClient) async {
    // 1. Verificar si el usuario ya existe en Supabase
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (password.isEmpty) {
      throw Exception('La contraseña es requerida para crear un nuevo conductor');
    }

    // Verificar si el usuario ya existe en Supabase
    final existingUser = await supabaseClient
        .from('users')
        .select('id, firebase_uid')
        .eq('email', email)
        .maybeSingle();

    String firebaseUid;
    String? existingUserId;

    if (existingUser != null) {
      // Usuario ya existe en Supabase
      existingUserId = existingUser['id'] as String?;
      firebaseUid = existingUser['firebase_uid'] as String? ?? '';
      
      // Si no tiene firebase_uid, crear en Firebase Auth
      if (firebaseUid.isEmpty) {
        try {
          final userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          firebaseUid = userCredential.user!.uid;
        } catch (e) {
          throw Exception('Error creando usuario en Firebase: $e');
        }
      }
    } else {
      // Usuario no existe, crear en Firebase Auth
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        firebaseUid = userCredential.user!.uid;
      } catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          // El email ya está en uso en Firebase, intentar obtener el UID
          try {
            // No podemos obtener el UID sin la contraseña, así que lanzamos error
            throw Exception('El email ya está registrado en Firebase. Por favor, use otro email o contacte al administrador.');
          } catch (e2) {
            throw Exception('Error: $e2');
          }
        } else {
          throw Exception('Error creando usuario en Firebase: $e');
        }
      }
    }

    // 2. Crear/actualizar usuario en tabla users con role='driver'
    String userId;
    
    if (existingUserId == null) {
      // Crear nuevo usuario
      final userData = {
        'firebase_uid': firebaseUid,
        'email': email,
        'display_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'role': 'driver',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final userResponse = await supabaseClient
          .from('users')
          .insert(userData)
          .select('id')
          .single();

      userId = userResponse['id'] as String;
    } else {
      // Actualizar usuario existente y asegurar que el rol sea 'driver'
      userId = existingUserId;
      await supabaseClient.from('users').update({
        'firebase_uid': firebaseUid,
        'display_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'role': 'driver', // Asegurar que el rol sea driver
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    }

    // Verificar si ya existe un driver para este usuario
    final existingDriver = await supabaseClient
        .from('drivers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (existingDriver != null) {
      throw Exception('Este usuario ya tiene un registro de conductor. Por favor, edite el conductor existente.');
    }

    // 3. Crear registro en tabla drivers
    final carInfo = {
      'model': _carModelController.text.trim(),
      'plate': _carPlateController.text.trim(),
      if (_carYearController.text.trim().isNotEmpty)
        'year': int.tryParse(_carYearController.text.trim()),
    };

    final driverData = {
      'user_id': userId,
      'status': _selectedStatus,
      'is_available': _isAvailable,
      'car_info': carInfo,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await supabaseClient.from('drivers').insert(driverData);
  }

  Future<void> _updateDriver(dynamic supabaseClient) async {
    // 1. Actualizar usuario en tabla users
    if (_userId != null) {
      final userUpdates = {
        'display_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Si se cambió el email, actualizarlo
      if (_emailController.text.trim().isNotEmpty) {
        userUpdates['email'] = _emailController.text.trim();
      }

      await supabaseClient.from('users').update(userUpdates).eq('id', _userId);
    }

    // 2. Actualizar registro en tabla drivers
    final carInfo = {
      'model': _carModelController.text.trim(),
      'plate': _carPlateController.text.trim(),
      if (_carYearController.text.trim().isNotEmpty)
        'year': int.tryParse(_carYearController.text.trim()),
    };

    final driverUpdates = {
      'status': _selectedStatus,
      'is_available': _isAvailable,
      'car_info': carInfo,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await supabaseClient.from('drivers').update(driverUpdates).eq('id', _driverId);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Conductor' : 'Nuevo Conductor'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A202C),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
          children: [
            // Información Personal
            _buildSectionCard(
              title: 'Información Personal',
              icon: Icons.person_outline,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Nombre completo',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isEditMode, // No permitir cambiar email en edición
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El email es requerido';
                    }
                    if (!value.contains('@')) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                if (!_isEditMode) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La contraseña es requerida';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Teléfono',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Información del Vehículo
            _buildSectionCard(
              title: 'Información del Vehículo',
              icon: Icons.directions_car_outlined,
              children: [
                _buildTextField(
                  controller: _carModelController,
                  label: 'Modelo del vehículo',
                  icon: Icons.directions_car,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El modelo es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _carPlateController,
                  label: 'Placa',
                  icon: Icons.confirmation_number_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La placa es requerida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _carYearController,
                  label: 'Año (opcional)',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Estado y Disponibilidad
            _buildSectionCard(
              title: 'Estado y Disponibilidad',
              icon: Icons.settings_outlined,
              children: [
                _buildDropdownField(
                  label: 'Estado',
                  value: _selectedStatus,
                  items: const [
                    {'value': 'active', 'label': 'Activo'},
                    {'value': 'inactive', 'label': 'Inactivo'},
                    {'value': 'busy', 'label': 'Ocupado'},
                  ],
                  onChanged: (value) {
                    setState(() => _selectedStatus = value!);
                  },
                ),
                const SizedBox(height: 16),
                _buildSwitchField(
                  label: 'Disponible',
                  value: _isAvailable,
                  onChanged: (value) {
                    setState(() => _isAvailable = value);
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Botones de acción
            _buildActionButtons(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1D4ED8), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1D4ED8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.info_outline, color: Color(0xFF1D4ED8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item['value'],
          child: Text(item['label']!),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSwitchField({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF1D4ED8),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveDriver,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isEditMode ? 'Actualizar Conductor' : 'Crear Conductor',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A202C),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

