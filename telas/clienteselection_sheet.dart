import 'package:flutter/material.dart';

class SelectionSheet extends StatelessWidget {
  final void Function(String tipo, Map<String,dynamic> estimativa) onRequest;
  const SelectionSheet({super.key, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      maxChildSize: 0.9,
      minChildSize: 0.25,
      builder: (_, ctl) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: ctl,
            children: [
              Center(child: Container(height: 4, width: 60, color: Colors.white24)),
              const SizedBox(height: 12),
              const Text("Escolha um profissional", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _optionCard(context, "Mecânico (Leve)", "5-8 min • R\$ 30", "leve"),
              const SizedBox(height: 8),
              _optionCard(context, "Guincho (Pesado)", "15-25 min • R\$ 120", "pesado"),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ],
          ),
        );
      },
    );
  }

  Widget _optionCard(BuildContext ctx, String title, String subtitle, String tipo) {
    return Card(
      color: Colors.white10,
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
        trailing: ElevatedButton(
          onPressed: () {
            // estimativa simples
            onRequest(tipo, {'eta': tipo == 'leve' ? 8 : 22, 'price': tipo == 'leve' ? 30 : 120});
            // Fecha o bottom sheet
            Navigator.of(ctx).pop();
          }, 
          child: const Text("Selecionar")
        ),
      ),
    );
  }
}
