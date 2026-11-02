import 'package:flutter/material.dart';
import 'profissional_home.dart';
import '../profissional/ganhos_page.dart';
import 'preferencias_page.dart';
import '../profissional/configuracoes_page.dart';
import '../../theme/app_theme.dart';

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
      backgroundColor: AppColors.bg,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.amber,
            unselectedItemColor: AppColors.textFaint,
            selectedLabelStyle: AppText.caption(AppColors.amber),
            unselectedLabelStyle: AppText.caption(AppColors.textFaint),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.attach_money_rounded),
                label: 'Ganhos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.tune_rounded),
                label: 'Preferências',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Conta',
              ),
            ],
          ),
        ),
      ),
    );
  }
}