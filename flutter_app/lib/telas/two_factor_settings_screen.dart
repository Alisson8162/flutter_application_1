import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Tela de ativar/desativar a verificação em duas etapas (2FA/TOTP).
///
/// Recebe as ações como callbacks em vez de depender diretamente de
/// ClienteProvider ou ProfissionalProvider - os dois têm exatamente os
/// mesmos três métodos (iniciarConfiguracao2FA/ativar2FA/desativar2FA), então
/// não faz sentido duplicar esta tela inteira para cada papel.
class TwoFactorSettingsScreen extends StatefulWidget {
  final bool initiallyEnabled;
  final Future<Map<String, dynamic>> Function() onSetup;
  final Future<Map<String, dynamic>> Function(String code) onEnable;
  final Future<Map<String, dynamic>> Function(String code) onDisable;
  final Color accent;

  const TwoFactorSettingsScreen({
    super.key,
    required this.initiallyEnabled,
    required this.onSetup,
    required this.onEnable,
    required this.onDisable,
    this.accent = AppColors.green,
  });

  @override
  State<TwoFactorSettingsScreen> createState() => _TwoFactorSettingsScreenState();
}

enum _Step { intro, showSecret, disable }

class _TwoFactorSettingsScreenState extends State<TwoFactorSettingsScreen> {
  late bool enabled = widget.initiallyEnabled;
  _Step step = _Step.intro;
  String? secret;
  String? otpauthUrl;
  final codeCtrl = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> _startSetup() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await widget.onSetup();
    setState(() => loading = false);

    if (result['success'] == true) {
      setState(() {
        secret = result['secret'] as String?;
        otpauthUrl = result['otpauthUrl'] as String?;
        step = _Step.showSecret;
      });
    } else {
      setState(() => error = result['message']?.toString() ?? 'Não foi possível iniciar a configuração.');
    }
  }

  Future<void> _confirmEnable() async {
    final code = codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => error = 'Digite o código de 6 dígitos.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final result = await widget.onEnable(code);
    setState(() => loading = false);

    if (result['success'] == true) {
      setState(() {
        enabled = true;
        step = _Step.intro;
        codeCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verificação em duas etapas ativada.')),
        );
      }
    } else {
      setState(() => error = result['message']?.toString() ?? 'Código inválido.');
    }
  }

  Future<void> _confirmDisable() async {
    final code = codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => error = 'Digite o código de 6 dígitos.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final result = await widget.onDisable(code);
    setState(() => loading = false);

    if (result['success'] == true) {
      setState(() {
        enabled = false;
        step = _Step.intro;
        codeCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verificação em duas etapas desativada.')),
        );
      }
    } else {
      setState(() => error = result['message']?.toString() ?? 'Código inválido.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Verificação em duas etapas', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (step) {
      case _Step.showSecret:
        return _buildShowSecret();
      case _Step.disable:
        return _buildCodeEntry(
          title: 'Confirme para desativar',
          subtitle: 'Digite o código atual do app autenticador para desativar a proteção.',
          onConfirm: _confirmDisable,
          confirmLabel: 'Desativar',
          danger: true,
        );
      case _Step.intro:
        return _buildIntro();
    }
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: enabled ? AppColors.greenDim : AppColors.surfaceElevated,
            borderRadius: AppRadius.mdBr,
            border: Border.all(color: enabled ? AppColors.green : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                enabled ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: enabled ? AppColors.green : AppColors.textDim,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  enabled ? 'Ativada nesta conta' : 'Desativada nesta conta',
                  style: AppText.bodyMedium(enabled ? AppColors.green : AppColors.textDim),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Com a verificação em duas etapas ativada, além da senha você precisa '
          'digitar um código gerado por um app autenticador (Google Authenticator, '
          'Authy, etc.) toda vez que fizer login.',
          style: AppText.body(AppColors.textDim),
        ),
        const Spacer(),
        if (error != null) ...[
          Text(error!, style: AppText.caption(AppColors.red)),
          const SizedBox(height: 10),
        ],
        AppPrimaryButton(
          label: enabled ? 'Desativar' : 'Ativar verificação em duas etapas',
          onPressed: enabled ? () => setState(() => step = _Step.disable) : _startSetup,
          loading: loading,
          color: enabled ? AppColors.red : widget.accent,
        ),
      ],
    );
  }

  Widget _buildShowSecret() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Escaneie ou digite manualmente', style: AppText.h2(AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Abra seu app autenticador e adicione uma conta usando o código abaixo '
          '(ou, se o app suportar, cole a URI otpauth completa).',
          style: AppText.body(AppColors.textDim),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.mdBr,
            border: Border.all(color: AppColors.border),
          ),
          child: SelectableText(
            secret ?? '',
            style: AppText.h2(AppColors.textPrimary).copyWith(letterSpacing: 2, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: codeCtrl,
          hint: '000000',
          keyboardType: TextInputType.number,
          style: AppText.h2(AppColors.textPrimary).copyWith(letterSpacing: 8),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: AppText.caption(AppColors.red)),
        ],
        const Spacer(),
        AppPrimaryButton(label: 'Confirmar e ativar', onPressed: _confirmEnable, loading: loading, color: widget.accent),
      ],
    );
  }

  Widget _buildCodeEntry({
    required String title,
    required String subtitle,
    required VoidCallback onConfirm,
    required String confirmLabel,
    bool danger = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.h2(AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(subtitle, style: AppText.body(AppColors.textDim)),
        const SizedBox(height: 22),
        AppTextField(
          controller: codeCtrl,
          hint: '000000',
          keyboardType: TextInputType.number,
          style: AppText.h2(AppColors.textPrimary).copyWith(letterSpacing: 8),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: AppText.caption(AppColors.red)),
        ],
        const Spacer(),
        AppPrimaryButton(
          label: confirmLabel,
          onPressed: onConfirm,
          loading: loading,
          color: danger ? AppColors.red : widget.accent,
        ),
        const SizedBox(height: 10),
        AppOutlinedButton(label: 'Cancelar', onPressed: () => setState(() => step = _Step.intro)),
      ],
    );
  }
}
