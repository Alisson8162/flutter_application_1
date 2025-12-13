import 'package:flutter/material.dart';
import 'profissional_home.dart';
import '../profissional/ganhos_page.dart';
import 'preferencias_page.dart';
import '../profissional/configuracoes_page.dart';

class ProfissionalMain extends StatefulWidget {
  const ProfissionalMain({super.key});

  @override
  State<ProfissionalMain> createState() => _ProfissionalMainState();
}

class _ProfissionalMainState extends State<ProfissionalMain> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ProfissionalHome(),
    const GanhosPage(),
    const PreferenciasPage(),
    const ConfiguracoesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Ganhos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Preferências',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Conta',
          ),
        ],
      ),
    );
  }
}