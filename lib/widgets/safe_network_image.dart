import 'package:flutter/material.dart';

/// Widget que maneja errores de carga de imágenes de red de forma segura
/// Incluye fallback automático cuando la imagen no se puede cargar
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final Widget fallback;
  final BoxFit? fit;
  final double? width;
  final double? height;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.fit,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return fallback;
    }

    return Image.network(
      imageUrl!,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        // No loguear errores 429 (Too Many Requests) como errores críticos
        // Son temporales y se resuelven automáticamente
        if (error is NetworkImageLoadException) {
          final statusCode = error.statusCode;
          if (statusCode == 429) {
            // Error de rate limiting - silencioso, solo mostrar fallback
            return fallback;
          }
        }
        // Para otros errores, mostrar fallback sin loguear
        return fallback;
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        // Mostrar fallback mientras carga
        return fallback;
      },
    );
  }
}
