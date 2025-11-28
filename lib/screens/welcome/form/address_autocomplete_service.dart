import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio para autocompletado de direcciones usando OpenStreetMap Nominatim
/// Extraído de welcome_screen.dart
class AddressAutocompleteService {
  /// Busca direcciones usando OpenStreetMap Nominatim API
  static Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'format=json&'
        'q=${Uri.encodeComponent(query)}&'
        'limit=10&'
        'addressdetails=1&'
        'extratags=1&'
        'namedetails=1&'
        'accept-language=es,en&'
        'dedupe=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'TaxiApp/1.0',
          'Referer': 'https://nominatim.openstreetmap.org/',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) {
          return [];
        }

        final results = data
            .map(
              (item) => {
                'display_name': item['display_name'] as String? ?? '',
                'lat': double.tryParse(item['lat'] as String? ?? '0') ?? 0.0,
                'lon': double.tryParse(item['lon'] as String? ?? '0') ?? 0.0,
                'importance': (item['importance'] as num?)?.toDouble() ?? 0.0,
                'type': item['type'] as String? ?? '',
                'class': item['class'] as String? ?? '',
              },
            )
            .where((item) => item['lat'] != 0.0 && item['lon'] != 0.0)
            .toList();

        results.sort((a, b) {
          final importanceA = a['importance'] as double;
          final importanceB = b['importance'] as double;
          return importanceB.compareTo(importanceA);
        });

        return results
            .map(
              (item) => {
                'display_name': item['display_name'] as String,
                'lat': item['lat'] as double,
                'lon': item['lon'] as double,
              },
            )
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error en búsqueda de direcciones: ${e.toString()}');
      }
      return [];
    }
  }
}
