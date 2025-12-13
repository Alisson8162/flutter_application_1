import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../telas/image_display_mobile.dart';
import '../telas/image_display_web.dart';

// Import condicional: escolhe a implementação correta conforme a plataforma
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
      appBar: AppBar(
        title: const Text("Reportar Problema"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: corridaSelecionada,
              decoration:
                  const InputDecoration(labelText: "Selecione a Corrida"),
              items: corridas
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => corridaSelecionada = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: categoriaSelecionada,
              decoration:
                  const InputDecoration(labelText: "Categoria do Problema"),
              items: categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => categoriaSelecionada = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descricaoController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Descreva o problema",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _selecionarImagem,
              icon: const Icon(Icons.photo),
              label: const Text("Adicionar Foto (opcional)"),
            ),

            // Exibir imagem (compatível com Web e Mobile)
            if (imagemSelecionada != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: kIsWeb
                    ? ImageDisplayWeb(bytes: imagemBytes!)
                    : ImageDisplayMobile(path: imagemSelecionada!.path),
              ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _enviarRelatorio,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Enviar Relatório"),
            ),
          ],
        ),
      ),
    );
  }
}
