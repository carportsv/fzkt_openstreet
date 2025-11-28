import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../auth/supabase_service.dart';

/// Datos necesarios para crear un viaje
class CreateRideData {
  final String originAddress;
  final String destinationAddress;
  final double price;
  final String clientName;
  final LatLng? originCoords;
  final LatLng? destinationCoords;
  final double? distanceKm;
  final String priority;
  final String vehicleType;
  final int passengerCount;
  final int childSeats;
  final int handLuggage;
  final int checkInLuggage;
  final String paymentMethod;
  final String? clientEmail;
  final String? clientPhone;
  final String? notes;
  final DateTime? scheduledDateTime;
  final String? cardNumber;
  final String? cardExpiry;
  final String? cardName;

  const CreateRideData({
    required this.originAddress,
    required this.destinationAddress,
    required this.price,
    required this.clientName,
    this.originCoords,
    this.destinationCoords,
    this.distanceKm,
    required this.priority,
    required this.vehicleType,
    required this.passengerCount,
    this.childSeats = 0,
    this.handLuggage = 0,
    this.checkInLuggage = 0,
    required this.paymentMethod,
    this.clientEmail,
    this.clientPhone,
    this.notes,
    this.scheduledDateTime,
    this.cardNumber,
    this.cardExpiry,
    this.cardName,
  });
}

/// Servicio para gestionar operaciones relacionadas con viajes
/// Extraído de request_ride_screen.dart
class RideService {
  final SupabaseService _supabaseService = SupabaseService();

  /// Validar datos de tarjeta si el método de pago es tarjeta
  void _validateCardData(CreateRideData data) {
    if (data.paymentMethod == 'card') {
      if (data.cardNumber == null || data.cardNumber!.isEmpty) {
        throw Exception('Por favor ingrese el número de tarjeta');
      }
      if (data.cardExpiry == null || data.cardExpiry!.isEmpty) {
        throw Exception('Por favor ingrese la fecha de expiración');
      }
      if (data.cardName == null || data.cardName!.isEmpty) {
        throw Exception('Por favor ingrese el nombre en la tarjeta');
      }
    }
  }

  /// Validar campos requeridos
  void _validateRequiredFields(CreateRideData data) {
    if (data.originAddress.isEmpty || data.destinationAddress.isEmpty || data.clientName.isEmpty) {
      throw Exception('Por favor complete todos los campos requeridos');
    }

    if (data.price <= 0) {
      throw Exception('El precio debe ser mayor a cero');
    }
  }

  /// Obtener el ID de usuario de Supabase desde Firebase UID
  Future<String> _getSupabaseUserId(String firebaseUid) async {
    final supabaseClient = _supabaseService.client;
    final userResponse = await supabaseClient
        .from('users')
        .select('id')
        .eq('firebase_uid', firebaseUid)
        .maybeSingle();

    final userId = userResponse?['id'] as String?;
    if (userId == null) {
      throw Exception(
        'Usuario no encontrado en Supabase. Por favor, sincronice su cuenta primero.',
      );
    }

    return userId;
  }

  /// Preparar los datos del viaje para insertar en Supabase
  Map<String, dynamic> _prepareRideData(String userId, CreateRideData data) {
    final rideData = <String, dynamic>{
      'user_id': userId,
      'origin': {
        'address': data.originAddress,
        'coordinates': {
          'latitude': data.originCoords?.latitude ?? 0.0,
          'longitude': data.originCoords?.longitude ?? 0.0,
        },
      },
      'destination': {
        'address': data.destinationAddress,
        'coordinates': {
          'latitude': data.destinationCoords?.latitude ?? 0.0,
          'longitude': data.destinationCoords?.longitude ?? 0.0,
        },
      },
      'status': 'requested',
      'price': data.price,
      'priority': data.priority.toLowerCase(),
      'vehicle_type': data.vehicleType,
      'passenger_count': data.passengerCount,
      'child_seats': data.childSeats,
      'hand_luggage': data.handLuggage,
      'check_in_luggage': data.checkInLuggage,
      'payment_method': data.paymentMethod,
      'client_name': data.clientName,
    };

    // Agregar email y teléfono si están disponibles
    if (data.clientEmail != null && data.clientEmail!.isNotEmpty) {
      rideData['client_email'] = data.clientEmail;
    }
    if (data.clientPhone != null && data.clientPhone!.isNotEmpty) {
      rideData['client_phone'] = data.clientPhone;
    }

    // Agregar distancia si está disponible (convertir km a metros)
    if (data.distanceKm != null && data.distanceKm! > 0) {
      rideData['distance'] = (data.distanceKm! * 1000).round();
    }

    // Agregar notas si están disponibles
    if (data.notes != null && data.notes!.isNotEmpty) {
      rideData['additional_notes'] = data.notes;
    }

    // Manejar viajes programados
    if (data.scheduledDateTime != null) {
      final now = DateTime.now();
      if (data.scheduledDateTime!.isAfter(now)) {
        rideData['scheduled_at'] = data.scheduledDateTime!.toIso8601String();
        rideData['is_scheduled'] = true;
      } else {
        throw Exception('La fecha y hora programadas deben ser en el futuro');
      }
    }

    // Agregar detalles de tarjeta si el método de pago es tarjeta
    if (data.paymentMethod == 'card' && data.cardNumber != null) {
      // Solo guardar últimos 4 dígitos por seguridad
      final cardNumber = data.cardNumber!.replaceAll(RegExp(r'[\s-]'), '');
      rideData['card_number'] = cardNumber.length >= 4
          ? cardNumber.substring(cardNumber.length - 4)
          : null;
      rideData['card_expiry'] = data.cardExpiry;
      rideData['card_name'] = data.cardName;
      // CVV no se guarda por seguridad
    }

    return rideData;
  }

  /// Crear una solicitud de viaje
  /// Retorna el ID del viaje creado
  /// Lanza excepciones si hay errores de validación o en la BD
  Future<String> createRideRequest(CreateRideData data) async {
    // Validar campos requeridos
    _validateRequiredFields(data);

    // Validar datos de tarjeta si es necesario
    _validateCardData(data);

    // Verificar autenticación
    User? firebaseUser;
    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
    } catch (e) {
      // Manejo seguro de excepciones para Flutter Web
      if (kDebugMode) {
        debugPrint('[RideService] ⚠️ Error obteniendo usuario: $e');
      }
      firebaseUser = null;
    }

    if (firebaseUser == null) {
      throw Exception('Usuario no autenticado. Por favor, inicie sesión.');
    }

    // Obtener ID de usuario de Supabase
    final userId = await _getSupabaseUserId(firebaseUser.uid);

    // Preparar datos del viaje
    final rideData = _prepareRideData(userId, data);

    // Crear viaje en Supabase
    if (kDebugMode) {
      debugPrint('[RideService] Creando viaje con datos: $rideData');
    }

    try {
      final supabaseClient = _supabaseService.client;
      final response = await supabaseClient
          .from('ride_requests')
          .insert(rideData)
          .select('id')
          .single();

      final rideId = response['id'] as String;

      if (kDebugMode) {
        debugPrint('[RideService] ✅ Viaje creado exitosamente con ID: $rideId');
      }

      return rideId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RideService] ❌ Error creando viaje: $e');
      }
      rethrow;
    }
  }
}
