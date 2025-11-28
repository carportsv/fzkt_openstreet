import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Servicio principal para interactuar con Supabase
/// Maneja la inicialización y proporciona métodos para operaciones comunes
class SupabaseService {
  static SupabaseService? _instance;
  SupabaseClient? _client;

  SupabaseService._();

  /// Singleton instance
  factory SupabaseService() {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  /// Inicializar Supabase con las credenciales del .env
  Future<void> initialize() async {
    try {
      String? supabaseUrl;
      String? supabaseAnonKey;

      try {
        supabaseUrl = dotenv.env['EXPO_PUBLIC_SUPABASE_URL'];
        supabaseAnonKey = dotenv.env['EXPO_PUBLIC_SUPABASE_ANON_KEY'];
      } catch (e) {
        // Si dotenv no está inicializado, lanzar un error más descriptivo
        throw Exception(
          'dotenv no está inicializado. En Flutter Web, las variables de entorno deben estar disponibles globalmente.\n'
          'Error: $e',
        );
      }

      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception(
          'Supabase credentials not found in .env file. Please add EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY',
        );
      }

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey, debug: kDebugMode);

      _client = Supabase.instance.client;
      if (kDebugMode) {
        print('✅ Supabase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Supabase: $e');
      }
      rethrow;
    }
  }

  /// Obtener el cliente de Supabase
  SupabaseClient get client {
    if (_client != null) {
      return _client!;
    }

    // Intentar obtener el cliente de Supabase.instance
    try {
      _client = Supabase.instance.client;
      if (_client != null) {
        return _client!;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] Error getting Supabase.instance.client: $e');
      }
    }

    // Si aún no está disponible, lanzar un error descriptivo
    throw StateError(
      'Supabase client is not initialized. Call SupabaseService().initialize() first.',
    );
  }

  /// Sincronizar usuario de Firebase Auth con Supabase
  /// Similar a la implementación en web-html/js/auth.js
  Future<bool> syncUserWithSupabase(firebase_auth.User firebaseUser) async {
    try {
      if (kDebugMode) {
        print('🔄 Sincronizando usuario con Supabase: ${firebaseUser.uid}');
      }

      // Verificar que el cliente esté inicializado
      SupabaseClient supabaseClient;
      try {
        supabaseClient = client;
      } catch (e) {
        if (kDebugMode) {
          print('[SupabaseService] ⚠️ Supabase no inicializado, no se puede sincronizar: $e');
        }
        return false;
      }

      // Verificar si el usuario ya existe en Supabase por firebase_uid
      var existingUserResponse = await supabaseClient
          .from('users')
          .select('id, email, firebase_uid, role')
          .eq('firebase_uid', firebaseUser.uid)
          .maybeSingle();

      // Si no existe por firebase_uid, buscar por email (si tiene email)
      if (existingUserResponse == null &&
          firebaseUser.email != null &&
          firebaseUser.email!.isNotEmpty) {
        if (kDebugMode) {
          print(
            '🔍 Usuario no encontrado por firebase_uid, buscando por email: ${firebaseUser.email}',
          );
        }
        existingUserResponse = await supabaseClient
            .from('users')
            .select('id, email, firebase_uid, role')
            .eq('email', firebaseUser.email!)
            .maybeSingle();

        if (existingUserResponse != null) {
          if (kDebugMode) {
            print('✅ Usuario encontrado por email, actualizando firebase_uid...');
          }
        }
      }

      final userData = {
        'firebase_uid': firebaseUser.uid,
        'email': firebaseUser.email,
        'display_name': firebaseUser.displayName ?? '',
        'phone_number': firebaseUser.phoneNumber ?? '',
        'photo_url': firebaseUser.photoURL,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingUserResponse != null) {
        // Usuario existe, actualizar
        if (kDebugMode) {
          print('✅ Usuario existe en Supabase, actualizando...');
        }

        // Si se encontró por email, actualizar también el firebase_uid
        await supabaseClient.from('users').update(userData).eq('id', existingUserResponse['id']);

        if (kDebugMode) {
          print('✅ Usuario actualizado en Supabase');
        }
        return true;
      } else {
        // Usuario no existe, crear nuevo
        if (kDebugMode) {
          print('✅ Creando nuevo usuario en Supabase...');
        }

        final newUserData = {
          ...userData,
          'role': 'user', // Por defecto es usuario
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        };

        try {
          await supabaseClient.from('users').insert(newUserData);
          if (kDebugMode) {
            print('✅ Nuevo usuario creado en Supabase');
          }
          return true;
        } catch (e) {
          // Si hay error de duplicado (por email), intentar actualizar
          if (e.toString().contains('duplicate') || e.toString().contains('23505')) {
            if (kDebugMode) {
              print('⚠️ Error de duplicado, intentando actualizar por email...');
            }
            if (firebaseUser.email != null && firebaseUser.email!.isNotEmpty) {
              await supabaseClient.from('users').update(userData).eq('email', firebaseUser.email!);
              if (kDebugMode) {
                print('✅ Usuario actualizado después de error de duplicado');
              }
              return true;
            }
          }
          rethrow;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error sincronizando usuario con Supabase: $e');
      }
      return false;
    }
  }

  /// Obtener rol del usuario desde Supabase
  /// Similar a getUserRole en FirestoreService pero usando Supabase
  Future<String> getUserRole(String firebaseUid) async {
    try {
      // Asegurar que el cliente esté inicializado con timeout más largo para web
      if (_client == null) {
        try {
          _client = Supabase.instance.client;
        } catch (e) {
          // Si Supabase aún no está inicializado, esperar más tiempo (web puede ser más lento)
          if (kDebugMode) {
            print('[SupabaseService] Waiting for Supabase initialization...');
          }
          await Future.delayed(const Duration(milliseconds: 1000));
          try {
            _client = Supabase.instance.client;
          } catch (e2) {
            // Si aún no está listo, esperar un poco más
            await Future.delayed(const Duration(milliseconds: 1000));
            try {
              _client = Supabase.instance.client;
            } catch (e3) {
              if (kDebugMode) {
                print('[SupabaseService] ⚠️ Supabase not ready after retries, using default role');
              }
              return 'user';
            }
          }
        }
      }

      // Obtener el cliente de forma segura
      SupabaseClient supabaseClient;
      try {
        supabaseClient = client;
      } catch (e) {
        if (kDebugMode) {
          print('[SupabaseService] ⚠️ Supabase no inicializado, usando rol por defecto: $e');
        }
        return 'user';
      }

      // Consulta con timeout más largo (5 segundos para web)
      if (kDebugMode) {
        print('[SupabaseService] Querying role for firebase_uid: $firebaseUid');
      }

      final response = await supabaseClient
          .from('users')
          .select('role')
          .eq('firebase_uid', firebaseUid)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (response != null) {
        final role = response['role'] as String? ?? 'user';
        if (kDebugMode) {
          print('[SupabaseService] ✅ Role found: $role');
        }
        return role;
      } else {
        // Usuario no existe en Supabase
        if (kDebugMode) {
          print('[SupabaseService] ⚠️ User not found in Supabase for firebase_uid: $firebaseUid');
        }
        // Intentar sincronizar y luego obtener el rol de nuevo
        final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (firebaseUser != null && firebaseUser.uid == firebaseUid) {
          if (kDebugMode) {
            print('[SupabaseService] Attempting to sync user and retry...');
          }
          await syncUserWithSupabase(firebaseUser);
          // Intentar obtener el rol nuevamente
          final retryResponse = await supabaseClient
              .from('users')
              .select('role')
              .eq('firebase_uid', firebaseUid)
              .maybeSingle()
              .timeout(const Duration(seconds: 3));

          if (retryResponse != null) {
            final role = retryResponse['role'] as String? ?? 'user';
            if (kDebugMode) {
              print('[SupabaseService] ✅ Role found after sync: $role');
            }
            return role;
          }
        }
        return 'user';
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] ❌ Error in getUserRole: $e');
      }
      // Retornar 'user' por defecto si hay error o timeout
      return 'user';
    }
  }

  /// Obtener todos los usuarios (Stream)
  Stream<List<Map<String, dynamic>>> getAllUsersStream() {
    try {
      return client.from('users').stream(primaryKey: ['id']).order('created_at', ascending: false);
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] ⚠️ Error getting users stream: $e');
      }
      // Retornar un stream vacío si hay error
      return Stream.value([]);
    }
  }

  /// Obtener todos los usuarios (Future)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final supabaseClient = client;
      final response = await supabaseClient
          .from('users')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] Error getting all users: $e');
      }
      return [];
    }
  }

  /// Obtener usuario por firebase_uid
  Future<Map<String, dynamic>?> getUserByFirebaseUid(String firebaseUid) async {
    try {
      final supabaseClient = client;
      final response = await supabaseClient
          .from('users')
          .select()
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();

      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] Error getting user by firebase_uid: $e');
      }
      return null;
    }
  }

  /// Actualizar perfil de usuario
  Future<bool> updateUserProfile({
    required String firebaseUid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final supabaseClient = client;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await supabaseClient.from('users').update(updates).eq('firebase_uid', firebaseUid);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] Error updating profile: $e');
      }
      return false;
    }
  }

  /// Eliminar usuario
  Future<bool> deleteUser(String firebaseUid) async {
    try {
      final supabaseClient = client;
      await supabaseClient.from('users').delete().eq('firebase_uid', firebaseUid);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] Error deleting user: $e');
      }
      return false;
    }
  }

  /// Obtener usuario por ID de Supabase
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final supabaseClient = client;
      final response = await supabaseClient.from('users').select().eq('id', userId).maybeSingle();

      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] Error getting user by id: $e');
      }
      return null;
    }
  }

  /// Sincronizar todos los usuarios de Firebase Auth a Supabase
  /// NOTA: En Flutter, solo puede sincronizar el usuario actual
  /// Para sincronizar todos los usuarios, se necesita un script del lado del servidor
  /// con Firebase Admin SDK
  Future<int> syncAllFirebaseUsers() async {
    try {
      if (kDebugMode) {
        print('🔄 Iniciando sincronización de usuarios de Firebase...');
      }

      // En Flutter, solo podemos sincronizar el usuario actual
      // Para sincronizar todos los usuarios, se necesita Firebase Admin SDK en un backend
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print('⚠️ No hay usuario autenticado actualmente');
        }
        return 0;
      }

      final synced = await syncUserWithSupabase(currentUser);
      if (kDebugMode) {
        print('✅ Usuario sincronizado: ${synced ? "Sí" : "No"}');
      }
      return synced ? 1 : 0;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error sincronizando usuarios: $e');
      }
      return 0;
    }
  }
}
