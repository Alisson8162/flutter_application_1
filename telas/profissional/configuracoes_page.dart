// Adicione no topo:
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../profissional/profissional_provider.dart';
import '../login.dart'; // Supondo que tenha uma tela de login

class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfissionalProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Configurações da Conta"), backgroundColor: Colors.black),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Conta",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _item("Nome", provider.userName ?? "Não informado"),
          _item("E-mail", provider.userEmail ?? "Não informado"),
          _item("Telefone", "(11) 98765-4321"),
          _item("Foto de perfil", "Atualizar"),
          const Divider(color: Colors.grey),

          const SizedBox(height: 10),
          const Text("Segurança",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _item("Alterar senha", "•••••••"),
          _item("Verificação em duas etapas", "Ativada"),
          _item("Notificações de novo login", "Ativadas"),
          const Divider(color: Colors.grey),

          const SizedBox(height: 10),
          const Text("Privacidade",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _item("Compartilhamento de dados", "Desativado"),
          _item("Histórico de localização", "Ativado"),
          const SizedBox(height: 20),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            onPressed: () {
              provider.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LandingLoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Sair da Conta"),
          ),
        ],
      ),
    );
  }

  Widget _item(String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
    );
  }
}