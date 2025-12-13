import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Central de Ajuda"),
        backgroundColor: Colors.indigoAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: "Busque seu problema...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Tópicos Frequentes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: topicos.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(topicos[index]),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {},
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _mostrarContatos(context);
              },
              icon: const Icon(Icons.support_agent),
              label: const Text("Contatar Suporte"),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarContatos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Contatar Suporte",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.indigoAccent),
              title: const Text("Chat com Suporte"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text("Ligar para Suporte"),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
