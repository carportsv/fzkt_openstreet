import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static Future<FirebaseOptions> get currentPlatform async {
    String? apiKey;
    String? appId;
    String? messagingSenderId;
    String? projectId;
    String? authDomain;
    String? storageBucket;

    try {
      apiKey = dotenv.env['EXPO_PUBLIC_FIREBASE_API_KEY'];
      appId = dotenv.env['EXPO_PUBLIC_FIREBASE_APP_ID'];
      messagingSenderId = dotenv.env['EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID'];
      projectId = dotenv.env['EXPO_PUBLIC_FIREBASE_PROJECT_ID'];
      authDomain = dotenv.env['EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN'];
      storageBucket = dotenv.env['EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET'];
    } catch (e) {
      // Si dotenv no está inicializado, lanzar un error más descriptivo
      throw Exception(
        'dotenv no está inicializado. En Flutter Web, las variables de entorno deben estar disponibles globalmente.\n'
        'Error: $e',
      );
    }

    if (apiKey == null ||
        appId == null ||
        messagingSenderId == null ||
        projectId == null ||
        authDomain == null ||
        storageBucket == null) {
      throw Exception(
        'Firebase configuration not found in .env file. Please ensure all required variables are set:\n'
        'EXPO_PUBLIC_FIREBASE_API_KEY\n'
        'EXPO_PUBLIC_FIREBASE_APP_ID\n'
        'EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID\n'
        'EXPO_PUBLIC_FIREBASE_PROJECT_ID\n'
        'EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN\n'
        'EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET',
      );
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
    );
  }
}
