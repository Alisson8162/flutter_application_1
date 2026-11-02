import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class CentralAjudaScreen extends StatefulWidget {
  const CentralAjudaScreen({super.key});

  @override
  State<CentralAjudaScreen> createState() => _CentralAjudaScreenState();
}

class _CentralAjudaScreenState extends State<CentralAjudaScreen> {
  final TextEditingController _buscaController = TextEditingController();

  final List<String> topicos = [
    "Problemas com pagamento",
    "Corrida cancelada",
    "Motorista não apareceu",
    "Problemas com rota",
    "Esqueci um item no carro",
    "Como funcionam as avaliações?"
  ];

  // CORRIGIDO: "Chat com Suporte" e "Ligar para Suporte" tinham
  // onTap: () {} - não faziam absolutamente nada. Agora abrem, de verdade,
  // uma conversa no WhatsApp (com uma mensagem inicial já preenchida
  // conforme o tópico escolhido) e o discador do telefone, respectivamente.
  Future<void> _abrirWhatsApp(BuildContext context, {String? mensagemInicial}) async {
    final numero = AppConfig.supportWhatsAppNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final texto = Uri.encodeComponent(
      mensagemInicial ?? 'Olá! Preciso de ajuda com o app FalaComigo.',
    );
    final uri = Uri.parse('https://wa.me/$numero?text=$texto');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp. Verifique se ele está instalado.')),
      );
    }
  }

  Future<void> _ligarParaSuporte(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: AppConfig.supportPhoneNumber);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível iniciar a ligação.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Central de Ajuda", style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _buscaController,
              hint: "Busque seu problema...",
              leading: Icons.search_rounded,
            ),
            const SizedBox(height: 22),
            Text("Tópicos Frequentes", style: AppText.h2(AppColors.textPrimary)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: topicos.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdBr,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListTile(
                      title: Text(topicos[index], style: AppText.bodyMedium(AppColors.textPrimary)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.textFaint),
                      // Ao tocar em um tópico, abre o WhatsApp já com uma
                      // mensagem inicial identificando o assunto - assim o
                      // atendente já sabe do que se trata a conversa.
                      onTap: () => _abrirWhatsApp(
                        context,
                        mensagemInicial: 'Olá! Preciso de ajuda com: "${topicos[index]}"',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            AppPrimaryButton(
              label: "Contatar Suporte",
              onPressed: () => _mostrarContatos(context),
              color: AppColors.blue,
              foreground: Colors.white,
              icon: Icons.support_agent_rounded,
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarContatos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Contatar Suporte", style: AppText.h2(AppColors.textPrimary)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.chat_bubble_rounded, color: AppColors.blue),
              title: Text("Chat com Suporte", style: AppText.bodyMedium(AppColors.textPrimary)),
              subtitle: Text("Abre uma conversa no WhatsApp", style: AppText.caption(AppColors.textDim)),
              onTap: () {
                Navigator.pop(sheetContext);
                _abrirWhatsApp(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_rounded, color: AppColors.green),
              title: Text("Ligar para Suporte", style: AppText.bodyMedium(AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(sheetContext);
                _ligarParaSuporte(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
