// lib/telas/profissional/preferencias_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

/// CORRIGIDO: as preferências eram apenas estado local perdido ao fechar o
/// app - o botão "Salvar Preferências" não fazia nada. Agora os valores são
/// persistidos localmente (SharedPreferences) e recarregados na próxima
/// abertura da tela.
class PreferenciasPage extends StatefulWidget {
  const PreferenciasPage({super.key});

  @override
  State<PreferenciasPage> createState() => _PreferenciasPageState();
}

class _PreferenciasPageState extends State<PreferenciasPage> {
  bool notificacoesPush = true;
  bool notificacoesEmail = false;
  bool notificacoesSms = true;
  bool conversasAtivas = true;
  bool acessibilidade = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificacoesPush = prefs.getBool('pref_notificacoes_push') ?? true;
      notificacoesEmail = prefs.getBool('pref_notificacoes_email') ?? false;
      notificacoesSms = prefs.getBool('pref_notificacoes_sms') ?? true;
      conversasAtivas = prefs.getBool('pref_conversas_ativas') ?? true;
      acessibilidade = prefs.getBool('pref_acessibilidade') ?? false;
      _loading = false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_notificacoes_push', notificacoesPush);
    await prefs.setBool('pref_notificacoes_email', notificacoesEmail);
    await prefs.setBool('pref_notificacoes_sms', notificacoesSms);
    await prefs.setBool('pref_conversas_ativas', conversasAtivas);
    await prefs.setBool('pref_acessibilidade', acessibilidade);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferências salvas com sucesso!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Preferências", style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle("Viagens"),
          _sectionCard([
            _switch("Conversa com o cliente", conversasAtivas, (v) => setState(() => conversasAtivas = v)),
            _switch("Acesso para deficientes", acessibilidade, (v) => setState(() => acessibilidade = v), last: true),
          ]),

          _sectionTitle("Notificações"),
          _sectionCard([
            _switch("Push", notificacoesPush, (v) => setState(() => notificacoesPush = v)),
            _switch("E-mail", notificacoesEmail, (v) => setState(() => notificacoesEmail = v)),
            _switch("SMS", notificacoesSms, (v) => setState(() => notificacoesSms = v), last: true),
          ]),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
              ),
              child: Text("Salvar Preferências", style: AppText.button(const Color(0xFF201400))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(title, style: AppText.caption(AppColors.textDim)),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _switch(String title, bool value, Function(bool) onChanged, {bool last = false}) {
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SwitchListTile(
        activeColor: AppColors.amber,
        title: Text(title, style: AppText.bodyMedium(AppColors.textPrimary)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
