import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageDisplayWeb extends StatelessWidget {
  final Uint8List bytes;
  const ImageDisplayWeb({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      height: 150,
      fit: BoxFit.cover,
    );
  }
}
