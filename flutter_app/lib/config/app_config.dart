/// Configuração central do app.
///
/// CORRIGIDO: a mesma chave do Google Maps estava copiada e colada em 3
/// lugares diferentes (`profissional_home.dart`, `clienteride_flow.dart`,
/// `AndroidManifest.xml`). Isso dificulta trocar a chave (fácil esquecer um
/// dos lugares) e, pior, deixa a chave "hardcoded" em texto puro no código-
/// fonte Dart, algo que pode ser extraído de dentro do APK/IPA compilado.
///
/// Recomendação de produção: restrinja esta chave no Google Cloud Console
/// (por pacote/assinatura no Android, por bundle ID no iOS, por referer no
/// Web) e, idealmente, faça as chamadas de Directions/Places API a partir do
/// backend (o app chama o seu servidor, e só o servidor guarda a chave) em
/// vez de embutir a chave no cliente.
class AppConfig {
  // ============================================================
  // API
  // ============================================================

  /// URL base da API.
  ///
  /// Desenvolvimento:
  /// http://10.0.2.2:5000/api
  ///
  /// Produção:
  /// https://api.seudominio.com/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  /// URL base do WebSocket.
  ///
  /// Desenvolvimento:
  /// ws://10.0.2.2:5000/ws/trip/
  ///
  /// Produção:
  /// wss://api.seudominio.com/ws/trip/
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:5000/ws/trip/',
  );

  // ============================================================
  // GOOGLE MAPS
  // ============================================================

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // ============================================================
  // STRIPE
  // ============================================================

  /// Chave PUBLICÁVEL da Stripe.
  ///
  /// Nunca coloque STRIPE_SECRET_KEY no aplicativo.
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  // ============================================================
  // SUPORTE
  // ============================================================

  static const String supportWhatsAppNumber = String.fromEnvironment(
    'SUPPORT_WHATSAPP_NUMBER',
    defaultValue: '',
  );

  static const String supportPhoneNumber = String.fromEnvironment(
    'SUPPORT_PHONE_NUMBER',
    defaultValue: '',
  );
}
