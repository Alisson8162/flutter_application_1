import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

/// Push notifications (FCM). Cobre: nova corrida disponível (profissional),
/// corrida aceita/iniciada/concluída/cancelada, e nova mensagem de chat -
/// ver os pontos correspondentes no backend (rideController.js e
/// messageController.js, todos usando utils/pushService.js).
///
/// IMPORTANTE - precisa de configuração externa que este arquivo não faz
/// sozinho (e que eu não tenho como fazer sem acesso a um projeto Firebase
/// real):
///   1. Criar (ou reaproveitar) um projeto no Firebase Console.
///   2. Baixar google-services.json e colocar em android/app/.
///   3. Baixar GoogleService-Info.plist e adicionar em ios/Runner/ (via
///      Xcode - arrastando o arquivo pro projeto, marcando "Copy if
///      needed").
///   4. Ativar o plugin do Google Services no Gradle (ver a documentação
///      oficial do FlutterFire: firebase.flutter.dev).
///   5. No Firebase Console > Cloud Messaging, subir a chave/certificado
///      APNs para o iOS funcionar.
///   6. No backend, configurar FIREBASE_SERVICE_ACCOUNT_JSON ou
///      FIREBASE_SERVICE_ACCOUNT_PATH com uma chave de conta de serviço do
///      MESMO projeto Firebase (ver backend/config/firebase.js).
///
/// Sem esses arquivos nativos, `Firebase.initializeApp()` lança uma
/// exceção - por isso TODA a inicialização aqui é best-effort dentro de
/// try/catch: o app continua funcionando normalmente sem push enquanto essa
/// configuração não existir.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  /// Usada no MaterialApp (main.dart) para permitir mostrar um banner de
  /// notificação em primeiro plano e navegar ao tocar numa notificação, sem
  /// precisar passar BuildContext por todo o app.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;
  String? _lastToken;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      debugPrint('Push notifications indisponíveis (Firebase não configurado ainda): $e');
      return;
    }

    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // Usuário recusou ou a plataforma não perguntou (Android < 13 não
      // pede permissão explícita) - segue o fluxo normalmente.
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _lastToken = token;
      _sendTokenToBackend(token);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);
  }

  /// Chamar depois de um login bem-sucedido (precisa do JWT já salvo para
  /// registrar o token no backend).
  Future<void> registerTokenWithBackend() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _lastToken = token;
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Falha ao obter/registrar token FCM: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await ApiService.post('/notifications/register-token', {'token': token, 'platform': platform});
  }

  /// Chamar no logout - evita continuar recebendo push depois de sair.
  Future<void> unregisterToken() async {
    if (_lastToken == null) return;
    await ApiService.post('/notifications/unregister-token', {'token': _lastToken});
    _lastToken = null;
  }

  // App em primeiro plano: a FCM não mostra notificação de sistema
  // automaticamente nesse caso, então mostramos um aviso simples dentro do
  // próprio app.
  void _handleForegroundMessage(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? 'Fala Comigo';
    final body = message.notification?.body ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body.isNotEmpty ? '$title: $body' : title),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // App aberto a partir de um toque na notificação (segundo plano ou
  // fechado). O `data` de cada notificação (type/ride_id) é definido no
  // backend - ver utils/pushService.js e os controllers que o chamam.
  void _handleNotificationTap(RemoteMessage message) {
    // Deixado como ponto de extensão: cada tela que precisar reagir a um
    // tipo específico de notificação (ex.: abrir a corrida ao tocar em
    // "corrida aceita") pode usar `navigatorKey.currentState` e
    // `message.data['type']`/`message.data['ride_id']` para navegar.
    debugPrint('Notificação tocada: ${message.data}');
  }
}
