import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Servicio unificado para gestión de usuarios
/// Migrado de FirestoreService para usar Supabase
/// Mantiene compatibilidad con la interfaz anterior mientras migra a Supabase
class UserService {
  final SupabaseService _supabaseService = SupabaseService();

  // Getter lazy para FirebaseAuth que maneja errores de forma segura
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      if (kDebugMode) {
        print('[UserService] ⚠️ Firebase no inicializado: ${e.toString()}');
      }
      return null;
    }
  }

  /// Obtener rol del usuario desde Supabase
  /// Reemplaza getUserRole de FirestoreService
  Future<String> getUserRole(String uid) async {
    return await _supabaseService.getUserRole(uid);
  }

  /// Obtener todos los usuarios como Stream (compatible con Firestore)
  /// Convierte el Stream de Supabase a un formato compatible con QuerySnapshot
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    // Crear un StreamController para convertir el Stream de Supabase
    final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();

    // Suscribirse al stream de Supabase
    final subscription = _supabaseService.getAllUsersStream().listen(
      (users) {
        // Convertir List<Map> a QuerySnapshot-like
        final docs = users.map((user) {
          // Crear un documento simulado compatible con Firestore
          return _createMockDocumentSnapshot(user);
        }).toList();

        final querySnapshot = _createMockQuerySnapshot(docs);
        controller.add(querySnapshot);
      },
      onError: (error) {
        controller.addError(error);
      },
    );

    // Limpiar cuando se cancele
    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Crear un QueryDocumentSnapshot simulado para compatibilidad
  QueryDocumentSnapshot<Map<String, dynamic>> _createMockDocumentSnapshot(
    Map<String, dynamic> data,
  ) {
    final id = data['id']?.toString() ?? data['firebase_uid']?.toString() ?? '';
    return _MockQueryDocumentSnapshot(id, data);
  }

  /// Crear un QuerySnapshot simulado para compatibilidad
  QuerySnapshot<Map<String, dynamic>> _createMockQuerySnapshot(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return _MockQuerySnapshot(docs);
  }

  /// Eliminar usuario
  Future<void> deleteUser(String uid) async {
    await _supabaseService.deleteUser(uid);
  }

  /// Actualizar perfil de usuario
  Future<bool> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    return await _supabaseService.updateUserProfile(firebaseUid: uid, updates: updates);
  }

  /// Enviar email de reset de contraseña (usa Firebase Auth)
  Future<bool> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) return false;
    final auth = _auth;
    if (auth == null) return false;
    try {
      await auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[UserService] Error sending password reset: ${e.toString()}');
      }
      return false;
    }
  }

  /// Sincronizar usuario de Firebase con Supabase
  Future<bool> syncUserWithSupabase() async {
    final auth = _auth;
    if (auth == null) return false;
    try {
      final user = auth.currentUser;
      if (user == null) return false;
      return await _supabaseService.syncUserWithSupabase(user);
    } catch (e) {
      if (kDebugMode) {
        print('[UserService] Error syncing user: ${e.toString()}');
      }
      return false;
    }
  }
}

/// Clase mock para SnapshotMetadata
class _MockSnapshotMetadata implements SnapshotMetadata {
  @override
  final bool hasPendingWrites = false;
  @override
  final bool isFromCache = false;

  _MockSnapshotMetadata();
}

/// Clases mock para compatibilidad con Firestore QuerySnapshot/DocumentSnapshot
// ignore: subtype_of_sealed_class
class _MockQuerySnapshot extends QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  _MockQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => _MockSnapshotMetadata();

  @override
  int get size => _docs.length;
}

// ignore: subtype_of_sealed_class
class _MockQueryDocumentSnapshot extends QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;

  _MockQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic get(Object field) => _data[field];

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  bool get exists => _data.isNotEmpty;

  @override
  SnapshotMetadata get metadata => _MockSnapshotMetadata();

  @override
  DocumentReference<Map<String, dynamic>> get reference {
    throw UnimplementedError('Reference not available in mock');
  }
}
