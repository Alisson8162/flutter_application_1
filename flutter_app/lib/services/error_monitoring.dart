import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Monitoramento de erros em produção (Sentry). Sem a DSN configurada, o
/// app roda exatamente como antes desta integração - `runWithErrorMonitoring`
/// simplesmente chama `runApp(app)` direto, sem nenhuma inicialização extra.
///
/// Para ativar, rode o app com:
///   flutter run --dart-define=SENTRY_DSN=https://sua-dsn@sentry.io/projeto
/// (ou configure isso no seu pipeline de build/CI para os builds de
/// produção - nunca deixe a DSN hardcoded no repositório).
class ErrorMonitoring {
  ErrorMonitoring._();

  static const String _dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  static bool get isConfigured => _dsn.isNotEmpty;
}

/// Substitui a chamada direta a `runApp(app)` no main(). Quando a DSN não
/// está configurada, o comportamento é idêntico a `runApp(app)` puro.
Future<void> runWithErrorMonitoring(Widget app) async {
  if (!ErrorMonitoring.isConfigured) {
    runApp(app);
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = ErrorMonitoring._dsn;
      options.tracesSampleRate = 0.1;
      options.environment = kReleaseMode ? 'production' : 'development';
    },
    appRunner: () => runApp(app),
  );
}
