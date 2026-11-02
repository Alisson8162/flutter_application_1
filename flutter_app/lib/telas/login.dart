import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'profissional/profissional_main.dart';
import 'profissional/subscription_screen.dart';
import 'cliente_home.dart';
import '../providers/cliente_provider.dart';
import '../providers/profissional_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

// CORRIGIDO: este arquivo definia seu próprio `main()`/`FalaComigoApp`, um
// segundo (e nunca executado, pois Flutter só invoca lib/main.dart) ponto de
// entrada duplicado. O app agora tem um único ponto de entrada real:
// lib/main.dart (FalaComigoRootApp), que registra os Providers e as rotas.

/// Tipos de usuário
enum UserRole { cliente, profissional }

/// Tela principal de login com seletor obrigatório
class LandingLoginScreen extends StatefulWidget {
  const LandingLoginScreen({super.key});
  @override
  State<LandingLoginScreen> createState() => _LandingLoginScreenState();
}

class _LandingLoginScreenState extends State<LandingLoginScreen> {
  UserRole? selectedRole;
  final TextEditingController identifierCtrl = TextEditingController();
  bool preferSms = false;
  bool loading = false;
  String? error;

  void _advance() {
    setState(() => error = null);

    final value = identifierCtrl.text.trim();
    if (selectedRole == null) {
      setState(() => error = "Selecione primeiro se é Cliente ou Profissional.");
      return;
    }
    if (value.isEmpty) {
      setState(() => error = "Informe e-mail ou telefone.");
      return;
    }

    final looksLikePhone = RegExp(r'^\+?\d{8,15}$').hasMatch(value);

    // Simulação: se parece telefone ou preferSms -> fluxo SMS, senão senha
    if (looksLikePhone || preferSms) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationScreen(
            identifier: value,
            role: selectedRole!,
            onSuccess: _onLoginSuccess,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PasswordScreen(
            identifier: value,
            role: selectedRole!,
            onSuccess: _onLoginSuccess,
          ),
        ),
      );
    }
  }

  void _onLoginSuccess(UserRole role) {
    // Redireciona para tela específica dependendo do papel
    if (role == UserRole.cliente) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ClienteHome()), (r) => false);
    } else {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfissionalMain()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.roleAccent(selectedRole == UserRole.profissional);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // header: logo + support/lang
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const BrandHeader(),
                Row(children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.language, color: AppColors.textDim)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.help_outline, color: AppColors.textDim)),
                ]),
              ]),

              const SizedBox(height: 36),

              // Title
              Text("Entrar na sua conta", style: AppText.display(AppColors.textPrimary))
                  .animate()
                  .fadeIn(delay: 100.ms),
              const SizedBox(height: 6),
              Text("Selecione seu papel e faça login", style: AppText.body(AppColors.textDim)),

              const SizedBox(height: 28),

              // Seletor de papel (obrigatório)
              Text("Sou:", style: AppText.caption(AppColors.textDim)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: RoleOptionCard(
                    icon: Icons.person_rounded,
                    label: "Sou Cliente",
                    selected: selectedRole == UserRole.cliente,
                    activeColor: AppColors.green,
                    onTap: () => setState(() => selectedRole = UserRole.cliente),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RoleOptionCard(
                    icon: Icons.build_rounded,
                    label: "Sou Profissional",
                    selected: selectedRole == UserRole.profissional,
                    activeColor: AppColors.amber,
                    onTap: () => setState(() => selectedRole = UserRole.profissional),
                  ),
                ),
              ]).animate().slideY(begin: 0.05, duration: 300.ms),

              const SizedBox(height: 22),

              // Input de e-mail/telefone
              AppTextField(
                controller: identifierCtrl,
                hint: "E-mail ou telefone",
                leading: Icons.email_outlined,
                trailing: IconButton(
                  onPressed: () => setState(() => preferSms = !preferSms),
                  icon: Icon(preferSms ? Icons.sms_rounded : Icons.lock_outline, color: AppColors.textFaint),
                  tooltip: preferSms ? "Preferir SMS" : "Preferir senha",
                ),
              ),

              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: AppText.caption(AppColors.red)),
              ],

              const SizedBox(height: 20),

              AppPrimaryButton(
                label: "Avançar",
                onPressed: _advance,
                loading: loading,
                color: accent,
              ),

              const SizedBox(height: 22),

              // Divider + social
              Row(children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text("ou", style: AppText.caption(AppColors.textFaint)),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ]),
              const SizedBox(height: 16),

              // CORRIGIDO: os botões de Google/Apple eram blocos cheios com
              // texto ("Continuar com Google"/"Continuar com Apple"),
              // ocupando a largura toda e ficando grandes demais. Agora usam
              // a variante `mini` do pacote (só o ícone, circular), lado a
              // lado, no mesmo estilo compacto de apps como o Uber.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: SignInButton(
                      Buttons.Google,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  ClipOval(
                    child: SignInButton(
                      Buttons.AppleDark,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),

              // Cadastro CTA
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Ainda não tem conta? ", style: AppText.body(AppColors.textDim)),
                GestureDetector(
                  onTap: () {
                    if (selectedRole == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione Cliente ou Profissional antes de cadastrar.")));
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(role: selectedRole!)));
                  },
                  child: Text("Criar conta", style: AppText.bodyMedium(accent)),
                )
              ]),

              const SizedBox(height: 26),

              // Footer links
              Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
                TextButton(onPressed: () {}, child: Text("Precisa de ajuda?", style: AppText.caption(AppColors.textFaint))),
                TextButton(onPressed: () {}, child: Text("Política de Privacidade", style: AppText.caption(AppColors.textFaint))),
                TextButton(onPressed: () {}, child: Text("Termos de Uso", style: AppText.caption(AppColors.textFaint))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tela de senha (segunda etapa) — fluxo fake
class PasswordScreen extends StatefulWidget {
  final String identifier;
  final UserRole role;
  final void Function(UserRole) onSuccess;
  const PasswordScreen({super.key, required this.identifier, required this.role, required this.onSuccess});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController passCtrl = TextEditingController();
  bool obscure = true;
  String? error;
  bool loading = false;

  void _submit() async {
    if (passCtrl.text.length < 4) {
      setState(() => error = "Senha inválida (mín 4 caracteres).");
      return;
    }

    setState(() {
      error = null;
      loading = true;
    });

    Map<String, dynamic> result;
    if (widget.role == UserRole.cliente) {
      result = await context
          .read<ClienteProvider>()
          .loginComSenha(widget.identifier, passCtrl.text);
    } else {
      result = await context
          .read<ProfissionalProvider>()
          .loginComSenha(widget.identifier, passCtrl.text);
    }

    if (!mounted) return;
    setState(() => loading = false);

    if (result['success'] == true && result['requires2FA'] == true) {
      // Conta com 2FA ativado: precisa confirmar o código do app
      // autenticador antes de completar o login.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TwoFactorScreen(
            pendingToken: result['pendingToken'] as String,
            role: widget.role,
            onSuccess: widget.onSuccess,
          ),
        ),
      );
    } else if (result['success'] == true) {
      widget.onSuccess(widget.role);
    } else {
      setState(() => error = result['message']?.toString() ?? 'Não foi possível entrar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.roleAccent(widget.role == UserRole.profissional);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Confirmar", style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      extendBodyBehindAppBar: true,
      body: AuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Entrar como ${widget.identifier}", style: AppText.body(AppColors.textDim)),
              const SizedBox(height: 14),
              AppTextField(
                controller: passCtrl,
                hint: "Senha",
                obscureText: obscure,
                trailing: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textFaint),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: AppText.caption(AppColors.red)),
              ],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recuperação de senha (placeholder)"))),
                  child: Text("Esqueci minha senha", style: AppText.caption(accent)),
                ),
                IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometria (placeholder)"))),
                  icon: const Icon(Icons.fingerprint, color: AppColors.textDim),
                ),
              ]),
              const Spacer(),
              AppPrimaryButton(label: "Entrar", onPressed: _submit, loading: loading, color: accent, height: 56),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tela de verificação por SMS (mock)
class VerificationScreen extends StatefulWidget {
  final String identifier;
  final UserRole role;
  final void Function(UserRole) onSuccess;
  const VerificationScreen({super.key, required this.identifier, required this.role, required this.onSuccess});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController codeCtrl = TextEditingController();
  Timer? _timer;
  int _remaining = 60;
  bool sending = false;
  String? error;
  int tries = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    Future.delayed(const Duration(milliseconds: 300), () => _sendCode());
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  bool _firstSendDone = false;

  void _sendCode() async {
    setState(() {
      sending = true;
      error = null;
    });

    Map<String, dynamic> result;
    if (!_firstSendDone) {
      // Primeiro envio: back-end decide o canal (sms/email) e cria o código
      result = widget.role == UserRole.cliente
          ? await context.read<ClienteProvider>().iniciarLogin(widget.identifier, preferSms: true)
          : await context.read<ProfissionalProvider>().iniciarLogin(widget.identifier, preferSms: true);
      _firstSendDone = true;
    } else {
      if (widget.role == UserRole.cliente) {
        await context.read<ClienteProvider>().reenviarCodigo(widget.identifier);
      } else {
        await context.read<ProfissionalProvider>().reenviarCodigo(widget.identifier);
      }
      result = {'success': true};
    }

    if (!mounted) return;
    setState(() => sending = false);
    _startTimer();

    if (result['success'] == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Código enviado")));
    } else {
      setState(() => error = result['message']?.toString());
    }
  }

  void _verify() async {
    final code = codeCtrl.text.trim();
    if (code.length < 3) {
      setState(() => error = "Código inválido.");
      return;
    }
    setState(() => sending = true);

    final result = widget.role == UserRole.cliente
        ? await context.read<ClienteProvider>().verificarCodigo(widget.identifier, code)
        : await context.read<ProfissionalProvider>().verificarCodigo(widget.identifier, code);

    if (!mounted) return;
    setState(() => sending = false);

    tries++;
    if (result['success'] != true) {
      setState(() => error = result['message']?.toString() ?? "Código incorreto.");
      if (tries >= 5) setState(() => error = "Muitas tentativas. Tente mais tarde.");
      return;
    }

    if (result['requires2FA'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TwoFactorScreen(
            pendingToken: result['pendingToken'] as String,
            role: widget.role,
            onSuccess: widget.onSuccess,
          ),
        ),
      );
      return;
    }

    widget.onSuccess(widget.role);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.roleAccent(widget.role == UserRole.profissional);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      extendBodyBehindAppBar: true,
      body: AuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Verificar ${widget.identifier}", style: AppText.h1(AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text("Enviamos um código para o seu telefone.", style: AppText.body(AppColors.textDim)),
              const SizedBox(height: 20),
              AppTextField(
                controller: codeCtrl,
                hint: "Código (ex: 1234)",
                keyboardType: TextInputType.number,
                style: AppText.body(AppColors.textPrimary).copyWith(letterSpacing: 6),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: AppText.caption(AppColors.red)),
              ],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                  onPressed: _remaining == 0 && !sending ? _sendCode : null,
                  child: Text(
                    _remaining == 0 ? "Reenviar código" : "Reenviar em $_remaining s",
                    style: AppText.caption(_remaining == 0 ? accent : AppColors.textFaint),
                  ),
                ),
                IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometria (placeholder)"))),
                  icon: const Icon(Icons.fingerprint, color: AppColors.textDim),
                ),
              ]),
              const Spacer(),
              AppPrimaryButton(label: "Verificar", onPressed: _verify, loading: sending, color: accent, height: 56),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tela de confirmação do código de 2FA (app autenticador), exibida quando
/// o login com senha/OTP responde `requires2FA: true`. Recebe o
/// `pendingToken` de 5 minutos emitido pelo backend nesse momento.
class TwoFactorScreen extends StatefulWidget {
  final String pendingToken;
  final UserRole role;
  final void Function(UserRole) onSuccess;
  const TwoFactorScreen({super.key, required this.pendingToken, required this.role, required this.onSuccess});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final TextEditingController codeCtrl = TextEditingController();
  bool loading = false;
  String? error;

  void _verify() async {
    final code = codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => error = "Digite o código de 6 dígitos.");
      return;
    }

    setState(() {
      error = null;
      loading = true;
    });

    final result = widget.role == UserRole.cliente
        ? await context.read<ClienteProvider>().verificarDoisFatores(widget.pendingToken, code)
        : await context.read<ProfissionalProvider>().verificarDoisFatores(widget.pendingToken, code);

    if (!mounted) return;
    setState(() => loading = false);

    if (result['success'] == true) {
      widget.onSuccess(widget.role);
    } else {
      setState(() => error = result['message']?.toString() ?? 'Código inválido.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.roleAccent(widget.role == UserRole.profissional);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Verificação em duas etapas", style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_rounded, color: accent, size: 40),
            const SizedBox(height: 14),
            Text("Abra seu app autenticador", style: AppText.h1(AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              "Digite o código de 6 dígitos gerado para a sua conta FalaComigo.",
              style: AppText.body(AppColors.textDim),
            ),
            const SizedBox(height: 22),
            AppTextField(
              controller: codeCtrl,
              hint: "000000",
              keyboardType: TextInputType.number,
              style: AppText.h2(AppColors.textPrimary).copyWith(letterSpacing: 8),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: AppText.caption(AppColors.red)),
            ],
            const Spacer(),
            AppPrimaryButton(label: "Confirmar", onPressed: _verify, loading: loading, color: accent, height: 56),
          ]),
        ),
      ),
    );
  }
}

/// Tela de cadastro por etapas
class RegisterScreen extends StatefulWidget {
  final UserRole role;
  const RegisterScreen({super.key, required this.role});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final pass = TextEditingController();
  final cpf = TextEditingController();
  final estado = TextEditingController();
  final cidade = TextEditingController();
  final endereco = TextEditingController();
  final bairro = TextEditingController();
  final cep = TextEditingController();
  // NOVO MODELO DE NEGÓCIO: o cliente não cadastra mais cartão no app (quem
  // paga a plataforma agora é o profissional, via mensalidade) - os campos
  // de cartão que existiam aqui (numeroCartao/nomeCartao/validade/cvv) e a
  // etapa "Pagamento" do fluxo do cliente foram removidos.
  final valorBase = TextEditingController();
  final valorKm = TextEditingController();

  String? especialidade;
  String? tipoVeiculo;
  bool aceita = false;
  bool loading = false;

  // Controle das etapas
  int _currentStep = 0;
  Uint8List? _fotoUsuario;
  Uint8List? _fotoDocumentoFrente;
  Uint8List? _fotoDocumentoVerso;
  Uint8List? _fotoSelfie;
  bool _buscandoCep = false;
  String? _cepError;
  // Comprovação de que o profissional realmente atua na especialidade
  // declarada, exigida antes de liberar o cadastro no painel admin.
  Uint8List? _fotoCertificado;
  Uint8List? _fotoCarteiraTrabalho;
  Uint8List? _fotoVeiculo;

  final esp = ['Mecânico', 'Borracheiro', 'Eletricista', 'Guincho'];
  final tipos = ['Leve', 'Pesado', 'Ambos'];
  final estados = ['SP', 'RJ', 'MG', 'RS', 'PR', 'SC', 'BA', 'PE'];

  bool get _isProf => widget.role == UserRole.profissional;
  Color get _accent => AppColors.roleAccent(_isProf);

  // Lista de etapas - versão diferenciada para cliente/profissional
  List<_RegisterStep> get _steps {
    if (_isProf) {
      return [
        _RegisterStep('Dados Pessoais', _buildDadosPessoais()),
        _RegisterStep('Documentos', _buildDocumentos()),
        _RegisterStep('Dados Profissionais', _buildDadosProfissionais()),
        _RegisterStep('Endereço', _buildEndereco()),
      ];
    } else {
      return [
        _RegisterStep('Dados Pessoais', _buildDadosPessoais()),
        _RegisterStep('Documentos', _buildDocumentos()),
        _RegisterStep('Endereço', _buildEndereco()),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('Cadastro · ${_isProf ? 'Profissional' : 'Cliente'}', style: AppText.h2(AppColors.textPrimary)),
      ),
      extendBodyBehindAppBar: true,
      body: AuthBackground(
        overlayOpacity: 0.82,
        child: SafeArea(
          child: Form(
            key: _form,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: StepProgressBar(totalSteps: steps.length, currentStep: _currentStep, activeColor: _accent),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[_currentStep].title, style: AppText.h1(AppColors.textPrimary)),
                        const SizedBox(height: 18),
                        steps[_currentStep].content,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _buildBottomButtons(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDadosPessoais() {
    return Column(
      children: [
        _buildFotoField(
          'Foto do Usuário',
          _fotoUsuario,
          (image) => setState(() => _fotoUsuario = image),
        ),
        const SizedBox(height: 16),
        AppTextField(controller: name, hint: "Nome completo", useFormField: true, validator: _requiredValidator),
        const SizedBox(height: 12),
        AppTextField(
          controller: email,
          hint: "E-mail",
          keyboardType: TextInputType.emailAddress,
          useFormField: true,
          validator: _emailValidator,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: phone,
          hint: "Telefone",
          keyboardType: TextInputType.phone,
          useFormField: true,
          validator: _phoneValidator,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: cpf,
          hint: "CPF",
          keyboardType: TextInputType.number,
          useFormField: true,
          validator: _cpfValidator,
        ),
        const SizedBox(height: 12),
        AppTextField(controller: pass, hint: "Senha", obscureText: true, useFormField: true, validator: _passwordValidator),
      ],
    );
  }

  Widget _buildDocumentos() {
    return Column(
      children: [
        _buildFotoField(
          'Foto do Documento (Frente) — CNH ou RG',
          _fotoDocumentoFrente,
          (image) => setState(() => _fotoDocumentoFrente = image),
        ),
        const SizedBox(height: 16),
        _buildFotoField(
          'Foto do Documento (Verso) — CNH ou RG',
          _fotoDocumentoVerso,
          (image) => setState(() => _fotoDocumentoVerso = image),
        ),
        const SizedBox(height: 16),
        _buildFotoField(
          'Selfie com Documento',
          _fotoSelfie,
          (image) => setState(() => _fotoSelfie = image),
          description: 'Tire uma selfie segurando seu documento',
        ),
      ],
    );
  }

  Widget _buildDadosProfissionais() {
    return Column(
      children: [
        AppDropdownField<String>(
          hint: "Especialidade",
          value: especialidade,
          items: esp,
          labelBuilder: (e) => e,
          onChanged: (v) => setState(() => especialidade = v),
          validator: (v) => v == null ? "Selecione" : null,
        ),
        const SizedBox(height: 12),
        AppDropdownField<String>(
          hint: "Tipo de veículo atendido",
          value: tipoVeiculo,
          items: tipos,
          labelBuilder: (e) => e,
          onChanged: (v) => setState(() => tipoVeiculo = v),
          validator: (v) => v == null ? "Selecione" : null,
        ),
        const SizedBox(height: 16),
        Text(
          "Quanto você cobra pelo atendimento?",
          style: AppText.bodyMedium(AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          "Você define seu próprio preço - o app mostra esse valor pro cliente antes de ele te chamar",
          style: AppText.caption(AppColors.textFaint),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: valorBase,
                hint: "Taxa base (R\$)",
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                useFormField: true,
                validator: _priceValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: valorKm,
                hint: "Valor por km (R\$)",
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                useFormField: true,
                validator: _priceValidator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Comprovação profissional",
            style: AppText.bodyMedium(AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Precisamos confirmar que você realmente atua na área - sem isso, "
          "seu cadastro não é liberado no painel de aprovação.",
          style: AppText.caption(AppColors.textFaint),
        ),
        const SizedBox(height: 12),
        _buildFotoField(
          'Certificado ou diploma do curso na área',
          _fotoCertificado,
          (image) => setState(() => _fotoCertificado = image),
          description: 'Ex.: certificado de curso de mecânica, eletricista, etc.',
        ),
        const SizedBox(height: 16),
        _buildFotoField(
          'Carteira de trabalho (página com o registro na função)',
          _fotoCarteiraTrabalho,
          (image) => setState(() => _fotoCarteiraTrabalho = image),
          description: 'A página que mostra que você já trabalhou como ${especialidade ?? "profissional da área"}',
        ),
        const SizedBox(height: 16),
        _buildFotoField(
          'Foto do seu veículo de trabalho',
          _fotoVeiculo,
          (image) => setState(() => _fotoVeiculo = image),
        ),
      ],
    );
  }

  Widget _buildEndereco() {
    return Column(
      children: [
        AppTextField(
          controller: cep,
          hint: "CEP",
          keyboardType: TextInputType.number,
          useFormField: true,
          validator: _cepValidator,
          trailing: _buscandoCep
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.search_rounded, color: AppColors.textFaint),
                  onPressed: () => _buscarCep(cep.text),
                ),
        ),
        if (_cepError != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_cepError!, style: AppText.caption(AppColors.red)),
          ),
        ],
        const SizedBox(height: 12),
        AppDropdownField<String>(
          hint: "Estado",
          value: estado.text.isEmpty ? null : estado.text,
          items: estados,
          labelBuilder: (e) => e,
          onChanged: (v) => setState(() => estado.text = v ?? ''),
          validator: (v) => v == null ? "Selecione o estado" : null,
        ),
        const SizedBox(height: 12),
        AppTextField(controller: cidade, hint: "Cidade", useFormField: true, validator: _requiredValidator),
        const SizedBox(height: 12),
        AppTextField(controller: bairro, hint: "Bairro", useFormField: true, validator: _requiredValidator),
        const SizedBox(height: 12),
        AppTextField(controller: endereco, hint: "Endereço completo (rua, número)", useFormField: true, validator: _requiredValidator),
        // ATUALIZADO: agora "Endereço" é a última etapa tanto do cliente
        // quanto do profissional (a etapa "Pagamento" do cliente foi
        // removida - o cliente não paga mais dentro do app), então o
        // checkbox de termos sempre aparece aqui.
        const SizedBox(height: 18),
        _buildTermsCheckbox(),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: aceita,
          onChanged: (v) => setState(() => aceita = v ?? false),
          activeColor: AppColors.green,
          checkColor: AppColors.bg,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => aceita = !aceita),
            child: Text(
              "Aceito os termos de uso e a política de privacidade",
              style: AppText.body(AppColors.textDim),
            ),
          ),
        ),
      ],
    );
  }

  // Busca o endereço pelo CEP (ViaCEP) e preenche estado/cidade/bairro
  // automaticamente - o usuário só precisa completar rua/número.
  Future<void> _buscarCep(String rawCep) async {
    final cleanCep = rawCep.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanCep.length != 8) {
      setState(() => _cepError = 'CEP deve ter 8 dígitos');
      return;
    }

    setState(() {
      _buscandoCep = true;
      _cepError = null;
    });

    try {
      final response = await http
          .get(Uri.parse('https://viacep.com.br/ws/$cleanCep/json/'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['erro'] == true) {
        setState(() => _cepError = 'CEP não encontrado');
      } else {
        setState(() {
          bairro.text = data['bairro']?.toString() ?? bairro.text;
          cidade.text = data['localidade']?.toString() ?? cidade.text;
          estado.text = data['uf']?.toString() ?? estado.text;
          if ((data['logradouro']?.toString() ?? '').isNotEmpty && endereco.text.isEmpty) {
            endereco.text = data['logradouro'].toString();
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cepError = 'Não foi possível buscar o CEP agora');
    } finally {
      if (mounted) setState(() => _buscandoCep = false);
    }
  }

  Widget _buildBottomButtons() {
    final isLastStep = _currentStep == _steps.length - 1;

    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(child: AppOutlinedButton(label: 'Voltar', onPressed: _previousStep, height: 52)),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: _currentStep > 0 ? 1 : 1,
          child: AppPrimaryButton(
            label: isLastStep ? 'Finalizar Cadastro' : 'Próximo',
            onPressed: _nextStep,
            loading: loading,
            color: _accent,
            height: 52,
          ),
        ),
      ],
    );
  }

  Widget _buildFotoField(String label, Uint8List? image, Function(Uint8List) onImageSelected, {String? description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption(AppColors.textDim)),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description, style: AppText.caption(AppColors.textFaint)),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickImage(onImageSelected),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.mdBr,
              border: Border.all(color: AppColors.border),
            ),
            child: image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded, color: AppColors.textFaint, size: 34),
                      const SizedBox(height: 8),
                      Text('Toque para tirar ou escolher uma foto', style: AppText.caption(AppColors.textDim)),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.mdBr,
                        child: Image.memory(image, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // Deixa escolher entre câmera e galeria, e entrega os bytes da imagem pro
  // callback do campo específico que foi tocado (foto do usuário, documento
  // frente/verso, ou selfie - cada um guarda o resultado no seu próprio
  // estado).
  Future<void> _pickImage(Function(Uint8List) onImageSelected) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.textPrimary),
              title: Text('Tirar foto', style: AppText.bodyMedium(AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.textPrimary),
              title: Text('Escolher da galeria', style: AppText.bodyMedium(AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      onImageSelected(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível acessar a câmera/galeria: $e')),
      );
    }
  }

  void _nextStep() {
    // Validar a etapa atual antes de avançar
    if (_currentStep == 0 && !_validateDadosPessoais()) return;
    if (_currentStep == 1 && !_validateDocumentos()) return;
    if (_currentStep == 2 && widget.role == UserRole.profissional && !_validateDadosProfissionais()) return;
    if (_currentStep == 2 && widget.role == UserRole.cliente && !_validateEndereco()) return;

    if (_currentStep == _steps.length - 1) {
      _submit();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  bool _validateDadosPessoais() {
    return name.text.isNotEmpty &&
           email.text.isNotEmpty &&
           phone.text.isNotEmpty &&
           cpf.text.isNotEmpty &&
           pass.text.isNotEmpty;
  }

  bool _validateDocumentos() {
    return _fotoUsuario != null &&
           _fotoDocumentoFrente != null &&
           _fotoDocumentoVerso != null &&
           _fotoSelfie != null;
  }

  bool _validateDadosProfissionais() {
    if (especialidade == null || tipoVeiculo == null) return false;
    final base = double.tryParse(valorBase.text.replaceAll(',', '.'));
    final km = double.tryParse(valorKm.text.replaceAll(',', '.'));
    if (base == null || base < 0 || km == null || km < 0) return false;
    if (_fotoCertificado == null || _fotoCarteiraTrabalho == null || _fotoVeiculo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Envie o certificado, a carteira de trabalho e a foto do veículo para continuar.",
          ),
        ),
      );
      return false;
    }
    return true;
  }

  String? _priceValidator(String? value) {
    if (value == null || value.isEmpty) return "Obrigatório";
    final n = double.tryParse(value.replaceAll(',', '.'));
    if (n == null || n < 0) return "Valor inválido";
    return null;
  }

  bool _validateEndereco() {
    return estado.text.isNotEmpty &&
        cidade.text.isNotEmpty &&
        endereco.text.isNotEmpty &&
        bairro.text.isNotEmpty &&
        cep.text.isNotEmpty;
  }

  void _submit() async {
    if (!_form.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos corretamente.")),
      );
      return;
    }

    final isProf = widget.role == UserRole.profissional;

    if (isProf && (especialidade == null || tipoVeiculo == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione especialidade e tipo de veículo.")),
      );
      return;
    }

    if (!aceita) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aceite os termos.")),
      );
      return;
    }

    setState(() => loading = true);

    final identifier = email.text.trim();
    final phoneDigits = phone.text.trim();

    Map<String, dynamic> result;
    if (isProf) {
      result = await context.read<ProfissionalProvider>().registrar(
            name: name.text.trim(),
            email: identifier.isNotEmpty ? identifier : null,
            phone: phoneDigits.isNotEmpty ? phoneDigits : null,
            cpf: cpf.text.trim(),
            password: pass.text,
            especialidade: especialidade!,
            tipoVeiculoAtendido: tipoVeiculo!,
            valorBase: double.parse(valorBase.text.replaceAll(',', '.')),
            valorKm: double.parse(valorKm.text.replaceAll(',', '.')),
          );
    } else {
      result = await context.read<ClienteProvider>().registrar(
            name: name.text.trim(),
            email: identifier.isNotEmpty ? identifier : null,
            phone: phoneDigits.isNotEmpty ? phoneDigits : null,
            cpf: cpf.text.trim(),
            password: pass.text,
          );
    }

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Erro ao cadastrar')),
      );
      return;
    }

    // A partir daqui o app já está autenticado (o provider salvou o token).
    // Envia endereço e as fotos/documentos coletados nas etapas anteriores -
    // falhas aqui não desfazem o cadastro (a conta já existe), só avisam o
    // usuário para tentar de novo depois, pelo perfil.
    final addressResult = await ApiService.post('/users/address', {
      'estado': estado.text.trim(),
      'cidade': cidade.text.trim(),
      'endereco_completo': endereco.text.trim(),
      'bairro': bairro.text.trim(),
      'cep': cep.text.replaceAll(RegExp(r'[^0-9]'), ''),
    });

    final documentFiles = <String, Uint8List>{
      if (_fotoUsuario != null) 'foto_usuario': _fotoUsuario!,
      if (_fotoDocumentoFrente != null) 'documento_frente': _fotoDocumentoFrente!,
      if (_fotoDocumentoVerso != null) 'documento_verso': _fotoDocumentoVerso!,
      if (_fotoSelfie != null) 'selfie': _fotoSelfie!,
    };
    final documentsResult = documentFiles.isNotEmpty
        ? await ApiService.uploadFiles('/users/documents', documentFiles)
        : {'success': true};

    Map<String, dynamic> professionalDocsResult = {'success': true};
    if (isProf) {
      final profFiles = <String, Uint8List>{
        if (_fotoCertificado != null) 'certificado': _fotoCertificado!,
        if (_fotoCarteiraTrabalho != null) 'carteira_trabalho': _fotoCarteiraTrabalho!,
        if (_fotoVeiculo != null) 'foto_veiculo': _fotoVeiculo!,
        if (_fotoSelfie != null) 'selfie': _fotoSelfie!,
      };
      if (profFiles.isNotEmpty) {
        professionalDocsResult = await ApiService.uploadFiles('/professionals/documents', profFiles);
      }
    }

    if (!mounted) return;
    setState(() => loading = false);

    final falhas = <String>[
      if (addressResult['success'] != true) 'endereço',
      if (documentsResult['success'] != true) 'documentos',
      if (professionalDocsResult['success'] != true) 'documentos profissionais',
    ];

    if (falhas.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cadastro criado! Não foi possível enviar: ${falhas.join(', ')}. '
            'Você pode reenviar depois pelo seu perfil.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cadastro realizado com sucesso!")),
      );
    }

    // Redirecionar para a tela apropriada.
    // Profissional vai primeiro para a tela de assinatura - a conta só fica
    // realmente ativa (pode ficar online) depois da mensalidade confirmada.
    // (SubscriptionScreen tem um botão "Continuar sem assinar agora" que
    // leva para ProfissionalMain, caso a pessoa prefira fazer isso depois.)
    if (isProf) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen(fromRegistration: true)),
        (r) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ClienteHome()),
        (r) => false,
      );
    }
  }

  // Validadores (mantidos os mesmos)
  String? _requiredValidator(String? value) {
    if (value == null || value.isEmpty) return "Campo obrigatório";
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.isEmpty) return "E-mail obrigatório";
    if (!value.contains('@')) return "E-mail inválido";
    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.isEmpty) return "Telefone obrigatório";
    if (value.length < 10) return "Telefone inválido";
    return null;
  }

  String? _cpfValidator(String? value) {
    if (value == null || value.isEmpty) return "CPF obrigatório";
    if (value.length < 11) return "CPF inválido";
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return "Senha obrigatória";
    if (value.length < 6) return "Mínimo 6 caracteres";
    return null;
  }

  String? _cepValidator(String? value) {
    if (value == null || value.isEmpty) return "CEP obrigatório";
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 8) return "CEP inválido";
    return null;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    pass.dispose();
    cpf.dispose();
    estado.dispose();
    cidade.dispose();
    endereco.dispose();
    bairro.dispose();
    cep.dispose();
    valorBase.dispose();
    valorKm.dispose();
    super.dispose();
  }
}

/// Par (título, conteúdo) de uma etapa do cadastro. Substitui o `Step` do
/// Stepper padrão do Material porque o layout novo desenha o cabeçalho e a
/// barra de progresso manualmente (StepProgressBar), então não precisamos
/// mais do Stepper embutido.
class _RegisterStep {
  final String title;
  final Widget content;
  const _RegisterStep(this.title, this.content);
}
