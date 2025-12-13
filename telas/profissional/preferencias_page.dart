// lib/screens/profissional/preferencias_page.dart
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Preferências"), backgroundColor: Colors.black),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Viagens",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _switch("Conversa com o cliente", conversasAtivas, (v) => setState(() => conversasAtivas = v)),
          _switch("Acesso para deficientes", acessibilidade, (v) => setState(() => acessibilidade = v)),

          const Divider(color: Colors.grey),
          const Text("Notificações",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _switch("Push", notificacoesPush, (v) => setState(() => notificacoesPush = v)),
          _switch("E-mail", notificacoesEmail, (v) => setState(() => notificacoesEmail = v)),
          _switch("SMS", notificacoesSms, (v) => setState(() => notificacoesSms = v)),

          const Divider(color: Colors.grey),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: const Text("Salvar Preferências", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _switch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      activeColor: Colors.greenAccent,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      value: value,
      onChanged: onChanged,
    );
  }
}
