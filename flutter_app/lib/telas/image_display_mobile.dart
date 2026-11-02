import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Implementação mobile/desktop: exibe a imagem a partir do caminho do
/// arquivo local usando `dart:io`.
///
/// CORRIGIDO: antes existiam duas classes com nomes e construtores
/// DIFERENTES (`ImageDisplayMobile({path})` e `ImageDisplayWeb({bytes})`)
/// "escolhidas" por um import condicional que não fazia sentido, já que o
/// código em reportar_problema.dart referenciava as duas classes
/// diretamente por nome (com `kIsWeb ? ... : ...`) - isso quebra a compilação
/// para Web, pois este arquivo usa `dart:io`, indisponível no navegador, e
/// seria importado incondicionalmente. Agora as duas implementações expõem
/// a MESMA classe `ImagePreview` com a mesma assinatura, e o import
/// condicional de verdade escolhe qual das duas é carregada.
class ImagePreview extends StatelessWidget {
  final String? path;
  final Uint8List? bytes;

  const ImagePreview({super.key, this.path, this.bytes});

  @override
  Widget build(BuildContext context) {
    if (path == null) return const SizedBox.shrink();
    return Image.file(
      File(path!),
      height: 150,
      fit: BoxFit.cover,
    );
  }
}
