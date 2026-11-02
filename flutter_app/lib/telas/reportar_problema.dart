import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

// Import condicional: em Web carrega image_display_web.dart (usa
// Image.memory), em outras plataformas carrega image_display_mobile.dart
// (usa Image.file/dart:io). Ambos expõem a mesma classe `ImagePreview`.
import 'image_display_mobile.dart'
    if (dart.library.html) 'image_display_web.dart';

class ReportarProblemaScreen extends StatefulWidget {
  const ReportarProblemaScreen({super.key});

  @override
  State<ReportarProblemaScreen> createState() =>
      _ReportarProblemaScreenState();
}

class _ReportarProblemaScreenState extends State<ReportarProblemaScreen> {
  String? corridaSelecionada;
  String? categoriaSelecionada;
  final TextEditingController _descricaoController = TextEditingController();

  XFile? imagemSelecionada;
  Uint8List? imagemBytes; // usado no Web

  final List<String> corridas = [
    "Corrida #1201",
    "Corrida #1200",
    "Corrida #1199"
  ];
  final List<String> categorias = ["Rota", "Motorista", "Pagamento", "Segurança"];

  Future<void> _selecionarImagem() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagem = await picker.pickImage(source: ImageSource.gallery);

    if (imagem != null) {
      if (kIsWeb) {
        final bytes = await imagem.readAsBytes();
        setState(() {
          imagemSelecionada = imagem;
          imagemBytes = bytes;
        });
      } else {
        setState(() {
          imagemSelecionada = imagem;
        });
      }
    }
  }

  void _enviarRelatorio() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Relatório enviado com sucesso!")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Reportar Problema", style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            AppDropdownField<String>(
              hint: "Selecione a Corrida",
              value: corridaSelecionada,
              items: corridas,
              labelBuilder: (c) => c,
              onChanged: (v) => setState(() => corridaSelecionada = v),
            ),
            const SizedBox(height: 14),
            AppDropdownField<String>(
              hint: "Categoria do Problema",
              value: categoriaSelecionada,
              items: categorias,
              labelBuilder: (c) => c,
              onChanged: (v) => setState(() => categoriaSelecionada = v),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.smBr,
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _descricaoController,
                maxLines: 4,
                style: AppText.body(AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: "Descreva o problema",
                  hintStyle: AppText.body(AppColors.textFaint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppOutlinedButton(
              label: imagemSelecionada != null ? "Trocar Foto" : "Adicionar Foto (opcional)",
              onPressed: _selecionarImagem,
              height: 50,
            ),

            // Exibir imagem (compatível com Web e Mobile)
            if (imagemSelecionada != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ClipRRect(
                  borderRadius: AppRadius.mdBr,
                  child: ImagePreview(
                    path: kIsWeb ? null : imagemSelecionada?.path,
                    bytes: kIsWeb ? imagemBytes : null,
                  ),
                ),
              ),

            const SizedBox(height: 16),
            AppPrimaryButton(
              label: "Enviar Relatório",
              onPressed: _enviarRelatorio,
              color: AppColors.red,
              foreground: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
