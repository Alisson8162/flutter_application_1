import 'dart:io';
import 'package:flutter/material.dart';

class ImageDisplayMobile extends StatelessWidget {
  final String path;
  const ImageDisplayMobile({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      height: 150,
      fit: BoxFit.cover,
    );
  }
}
