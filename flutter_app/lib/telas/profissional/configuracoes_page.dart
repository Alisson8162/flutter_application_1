// Adicione no topo:
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../../providers/profissional_provider.dart';
import '../login.dart'; // Supondo que tenha uma tela de login
import '../two_factor_settings_screen.dart';
import 'editar_precos_screen.dart';
import '../../theme/app_theme.dart';

class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfissionalProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Configurações da Conta", style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle("Conta"),
          _sectionCard([
            _item("Nome", provider.userName ?? "Não informado"),
            _item("E-mail", provider.userEmail ?? "Não informado"),
            _item("Telefone", "(11) 98765-4321"),
            _item(
              "Meus preços",
              provider.valorBase != null && provider.valorKm != null
                  ? "Base R\$ ${provider.valorBase!.toStringAsFixed(2)} + R\$ ${provider.valorKm!.toStringAsFixed(2)}/km"
                  : "Não definido",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditarPrecosScreen()),
                );
              },
            ),
            _item("Foto de perfil", "Atualizar", last: true),
          ]),

          _sectionTitle("Segurança"),
          _sectionCard([
            _item("Alterar senha", "•••••••"),
            _item(
              "Verificação em duas etapas",
              provider.twoFactorEnabled ? "Ativada" : "Desativada",
              last: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TwoFactorSettingsScreen(
                      initiallyEnabled: provider.twoFactorEnabled,
                      onSetup: provider.iniciarConfiguracao2FA,
                      onEnable: provider.ativar2FA,
                      onDisable: provider.desativar2FA,
                      accent: AppColors.amber,
                    ),
                  ),
                );
              },
            ),
          ]),

          _sectionTitle("Privacidade"),
          _sectionCard([
            _item("Compartilhamento de dados", "Desativado"),
            _item("Histórico de localização", "Ativado", last: true),
          ]),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.redDim,
                foregroundColor: AppColors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
              ),
              onPressed: () {
                provider.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LandingLoginScreen()),
                  (route) => false,
                );
              },
              child: Text("Sair da Conta", style: AppText.button(AppColors.red)),
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

  Widget _item(String title, String subtitle, {bool last = false, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListTile(
        title: Text(title, style: AppText.bodyMedium(AppColors.textPrimary)),
        subtitle: Text(subtitle, style: AppText.caption(AppColors.textDim)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.textFaint),
        onTap: onTap,
      ),
    );
  }
}
