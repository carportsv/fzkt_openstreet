import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth/firebase_options.dart';
import 'auth/supabase_service.dart';
import 'router/route_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  // El .env siempre está en la raíz del proyecto
  // En móvil, debe estar listado en pubspec.yaml bajo assets
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ .env cargado exitosamente');
  } catch (e) {
    debugPrint('❌ Error cargando .env: $e');
    debugPrint('⚠️ La app continuará, pero puede fallar la inicialización de Firebase');
  }

  // Initialize Firebase
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(options: await DefaultFirebaseOptions.currentPlatform);
      debugPrint('✅ Firebase inicializado');
    } catch (e, stackTrace) {
      debugPrint('❌ Error inicializando Firebase: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continuar aunque Firebase falle - la app mostrará un error en AuthGate
    }
  }

  // Initialize Supabase
  try {
    await SupabaseService().initialize();
    debugPrint('✅ Supabase inicializado');
  } catch (e, stackTrace) {
    // Log error but don't crash the app - Supabase operations will fail gracefully
    debugPrint('⚠️ Warning: Could not initialize Supabase: $e');
    debugPrint('Stack trace: $stackTrace');
    // Continuar - las operaciones de Supabase manejarán el error
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const RouteHandler(),
      // Prevenir que Flutter intente manipular el historial automáticamente
      // Esto evita el SecurityError cuando hay URLs con dobles barras
      restorationScopeId: null,
      // Usar un builder para capturar errores de routing
      builder: (context, child) {
        // Si hay un error, mostrar el widget hijo de todas formas
        return child ?? const RouteHandler();
      },
    );
  }
}
