// ATENÇÃO: este é o ÚNICO ponto de entrada do app.
//
// CORRIGIDO: o projeto original tinha o app "de verdade" definido em um
// main.dart na RAIZ do projeto (fora de lib/), enquanto lib/main.dart
// continha o template padrão "contador" que o `flutter create` gera. Como o
// Flutter sempre compila a partir de lib/main.dart, rodar `flutter run`
// jamais abria o app real - sempre o contador de exemplo. Havia ainda um
// TERCEIRO `main()` dentro de telas/login.dart. Agora existe um único
// main.dart, aqui, e ele é quem registra os providers e as rotas.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'config/app_config.dart';
import 'providers/cliente_provider.dart';
import 'providers/profissional_provider.dart';
import 'services/map_service.dart';
import 'services/ws_service.dart';
import 'services/push_notification_service.dart';
import 'services/error_monitoring.dart';

import 'telas/login.dart';
import 'telas/cliente_home.dart';
import 'telas/clientemap_screen.dart';
import 'telas/central_ajuda.dart';
import 'telas/reportar_problema.dart';
import 'telas/profissional/profissional_main.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa o SDK da Stripe (necessário antes de usar CardField,
  // confirmSetupIntent, etc. em qualquer tela de pagamento).
  Stripe.publishableKey = AppConfig.stripePublishableKey;
  // Best-effort: se o Firebase ainda não tiver sido configurado
  // nativamente (google-services.json/GoogleService-Info.plist), isso não
  // trava o app - ver push_notification_service.dart.
  PushNotificationService.instance.initialize();
  // Sem SENTRY_DSN configurada (--dart-define), isso equivale a
  // runApp(const FalaComigoRootApp()) puro - ver error_monitoring.dart.
  runWithErrorMonitoring(const FalaComigoRootApp());
}

class FalaComigoRootApp extends StatelessWidget {
  const FalaComigoRootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClienteProvider()..loadUserData()),
        ChangeNotifierProvider(create: (_) => ProfissionalProvider()..loadUserData()),
        ChangeNotifierProvider(create: (_) => MapService()),
        Provider(create: (_) => WsService()),
      ],
      child: MaterialApp(
        navigatorKey: PushNotificationService.instance.navigatorKey,
        title: 'Fala Comigo - Socorro Veicular',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LandingLoginScreen(),
          '/cliente/home': (context) => const ClienteHome(),
          '/cliente/map': (context) => const ClienteMapScreen(),
          '/profissional/home': (context) => const ProfissionalMain(),
          '/ajuda': (context) => const CentralAjudaScreen(),
          '/reportar': (context) => const ReportarProblemaScreen(),
        },
      ),
    );
  }
}
