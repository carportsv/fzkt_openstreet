import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_service.dart';
import '../../widgets/safe_network_image.dart';

class DriverVehicleInfoScreen extends StatefulWidget {
  const DriverVehicleInfoScreen({super.key});

  @override
  State<DriverVehicleInfoScreen> createState() => _DriverVehicleInfoScreenState();
}

class _DriverVehicleInfoScreenState extends State<DriverVehicleInfoScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _driverId;
  String? _currentVehiclePhotoUrl;
  File? _selectedVehicleImage;
  bool _deleteVehiclePhoto = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadVehicleInfo();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleInfo() async {
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
          .select('id')
          .eq('firebase_uid', user.uid)
          .maybeSingle();

      if (userResponse != null) {
        final userId = userResponse['id'] as String?;
        if (userId != null) {
          // Obtener información del driver y vehículo
          final driverResponse = await supabaseClient
              .from('drivers')
              .select('id, car_info')
              .eq('user_id', userId)
              .maybeSingle();

          if (driverResponse != null) {
            _driverId = driverResponse['id'] as String?;
            final carInfo = driverResponse['car_info'] as Map<String, dynamic>?;

            if (carInfo != null) {
              _modelController.text = carInfo['model'] as String? ?? '';
              _plateController.text = carInfo['plate'] as String? ?? '';
              _yearController.text = carInfo['year']?.toString() ?? '';
              _currentVehiclePhotoUrl = carInfo['vehicle_photo'] as String?;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverVehicleInfoScreen] Error cargando información: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickVehicleImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedVehicleImage = File(image.path);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverVehicleInfoScreen] Error seleccionando imagen del vehículo: $e');
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

  Future<String?> _uploadImageToSupabase(File imageFile, String type, String driverId) async {
    try {
      final supabaseClient = _supabaseService.client;
      final fileName = '${type}_${driverId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'vehicles/$driverId/$fileName';

      // Leer el archivo como bytes
      final bytes = await imageFile.readAsBytes();

      // Subir a Supabase Storage
      await supabaseClient.storage
          .from('vehicle-photos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
          );

      // Obtener URL pública
      final publicUrl = supabaseClient.storage.from('vehicle-photos').getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DriverVehicleInfoScreen] Error subiendo imagen: $e');
      }
      return null;
    }
  }

  Future<void> _saveVehicleInfo() async {
    if (_driverId == null) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Error', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
            content: Text('No se encontró el conductor', style: GoogleFonts.exo()),
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
      String? vehiclePhotoUrl = _currentVehiclePhotoUrl;

      // Eliminar foto si se marcó para eliminar
      if (_deleteVehiclePhoto) {
        vehiclePhotoUrl = null;
        // Intentar eliminar del storage si existe
        if (_currentVehiclePhotoUrl != null) {
          try {
            // Extraer el path del storage desde la URL
            final urlParts = _currentVehiclePhotoUrl!.split('/vehicle-photos/');
            if (urlParts.length > 1) {
              final filePath = urlParts[1].split('?')[0];
              await supabaseClient.storage.from('vehicle-photos').remove([filePath]);
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[DriverVehicleInfoScreen] Error eliminando foto del storage: $e');
            }
            // Continuar aunque falle la eliminación del storage
          }
        }
      } else if (_selectedVehicleImage != null) {
        // Subir imagen del vehículo si se seleccionó una nueva
        final uploadedUrl = await _uploadImageToSupabase(
          _selectedVehicleImage!,
          'vehicle',
          _driverId!,
        );
        if (uploadedUrl != null) {
          vehiclePhotoUrl = uploadedUrl;
        }
      }

      // Preparar car_info
      final carInfo = <String, dynamic>{
        'model': _modelController.text.trim(),
        'plate': _plateController.text.trim(),
      };

      if (_yearController.text.trim().isNotEmpty) {
        final year = int.tryParse(_yearController.text.trim());
        if (year != null) {
          carInfo['year'] = year;
        }
      }

      // Si hay foto nueva o se eliminó, actualizar vehicle_photo
      if (_deleteVehiclePhoto || _selectedVehicleImage != null) {
        carInfo['vehicle_photo'] = vehiclePhotoUrl;
      } else if (_currentVehiclePhotoUrl != null) {
        // Mantener la foto existente si no hay cambios
        carInfo['vehicle_photo'] = _currentVehiclePhotoUrl;
      }

      // Actualizar datos del vehículo
      await supabaseClient
          .from('drivers')
          .update({'car_info': carInfo, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', _driverId!);

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Éxito', style: GoogleFonts.exo(fontWeight: FontWeight.w600)),
            content: Text(
              'Información del vehículo actualizada correctamente',
              style: GoogleFonts.exo(),
            ),
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
        debugPrint('[DriverVehicleInfoScreen] Error guardando información: $e');
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
          middle: Text(
            'Información del Vehículo',
            style: GoogleFonts.exo(fontWeight: FontWeight.w600),
          ),
          backgroundColor: CupertinoColors.systemBackground,
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Información del Vehículo',
          style: GoogleFonts.exo(fontWeight: FontWeight.w600),
        ),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: _isSaving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saveVehicleInfo,
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
                  // Campos del formulario
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _modelController,
                          label: 'Modelo',
                          icon: CupertinoIcons.car,
                          isFirst: true,
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(left: 60),
                          color: CupertinoColors.separator,
                        ),
                        _buildTextField(
                          controller: _plateController,
                          label: 'Placa',
                          icon: CupertinoIcons.number,
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(left: 60),
                          color: CupertinoColors.separator,
                        ),
                        _buildTextField(
                          controller: _yearController,
                          label: 'Año',
                          icon: CupertinoIcons.calendar,
                          keyboardType: TextInputType.number,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  // Foto del vehículo (abajo)
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Foto del vehículo
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foto del Vehículo',
                                style: GoogleFonts.exo(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _pickVehicleImage,
                                      child: Container(
                                        width: double.infinity,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemGrey5,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: CupertinoColors.separator,
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: _selectedVehicleImage != null
                                              ? Image.file(
                                                  _selectedVehicleImage!,
                                                  fit: BoxFit.cover,
                                                )
                                              : _currentVehiclePhotoUrl != null
                                              ? SafeNetworkImage(
                                                  imageUrl: _currentVehiclePhotoUrl,
                                                  fallback: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        CupertinoIcons.car_fill,
                                                        size: 50,
                                                        color: CupertinoColors.systemGrey,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Toca para agregar foto',
                                                        style: GoogleFonts.exo(
                                                          color: CupertinoColors.secondaryLabel,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      CupertinoIcons.car_fill,
                                                      size: 50,
                                                      color: CupertinoColors.systemGrey,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Toca para agregar foto',
                                                      style: GoogleFonts.exo(
                                                        color: CupertinoColors.secondaryLabel,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_currentVehiclePhotoUrl != null ||
                                      _selectedVehicleImage != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          setState(() {
                                            _selectedVehicleImage = null;
                                            _deleteVehiclePhoto = true;
                                          });
                                        },
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.destructiveRed,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.delete,
                                            color: CupertinoColors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
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
