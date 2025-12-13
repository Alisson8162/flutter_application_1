// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'telas/central_ajuda.dart';
import 'telas/login.dart';
import 'telas/clientemap_screen.dart';
import 'telas/clienteselection_sheet.dart';
import 'telas/clienteride_flow.dart';
import 'telas/map_service.dart';
import 'lib/services/ws_service.dart';
import 'telas/cliente_home.dart';
import 'telas/reportar_problema.dart';
import 'telas/profissional/profissional_main.dart'; // ←
import 'telas/profissional/profissional_provider.dart'; // ← ADICIONADO
import 'telas/map_service.dart'; // Se este arquivo existe

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapService()),
        ChangeNotifierProvider(create: (_) => ProfissionalProvider()),
      ],
      child: MaterialApp(
        title: 'Fala Comigo - Socorro Veicular',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => FalaComigoApp(),
          '/login': (context) => LandingLoginScreen(),
          '/cliente/map': (context) => ClienteMapScreen(),
          '/profissional/home': (context) => ProfissionalMain(),
          '/cliente/home': (context) => ClienteHome(),
          '/ajuda': (context) => const CentralAjudaScreen(),
          '/reportar': (context) => const ReportarProblemaScreen(),
        },
      ),
    );
  }
}