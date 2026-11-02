# FalaComigo - App Flutter (cliente + profissional)

App de socorro veicular (estilo "Uber de guincho/mecânico"): clientes
solicitam atendimento, profissionais cadastrados e aprovados aceitam e
atendem. Este app conversa com o backend em `../backend` (Node/Express +
PostgreSQL).

## Configuração antes de rodar

O app precisa saber onde está o backend e as chaves públicas de Maps/Stripe.
Todas as configurações ficam centralizadas em `lib/config/app_config.dart`
e em `lib/services/api_service.dart`, e podem ser sobrescritas via
`--dart-define` sem precisar editar código:

```bash
flutter run \
  flutter run `
  --dart-define=API_BASE_URL=http://192.168.0.188:5000/api `
  --dart-define=WS_BASE_URL=ws://192.168.0.188:5000/ws/trip/ `
  --dart-define=GOOGLE_MAPS_API_KEY=SUA_CHAVE `
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_SUA_CHAVE `
  --dart-define=SUPPORT_WHATSAPP_NUMBER=SEU_NUMERO `
  --dart-define=SUPPORT_PHONE_NUMBER=SEU_NUMERO
```

Valores padrão de `API_HOST` (em `lib/services/api_service.dart`):
- Web / iOS simulator → `localhost`
- Emulador Android → `10.0.2.2` (loopback especial do emulador para a
  máquina host)
- Dispositivo físico → troque para o IP da máquina rodando o backend na
  mesma rede Wi-Fi

## Pagamentos (Stripe)

O app usa `flutter_stripe` para coletar o cartão diretamente com a Stripe -
o número do cartão nunca passa pelo nosso backend. Configure
`STRIPE_PUBLISHABLE_KEY` (a chave *publicável*, começa com `pk_`; nunca use
a chave secreta aqui) e garanta que o backend tem `STRIPE_SECRET_KEY`
configurado (ver README do backend). A tela fica em
`lib/telas/payment_methods_screen.dart`, acessível pelo menu do cliente em
"Pagamento".

## Suporte via WhatsApp

Os botões "Chat com Suporte" e "Ligar para Suporte" (`central_ajuda.dart`)
abrem, respectivamente, uma conversa no WhatsApp (`wa.me`) e o discador do
telefone, usando os números configurados em `AppConfig.supportWhatsAppNumber`
e `AppConfig.supportPhoneNumber`.

## Rodando

```bash
flutter pub get
flutter run
```

Certifique-se de que o backend (`../backend`) está rodando e acessível no
host/porta configurados acima antes de testar login, cadastro, busca de
profissionais e o fluxo de corrida.

## Estrutura

```
lib/
  main.dart                 ponto de entrada único (registra Providers e rotas)
  config/app_config.dart    chaves e configs centralizadas (Maps, Stripe, WhatsApp)
  providers/                estado + chamadas de API (cliente e profissional)
  services/                 ApiService (HTTP), WsService (WebSocket), MapService
  telas/                    todas as telas do app (cliente e profissional)
```

## Notas de produção

- A chave do Google Maps embutida no app (Directions API) deve ser
  restringida no Google Cloud Console (por assinatura/pacote no Android,
  por bundle ID no iOS). Para máxima segurança, considere proxiar as
  chamadas de Directions pelo backend.
- Configure ícone de app, splash screen e nome definitivo antes de publicar
  nas lojas (hoje usa os padrões gerados pelo `flutter create`).
