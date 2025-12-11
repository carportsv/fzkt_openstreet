import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_service.dart';
import '../../widgets/safe_network_image.dart';

class DriverProfileEditScreen extends StatefulWidget {
  const DriverProfileEditScreen({super.key});

  @override
  State<DriverProfileEditScreen> createState() => _DriverProfileEditScreenState();
}

class _DriverProfileEditScreenState extends State<DriverProfileEditScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;
  String? _currentPhotoUrl;
  File? _selectedImage;
  bool _deletePhoto = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final supabaseClient = _supabaseService.client;

      // Obtener user_id desde firebase_uid
      final userResponse = await supabaseClient
          .from('users')
          .select('id, display_name, email, phone_number, photo_url')
          .eq('firebase_uid', user.uid)
          .maybeSingle();

      if (userResponse != null) {
        final userId = userResponse['id'] as String?;
        if (userId != null) {
          _userId = userId;
          _nameController.text = userResponse['display_name'] as String? ?? '';
          _emailController.text = userResponse['email'] as String? ?? '';
          _phoneController.text = userResponse['phone_number'] as String? ?? '';
          _currentPhotoUrl = userResponse['photo_url'] as String?;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverProfileEditScreen] Error cargando perfil: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverProfileEditScreen] Error seleccionando imagen: $e');
      }
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Error', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
            content: Text('Error al seleccionar imagen: ${e.toString()}', style: GoogleFonts.exo()),
            actions: [
              CupertinoDialogAction(
                child: Text('OK', style: GoogleFonts.exo()),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToSupabase(File imageFile, String userId) async {
    try {
      final supabaseClient = _supabaseService.client;
      final fileName = 'driver_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'drivers/$userId/$fileName';

      // Leer el archivo como bytes
      final bytes = await imageFile.readAsBytes();

      // Subir a Supabase Storage
      await supabaseClient.storage
          .from('driver-photos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
          );

      // Obtener URL pública
      final publicUrl = supabaseClient.storage.from('driver-photos').getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverProfileEditScreen] Error subiendo imagen: $e');
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_userId == null) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Error', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
            content: Text('No se encontró el usuario', style: GoogleFonts.exo()),
            actions: [
              CupertinoDialogAction(
                child: Text('OK', style: GoogleFonts.exo()),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabaseClient = _supabaseService.client;
      String? photoUrl = _currentPhotoUrl;

      // Eliminar foto si se marcó para eliminar
      if (_deletePhoto) {
        photoUrl = null;
        // Intentar eliminar del storage si existe
        if (_currentPhotoUrl != null) {
          try {
            // Extraer el path del storage desde la URL
            final urlParts = _currentPhotoUrl!.split('/driver-photos/');
            if (urlParts.length > 1) {
              final filePath = urlParts[1].split('?')[0];
              await supabaseClient.storage.from('driver-photos').remove([filePath]);
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[DriverProfileEditScreen] Error eliminando foto del storage: $e');
            }
            // Continuar aunque falle la eliminación del storage
          }
        }
      } else if (_selectedImage != null) {
        // Subir imagen si se seleccionó una nueva
        final uploadedUrl = await _uploadImageToSupabase(_selectedImage!, _userId!);
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      }

      // Actualizar datos del usuario
      final updateData = <String, dynamic>{
        'display_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Si hay foto nueva o se eliminó, actualizar photo_url
      if (_deletePhoto || _selectedImage != null) {
        updateData['photo_url'] = photoUrl;
      }

      await supabaseClient.from('users').update(updateData).eq('id', _userId!);

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Éxito', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
            content: Text('Perfil actualizado correctamente', style: GoogleFonts.exo()),
            actions: [
              CupertinoDialogAction(
                child: Text('OK', style: GoogleFonts.exo()),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true); // Retornar true para indicar actualización
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverProfileEditScreen] Error guardando perfil: $e');
      }
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Error', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
            content: Text('Error al guardar: ${e.toString()}', style: GoogleFonts.exo()),
            actions: [
              CupertinoDialogAction(
                child: Text('OK', style: GoogleFonts.exo()),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Editar Perfil', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
          backgroundColor: CupertinoColors.systemBackground,
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Editar Perfil', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: _isSaving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saveProfile,
                child: Text(
                  'Guardar',
                  style: GoogleFonts.exo(
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Foto de perfil
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CupertinoColors.systemGrey5,
                              ),
                              child: ClipOval(
                                child: _selectedImage != null
                                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                                    : _currentPhotoUrl != null
                                    ? SafeNetworkImage(
                                        imageUrl: _currentPhotoUrl,
                                        fallback: Icon(
                                          CupertinoIcons.person_fill,
                                          size: 60,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(
                                        CupertinoIcons.person_fill,
                                        size: 60,
                                        color: CupertinoColors.systemGrey,
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: CupertinoColors.activeBlue,
                                ),
                                child: const Icon(
                                  CupertinoIcons.camera_fill,
                                  color: CupertinoColors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            // Botón para eliminar foto si existe
                            if (_currentPhotoUrl != null || _selectedImage != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedImage = null;
                                      _deletePhoto = true;
                                    });
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: CupertinoColors.destructiveRed,
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.delete,
                                      color: CupertinoColors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Campos del formulario
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Nombre',
                          icon: CupertinoIcons.person,
                          isFirst: true,
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(left: 60),
                          color: CupertinoColors.separator,
                        ),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: CupertinoIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          enabled: false, // Email no se puede editar
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(left: 60),
                          color: CupertinoColors.separator,
                        ),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Teléfono',
                          icon: CupertinoIcons.phone,
                          keyboardType: TextInputType.phone,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: CupertinoColors.activeBlue, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: label,
              keyboardType: keyboardType,
              enabled: enabled,
              style: GoogleFonts.exo(),
              placeholderStyle: GoogleFonts.exo(color: CupertinoColors.placeholderText),
              decoration: const BoxDecoration(),
            ),
          ),
        ],
      ),
    );
  }
}
