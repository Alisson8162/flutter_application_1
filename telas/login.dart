import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import '../telas/profissional/Profissional_home.dart';
import '../telas/clienteride_flow.dart';
import '../telas/cliente_home.dart';
import 'dart:typed_data';

// ENTRYPOINT ADICIONADO
void main() => runApp(const FalaComigoApp());

class FalaComigoApp extends StatelessWidget {
  const FalaComigoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fala Comigo - Socorro Veicular',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const LandingLoginScreen(),
    );
  }
}

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
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfissionalHome()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // background image
        Positioned.fill(child: Image.asset('assets/imagem/imagem.png', fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.56))),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // header: logo + support/lang
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.car_repair, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text("Fala Comigo", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
                ]),
                Row(children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.language, color: Colors.white)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.help_outline, color: Colors.white)),
                ]),
              ]),

              const SizedBox(height: 30),

              // Title
              Text("Entrar na sua conta", style: GoogleFonts.inter(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold))
                  .animate()
                  .fadeIn(delay: 100.ms),
              const SizedBox(height: 6),
              Text("Selecione seu papel e faça login", style: GoogleFonts.inter(color: Colors.white70)),

              const SizedBox(height: 24),

              // Seletor de papel (obrigatório)
              Text("Sou:", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedRole = UserRole.cliente),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedRole == UserRole.cliente ? Colors.green : Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selectedRole == UserRole.cliente ? Colors.greenAccent : Colors.transparent),
                      ),
                      child: Column(children: [
                        const Icon(Icons.person, color: Colors.white),
                        const SizedBox(height: 8),
                        Text("Sou Cliente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedRole = UserRole.profissional),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedRole == UserRole.profissional ? Colors.orange : Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selectedRole == UserRole.profissional ? Colors.orangeAccent : Colors.transparent),
                      ),
                      child: Column(children: [
                        const Icon(Icons.build, color: Colors.white),
                        const SizedBox(height: 8),
                        Text("Sou Profissional", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ]).animate().slideY(begin: 0.05, duration: 300.ms),

              const SizedBox(height: 20),

              // Input de e-mail/telefone
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.email_outlined, color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: identifierCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: "E-mail ou telefone", hintStyle: TextStyle(color: Colors.white60), border: InputBorder.none),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => preferSms = !preferSms),
                    icon: Icon(preferSms ? Icons.sms_rounded : Icons.lock_outline, color: Colors.white70),
                    tooltip: preferSms ? "Preferir SMS" : "Preferir senha",
                  ),
                ]),
              ),

              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],

              const SizedBox(height: 16),

              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : _advance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Avançar", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 16),

              // Divider + social
              Row(children: const [
                Expanded(child: Divider(color: Colors.white38)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("ou", style: TextStyle(color: Colors.white70))),
                Expanded(child: Divider(color: Colors.white38)),
              ]),
              const SizedBox(height: 12),

              SignInButton(Buttons.Google, onPressed: () {}, text: "Continuar com Google"),
              const SizedBox(height: 8),
              SignInButton(Buttons.AppleDark, onPressed: () {}, text: "Continuar com Apple"),
              const SizedBox(height: 8),

              // Cadastro CTA
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Ainda não tem conta? ", style: TextStyle(color: Colors.white70)),
                GestureDetector(
                  onTap: () {
                    if (selectedRole == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione Cliente ou Profissional antes de cadastrar.")));
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(role: selectedRole!)));
                  },
                  child: Text("Criar conta", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                )
              ]),

              const SizedBox(height: 24),

              // Footer links
              Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
                TextButton(onPressed: () {}, child: const Text("Precisa de ajuda?")),
                TextButton(onPressed: () {}, child: const Text("Política de Privacidade")),
                TextButton(onPressed: () {}, child: const Text("Termos de Uso")),
              ]),
            ]),
          ),
        ),
      ]),
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
    setState(() {
      error = null;
      loading = true;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    setState(() => loading = false);

    if (passCtrl.text.length < 4) {
      setState(() => error = "Senha inválida (mín 4 caracteres).");
      return;
    }

    // mock success
    widget.onSuccess(widget.role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirmar"), backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        Positioned.fill(child: Image.asset('assets/imagem/imagem.png', fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.64))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Entrar como ${widget.identifier}", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Senha",
                    hintStyle: const TextStyle(color: Colors.white60),
                    border: InputBorder.none,
                    suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: () => setState(() => obscure = !obscure)),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recuperação de senha (placeholder)"))), child: const Text("Esqueci minha senha")),
                IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometria (placeholder)"))), icon: const Icon(Icons.fingerprint, color: Colors.white)),
              ]),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(onPressed: loading ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Entrar")),
              )
            ]),
          ),
        )
      ]),
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

  void _sendCode() async {
    setState(() {
      sending = true;
      error = null;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() => sending = false);
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código enviado (simulado): 1234")));
  }

  void _verify() async {
    final code = codeCtrl.text.trim();
    if (code.length < 3) {
      setState(() => error = "Código inválido.");
      return;
    }
    setState(() => sending = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => sending = false);

    tries++;
    if (code != '1234') {
      setState(() => error = "Código incorreto.");
      if (tries >= 5) setState(() => error = "Muitas tentativas. Tente mais tarde.");
      return;
    }

    // sucesso
    widget.onSuccess(widget.role);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        Positioned.fill(child: Image.asset('assets/imagem/imagem.png', fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.64))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Verificar ${widget.identifier}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Enviamos um código para o seu telefone.", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, letterSpacing: 6),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: "Código (ex: 1234)", hintStyle: TextStyle(color: Colors.white60)),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(onPressed: _remaining == 0 && !sending ? _sendCode : null, child: Text(_remaining == 0 ? "Reenviar código" : "Reenviar em $_remaining s")),
                IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometria (placeholder)"))), icon: const Icon(Icons.fingerprint, color: Colors.white)),
              ]),
              const Spacer(),
              SizedBox(height: 56, width: double.infinity, child: ElevatedButton(onPressed: sending ? null : _verify, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: sending ? const CircularProgressIndicator(color: Colors.white) : const Text("Verificar"))),
            ]),
          ),
        ),
      ]),
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
  final numeroCartao = TextEditingController();
  final nomeCartao = TextEditingController();
  final validade = TextEditingController();
  final cvv = TextEditingController();
  
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

  final esp = ['Mecânico', 'Borracheiro', 'Eletricista', 'Guincho'];
  final tipos = ['Leve', 'Pesado', 'Ambos'];
  final estados = ['SP', 'RJ', 'MG', 'RS', 'PR', 'SC', 'BA', 'PE'];

  // Lista de etapas - versão diferenciada para cliente/profissional
  List<Step> get _steps {
    final isProf = widget.role == UserRole.profissional;
    
    if (isProf) {
      return [
        Step(
          title: const Text('Dados Pessoais'),
          content: _buildDadosPessoais(),
        ),
        Step(
          title: const Text('Documentos'),
          content: _buildDocumentos(),
        ),
        Step(
          title: const Text('Dados Profissionais'),
          content: _buildDadosProfissionais(),
        ),
        Step(
          title: const Text('Endereço'),
          content: _buildEndereco(),
        ),
      ];
    } else {
      return [
        Step(
          title: const Text('Dados Pessoais'),
          content: _buildDadosPessoais(),
        ),
        Step(
          title: const Text('Documentos'),
          content: _buildDocumentos(),
        ),
        Step(
          title: const Text('Endereço'),
          content: _buildEndereco(),
        ),
        Step(
          title: const Text('Pagamento'),
          content: _buildPagamento(),
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProf = widget.role == UserRole.profissional;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Cadastro - ${isProf ? 'Profissional' : 'Cliente'}'),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        Positioned.fill(child: Image.asset('assets/imagem/imagem.png', fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.68))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                children: [
                  // Indicador de progresso
                  _buildProgressIndicator(),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: Theme(
                      data: ThemeData(
                        colorScheme: const ColorScheme.light(primary: Colors.green),
                      ),
                      child: Stepper(
                        currentStep: _currentStep,
                        onStepContinue: _nextStep,
                        onStepCancel: _previousStep,
                        onStepTapped: (step) => setState(() => _currentStep = step),
                        controlsBuilder: (context, details) {
                          return const SizedBox.shrink();
                        },
                        steps: _steps,
                      ),
                    ),
                  ),
                  _buildBottomButtons(),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildProgressIndicator() {
    final totalSteps = _steps.length;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalSteps, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 4,
                decoration: BoxDecoration(
                  color: index <= _currentStep ? Colors.green : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Etapa ${_currentStep + 1} de ${_steps.length}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
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
        _field("Nome completo", name, validator: _requiredValidator),
        const SizedBox(height: 12),
        _field("E-mail", email, 
          keyboard: TextInputType.emailAddress,
          validator: _emailValidator,
        ),
        const SizedBox(height: 12),
        _field("Telefone", phone, 
          keyboard: TextInputType.phone,
          validator: _phoneValidator,
        ),
        const SizedBox(height: 12),
        _field("CPF", cpf, 
          keyboard: TextInputType.number,
          validator: _cpfValidator,
        ),
        const SizedBox(height: 12),
        _field("Senha", pass, 
          obscure: true,
          validator: _passwordValidator,
        ),
      ],
    );
  }

  Widget _buildDocumentos() {
    return Column(
      children: [
        _buildFotoField(
          'Foto do Documento (Frente) - CNH ou RG',
          _fotoDocumentoFrente,
          (image) => setState(() => _fotoDocumentoFrente = image),
        ),
        const SizedBox(height: 16),
        _buildFotoField(
          'Foto do Documento (Verso) - CNH ou RG',
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
        DropdownButtonFormField<String>(
          decoration: _dec("Especialidade"),
          dropdownColor: Colors.black87,
          value: especialidade,
          items: esp.map((e) => DropdownMenuItem(
            value: e, 
            child: Text(e, style: const TextStyle(color: Colors.white))
          )).toList(),
          onChanged: (v) => setState(() => especialidade = v),
          validator: (v) => v == null ? "Selecione" : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: _dec("Tipo de veículo atendido"),
          dropdownColor: Colors.black87,
          value: tipoVeiculo,
          items: tipos.map((e) => DropdownMenuItem(
            value: e, 
            child: Text(e, style: const TextStyle(color: Colors.white))
          )).toList(),
          onChanged: (v) => setState(() => tipoVeiculo = v),
          validator: (v) => v == null ? "Selecione" : null,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _uploadDocumentosProfissionais(),
          icon: const Icon(Icons.upload_file),
          label: const Text("Enviar documentos profissionais"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Documentos necessários: CNH, certificados, alvará",
          style: TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEndereco() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: _dec("Estado"),
          dropdownColor: Colors.black87,
          value: estado.text.isEmpty ? null : estado.text,
          items: estados.map((e) => DropdownMenuItem(
            value: e, 
            child: Text(e, style: const TextStyle(color: Colors.white))
          )).toList(),
          onChanged: (v) => setState(() => estado.text = v ?? ''),
          validator: (v) => v == null ? "Selecione o estado" : null,
        ),
        const SizedBox(height: 12),
        _field("Cidade", cidade, validator: _requiredValidator),
        const SizedBox(height: 12),
        _field("Endereço Completo", endereco, validator: _requiredValidator),
        const SizedBox(height: 12),
        _field("Bairro", TextEditingController(), validator: _requiredValidator),
        const SizedBox(height: 12),
        _field("CEP", TextEditingController(), 
          keyboard: TextInputType.number,
          validator: _requiredValidator,
        ),
      ],
    );
  }

  Widget _buildPagamento() {
    return Column(
      children: [
        const Text(
          "Cadastre seu cartão para pagamentos futuros",
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _field("Número do Cartão", numeroCartao, 
          keyboard: TextInputType.number,
          validator: _cardValidator,
        ),
        const SizedBox(height: 12),
        _field("Nome no Cartão", nomeCartao, validator: _requiredValidator),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _field("Validade (MM/AA)", validade, 
                keyboard: TextInputType.datetime,
                validator: _dateValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field("CVV", cvv, 
                keyboard: TextInputType.number,
                validator: _cvvValidator,
                obscure: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: aceita,
              onChanged: (v) => setState(() => aceita = v ?? false),
              fillColor: MaterialStateProperty.all(Colors.green),
            ),
            const Expanded(
              child: Text(
                "Aceito termos e política de privacidade",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    final isLastStep = _currentStep == _steps.length - 1;
    final isProf = widget.role == UserRole.profissional;
    
    return Column(
      children: [
        Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Voltar'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isProf ? Colors.orange : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: loading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isLastStep ? 'Finalizar Cadastro' : 'Próximo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFotoField(String label, Uint8List? image, Function(Uint8List) onImageSelected, {String? description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt, color: Colors.white70, size: 40),
                      SizedBox(height: 8),
                      Text('Clique para adicionar foto', style: TextStyle(color: Colors.white70)),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(image, fit: BoxFit.cover),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    // Simulação - Em uma implementação real, usar image_picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Funcionalidade de câmera será implementada")),
    );
  }

  void _uploadDocumentosProfissionais() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Upload de documentos profissionais (CNH, certificados, alvará)")),
    );
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
    return especialidade != null && tipoVeiculo != null;
  }

  bool _validateEndereco() {
    return estado.text.isNotEmpty && cidade.text.isNotEmpty && endereco.text.isNotEmpty;
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
    await Future.delayed(const Duration(seconds: 2));
    setState(() => loading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Cadastro realizado com sucesso!")),
    );
    
    // Redirecionar para a tela apropriada
    if (isProf) {
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const ProfissionalHome()), 
        (r) => false
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const ClienteHome()), 
        (r) => false
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

  String? _cardValidator(String? value) {
    if (value == null || value.isEmpty) return "Número do cartão obrigatório";
    if (value.length < 16) return "Cartão inválido";
    return null;
  }

  String? _dateValidator(String? value) {
    if (value == null || value.isEmpty) return "Validade obrigatória";
    if (!value.contains('/')) return "Formato MM/AA";
    return null;
  }

  String? _cvvValidator(String? value) {
    if (value == null || value.isEmpty) return "CVV obrigatório";
    if (value.length < 3) return "CVV inválido";
    return null;
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white60),
    filled: true,
    fillColor: Colors.white12,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  Widget _field(String hint, TextEditingController ctl, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: ctl,
        keyboardType: keyboard,
        obscureText: obscure,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white60),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}