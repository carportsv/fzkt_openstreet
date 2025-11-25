import 'package:flutter/material.dart';
import '../../../auth/supabase_service.dart';

class GeneralPricingScreen extends StatefulWidget {
  const GeneralPricingScreen({super.key});

  @override
  State<GeneralPricingScreen> createState() => _GeneralPricingScreenState();
}

class _GeneralPricingScreenState extends State<GeneralPricingScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  final _priceDecimalsController = TextEditingController(text: '2');
  final _minDropOffPriceController = TextEditingController(text: '100');
  final _childSeatPriceController = TextEditingController(text: '90');
  final _cardPaymentAmountController = TextEditingController(text: '90');

  String _cardPaymentType = 'Amount';
  bool _loading = false;

  @override
  void dispose() {
    _priceDecimalsController.dispose();
    _minDropOffPriceController.dispose();
    _childSeatPriceController.dispose();
    _cardPaymentAmountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      setState(() => _loading = true);
      final supabaseClient = _supabaseService.client;

      // Intentar cargar desde tabla 'pricing_settings' o 'settings'
      try {
        final response = await supabaseClient
            .from('pricing_settings')
            .select('*')
            .eq('key', 'general')
            .maybeSingle();

        if (response != null) {
          final data = Map<String, dynamic>.from(response);
          final config = data['config'] as Map<String, dynamic>? ?? {};

          setState(() {
            _priceDecimalsController.text = config['price_decimals']?.toString() ?? '2';
            _minDropOffPriceController.text = config['min_drop_off_price']?.toString() ?? '100';
            _childSeatPriceController.text = config['child_seat_price']?.toString() ?? '90';
            _cardPaymentAmountController.text = config['card_payment_amount']?.toString() ?? '90';
            _cardPaymentType = config['card_payment_type']?.toString() ?? 'Amount';
          });
        }
      } catch (e) {
        // Si la tabla no existe, usar valores por defecto
        debugPrint('Tabla pricing_settings no encontrada, usando valores por defecto: $e');
      }
    } catch (e) {
      debugPrint('Error cargando pricing: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _savePricing() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _loading = true);
      final supabaseClient = _supabaseService.client;

      // Preparar datos de configuración
      final config = {
        'price_decimals': int.tryParse(_priceDecimalsController.text) ?? 2,
        'min_drop_off_price': double.tryParse(_minDropOffPriceController.text) ?? 100.0,
        'child_seat_price': double.tryParse(_childSeatPriceController.text) ?? 90.0,
        'card_payment_type': _cardPaymentType,
        'card_payment_amount': double.tryParse(_cardPaymentAmountController.text) ?? 90.0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Intentar actualizar o insertar en tabla 'pricing_settings'
      try {
        // Verificar si ya existe un registro con key='general'
        final existing = await supabaseClient
            .from('pricing_settings')
            .select('id')
            .eq('key', 'general')
            .maybeSingle();

        if (existing != null) {
          // Actualizar registro existente
          await supabaseClient
              .from('pricing_settings')
              .update({'config': config, 'updated_at': DateTime.now().toIso8601String()})
              .eq('key', 'general');
        } else {
          // Insertar nuevo registro
          await supabaseClient.from('pricing_settings').insert({
            'key': 'general',
            'config': config,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        // Si hay error, lanzarlo para que se maneje en el catch externo
        debugPrint('Error guardando pricing_settings: $e');
        rethrow;
      }

      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Configuración de pricing actualizada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Material(
      color: Colors.white,
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General Pricing',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A202C),
                      fontSize: isTablet ? null : 20,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 24),
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 250,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _loading ? null : _savePricing,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'UPDATE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCurrencyField(
                    label: 'Price Decimals',
                    controller: _priceDecimalsController,
                    showCurrency: false,
                  ),
                  const SizedBox(height: 20),
                  _buildCurrencyField(
                    label: 'Minimum price for additional drop off',
                    controller: _minDropOffPriceController,
                  ),
                  const SizedBox(height: 20),
                  _buildCurrencyField(
                    label: 'Child seat price',
                    controller: _childSeatPriceController,
                  ),
                  const SizedBox(height: 20),
                  _buildDropdown(
                    label: 'Card payment price type',
                    value: _cardPaymentType,
                    items: ['Amount', 'Percentage'],
                    onChanged: (value) {
                      setState(() => _cardPaymentType = value!);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildCurrencyField(
                    label: 'Card payment Amount / Percentage',
                    controller: _cardPaymentAmountController,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyField({
    required String label,
    required TextEditingController controller,
    bool showCurrency = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A202C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            SizedBox(
              width: 250,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es requerido';
                  }
                  if (showCurrency && double.tryParse(value) == null) {
                    return 'Ingrese un número válido';
                  }
                  if (!showCurrency && int.tryParse(value) == null) {
                    return 'Ingrese un número entero válido';
                  }
                  return null;
                },
              ),
            ),
            if (showCurrency) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'EUR',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A202C),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A202C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 250,
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                style: const TextStyle(fontSize: 14),
                items: items
                    .map((String item) => DropdownMenuItem<String>(value: item, child: Text(item)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
