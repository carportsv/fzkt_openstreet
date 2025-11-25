import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static Future<FirebaseOptions> get currentPlatform async {
    final apiKey = dotenv.env['EXPO_PUBLIC_FIREBASE_API_KEY'];
    final appId = dotenv.env['EXPO_PUBLIC_FIREBASE_APP_ID'];
    final messagingSenderId = dotenv.env['EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID'];
    final projectId = dotenv.env['EXPO_PUBLIC_FIREBASE_PROJECT_ID'];
    final authDomain = dotenv.env['EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN'];
    final storageBucket = dotenv.env['EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET'];

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
