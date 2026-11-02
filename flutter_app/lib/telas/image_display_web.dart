import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Implementação Web: exibe a imagem a partir dos bytes em memória
/// (arquivos locais não são acessíveis via `dart:io` no navegador).
/// Ver comentário completo em image_display_mobile.dart.
class ImagePreview extends StatelessWidget {
  final String? path;
  final Uint8List? bytes;

  const ImagePreview({super.key, this.path, this.bytes});

  @override
  Widget build(BuildContext context) {
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(
      bytes!,
      height: 150,
      fit: BoxFit.cover,
    );
  }
}
