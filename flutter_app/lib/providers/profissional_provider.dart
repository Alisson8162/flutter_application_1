import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';

/// Estado do profissional logado + autenticação e disponibilidade.
///
/// CORRIGIDO: não existia nenhum método de login/cadastro aqui - a tela de
/// login (telas/login.dart) nunca persistia sessão de profissional nenhuma.
class ProfissionalProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userCpf;
  String? _fotoUrl;
  String? _especialidade;
  String? _tipoVeiculoAtendido;
  double _avaliacaoMedia = 0;
  int _totalAvaliacoes = 0;
  bool _documentacaoAprovada = false;
  bool _contaAtiva = false;
  double? _valorBase;
  double? _valorKm;
  bool _twoFactorEnabled = false;
  bool _isOnline = false;
  bool _hasActiveRide = false;
  bool _loadingPerfil = false;
  String? _lastError;

  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  String? get userCpf => _userCpf;
  String? get fotoUrl => _fotoUrl;
  String? get especialidade => _especialidade;
  String? get tipoVeiculoAtendido => _tipoVeiculoAtendido;
  double get avaliacaoMedia => _avaliacaoMedia;
  int get totalAvaliacoes => _totalAvaliacoes;
  bool get documentacaoAprovada => _documentacaoAprovada;
  bool get contaAtiva => _contaAtiva;
  double? get valorBase => _valorBase;
  double? get valorKm => _valorKm;
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get isOnline => _isOnline;
  bool get hasActiveRide => _hasActiveRide;
  bool get loadingPerfil => _loadingPerfil;
  String? get lastError => _lastError;

  bool get isAuthenticated => _token != null;

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _userName = prefs.getString('userName');
    _userEmail = prefs.getString('userEmail');
    _isOnline = prefs.getBool('isOnline') ?? false;
    notifyListeners();

    if (_token != null) {
      await carregarPerfil();
    }
  }

  // Busca o perfil profissional completo (especialidade, tipo de veículo,
  // avaliação, e principalmente `documentacao_aprovada` - sem isso, a tela
  // do profissional não tinha como saber se ele já pode ficar online ou
  // ainda está com a documentação em análise).
  Future<void> carregarPerfil() async {
    _loadingPerfil = true;
    notifyListeners();

    final result = await ApiService.get('/users/profile');

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      _userName = data['name']?.toString() ?? _userName;
      _userEmail = data['email']?.toString();
      _userPhone = data['phone']?.toString();
      _userCpf = data['cpf']?.toString();
      _fotoUrl = data['foto_url']?.toString();
      _twoFactorEnabled = data['two_factor_enabled'] == true;

      final professional = data['professional'] as Map<String, dynamic>?;
      _especialidade = professional?['especialidade']?.toString();
      _tipoVeiculoAtendido = professional?['tipo_veiculo_atendido']?.toString();
      _avaliacaoMedia = double.tryParse(professional?['avaliacao_media']?.toString() ?? '') ?? 0;
      _totalAvaliacoes = int.tryParse(professional?['total_avaliacoes']?.toString() ?? '') ?? 0;
      _documentacaoAprovada = professional?['documentacao_aprovada'] == true;
      _contaAtiva = professional?['conta_ativa'] == true;
      _valorBase = double.tryParse(professional?['valor_base']?.toString() ?? '');
      _valorKm = double.tryParse(professional?['valor_km']?.toString() ?? '');
      _isOnline = professional?['disponivel'] == true;

      final prefs = await SharedPreferences.getInstance();
      if (_userName != null) await prefs.setString('userName', _userName!);
      if (_userEmail != null) await prefs.setString('userEmail', _userEmail!);
      await prefs.setBool('isOnline', _isOnline);
    } else {
      _lastError = result['message']?.toString();
    }

    _loadingPerfil = false;
    notifyListeners();
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    _token = data['token'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    _userId = user?['id']?.toString();
    _userName = user?['name']?.toString();
    _userEmail = user?['email']?.toString();
    _twoFactorEnabled = user?['two_factor_enabled'] == true;

    await ApiService.saveTokens(token: _token, refreshToken: refreshToken);
    // Best-effort: registra o token FCM deste dispositivo para este usuário.
    // Não faz nada se o Firebase não estiver configurado (ver serviço).
    PushNotificationService.instance.registerTokenWithBackend();
    final prefs = await SharedPreferences.getInstance();
    if (_userId != null) await prefs.setString('userId', _userId!);
    if (_userName != null) await prefs.setString('userName', _userName!);
    if (_userEmail != null) await prefs.setString('userEmail', _userEmail!);

    notifyListeners();

    // Best-effort: busca especialidade/avaliação/status de documentação
    // assim que a sessão é criada.
    unawaited(carregarPerfil());
  }

  // --------------------------------------------------------------------
  // Autenticação
  // --------------------------------------------------------------------

  Future<Map<String, dynamic>> registrar({
    required String name,
    String? email,
    String? phone,
    String? cpf,
    required String password,
    required String especialidade,
    required String tipoVeiculoAtendido,
    required double valorBase,
    required double valorKm,
  }) async {
    final result = await ApiService.post('/auth/register', {
      'name': name,
      'email': email,
      'phone': phone,
      'cpf': cpf,
      'password': password,
      'role': 'profissional',
      'especialidade': especialidade,
      'tipo_veiculo_atendido': tipoVeiculoAtendido,
      'valor_base': valorBase,
      'valor_km': valorKm,
    });

    if (result['success'] == true) {
      await _persistSession(result);

      // Mantém os valores de preço no estado local
      _valorBase = valorBase;
      _valorKm = valorKm;
    } else {
      _lastError = result['message']?.toString();
    }

    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> iniciarLogin(String identifier, {bool preferSms = false}) async {
    final result = await ApiService.post('/auth/login/start', {
      'identifier': identifier,
      'role': 'profissional',
      'preferSms': preferSms,
    });
    if (result['success'] != true) _lastError = result['message']?.toString();
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> loginComSenha(String identifier, String password) async {
    final result = await ApiService.post('/auth/login/password', {
      'identifier': identifier,
      'password': password,
      'role': 'profissional',
    });

    if (result['success'] == true && result['requires2FA'] != true) {
      await _persistSession(result);
    } else if (result['success'] != true) {
      _lastError = result['message']?.toString();
    }
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> verificarCodigo(String identifier, String code) async {
    final result = await ApiService.post('/auth/verify', {
      'identifier': identifier,
      'code': code,
      'role': 'profissional',
    });

    if (result['success'] == true && result['requires2FA'] != true) {
      await _persistSession(result);
    } else if (result['success'] != true) {
      _lastError = result['message']?.toString();
    }
    notifyListeners();
    return result;
  }

  // Completa o login quando a conta tem 2FA ativado (ver ClienteProvider
  // para a explicação completa do fluxo - é idêntico para profissionais).
  Future<Map<String, dynamic>> verificarDoisFatores(String pendingToken, String code) async {
    final result = await ApiService.post('/auth/2fa/verify-login', {
      'pendingToken': pendingToken,
      'code': code,
    });

    if (result['success'] == true) {
      await _persistSession(result);
    } else {
      _lastError = result['message']?.toString();
    }
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> iniciarConfiguracao2FA() async {
    return ApiService.post('/auth/2fa/setup', {});
  }

  Future<Map<String, dynamic>> ativar2FA(String code) async {
    final result = await ApiService.post('/auth/2fa/enable', {'code': code});
    if (result['success'] == true) {
      _twoFactorEnabled = true;
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> desativar2FA(String code) async {
    final result = await ApiService.post('/auth/2fa/disable', {'code': code});
    if (result['success'] == true) {
      _twoFactorEnabled = false;
      notifyListeners();
    }
    return result;
  }

  // Atualiza o preço que o profissional cobra (taxa base + valor por km),
  // usado pela tela de edição de preços depois do cadastro.
  Future<Map<String, dynamic>> atualizarPrecos({
    required double valorBase,
    required double valorKm,
  }) async {
    final result = await ApiService.put('/professionals/profile', {
      'valor_base': valorBase,
      'valor_km': valorKm,
    });
    if (result['success'] == true) {
      _valorBase = valorBase;
      _valorKm = valorKm;
      notifyListeners();
    }
    return result;
  }

  Future<void> reenviarCodigo(String identifier) async {
    await ApiService.post('/auth/resend-code', {'identifier': identifier});
  }

  // --------------------------------------------------------------------
  // Disponibilidade / corridas
  // --------------------------------------------------------------------

  // Atualizar status online (chama o backend e persiste localmente)
  Future<void> setOnline(bool online) async {
    _isOnline = online;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnline', online);

    await ApiService.put('/professionals/availability', {'disponivel': online});
  }

  void setActiveRide(bool active) {
    _hasActiveRide = active;
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    final refreshToken = await ApiService.refreshToken;
    await ApiService.post('/auth/logout', {if (refreshToken != null) 'refreshToken': refreshToken});

    await PushNotificationService.instance.unregisterToken();
    await ApiService.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userPhone = null;
    _userCpf = null;
    _fotoUrl = null;
    _especialidade = null;
    _tipoVeiculoAtendido = null;
    _avaliacaoMedia = 0;
    _totalAvaliacoes = 0;
    _documentacaoAprovada = false;
    _contaAtiva = false;
    _valorBase = null;
    _valorKm = null;
    _isOnline = false;
    _hasActiveRide = false;

    notifyListeners();
  }
}
