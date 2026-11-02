import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';

/// Estado do cliente logado + chamadas de API do fluxo de cliente.
///
/// CORRIGIDO: todas as ações (login, buscar profissionais próximos, e
/// principalmente `solicitarServico`) eram 100% simuladas com
/// `Future.delayed`, sem nenhuma chamada real ao backend - a linha que
/// chamaria a API de verdade estava comentada. Agora todas essas ações
/// conversam com a API Node/Express.
class ClienteProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userCpf;
  String? _fotoUrl;
  String? _tipoVeiculoPreferido;
  String? _enderecoCompleto;
  String? _enderecoCidade;
  String? _enderecoEstado;
  bool _twoFactorEnabled = false;
  String? _currentAddress;
  String? _destinationAddress;
  List<dynamic> _nearbyProfessionals = [];
  bool _isLoading = false;
  bool _loadingPerfil = false;
  String? _lastError;

  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  String? get userCpf => _userCpf;
  String? get fotoUrl => _fotoUrl;
  String? get tipoVeiculoPreferido => _tipoVeiculoPreferido;
  String? get enderecoCompleto => _enderecoCompleto;
  String? get enderecoCidade => _enderecoCidade;
  String? get enderecoEstado => _enderecoEstado;
  bool get twoFactorEnabled => _twoFactorEnabled;
  String? get currentAddress => _currentAddress;
  String? get destinationAddress => _destinationAddress;
  List<dynamic> get nearbyProfessionals => _nearbyProfessionals;
  bool get isLoading => _isLoading;
  bool get loadingPerfil => _loadingPerfil;
  String? get lastError => _lastError;

  bool get isAuthenticated => _token != null;

  // Carregar dados do usuário salvos localmente (sessão persistida) e, em
  // seguida, buscar o perfil completo e atualizado do backend.
  //
  // CORRIGIDO: antes só se lia do SharedPreferences (token/nome/email
  // salvos no instante do login) e nunca mais nada era buscado depois -
  // telefone, CPF, foto e veículo preferido do cliente nunca chegavam a
  // nenhuma tela, porque nunca eram sequer buscados do backend.
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _userName = prefs.getString('userName');
    _userEmail = prefs.getString('userEmail');
    notifyListeners();

    if (_token != null) {
      await carregarPerfil();
    }
  }

  // Busca o perfil completo e atualizado em GET /api/users/profile e
  // atualiza todos os campos locais. Chame sempre que uma tela precisar
  // garantir que está mostrando os dados mais recentes (ex.: pull-to-refresh
  // na aba de perfil, ou logo após editar o cadastro).
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

      final client = data['client'] as Map<String, dynamic>?;
      _tipoVeiculoPreferido = client?['tipo_veiculo_preferido']?.toString();

      final prefs = await SharedPreferences.getInstance();
      if (_userName != null) await prefs.setString('userName', _userName!);
      if (_userEmail != null) await prefs.setString('userEmail', _userEmail!);
    } else {
      _lastError = result['message']?.toString();
    }

    // Endereço fica em uma tabela separada (GET /api/users/address) -
    // buscado junto para que a aba de Perfil já mostre o endereço real em
    // vez do texto fixo "Rua Exemplo, 123" que existia antes.
    final addressResult = await ApiService.get('/users/address');
    if (addressResult['success'] == true && addressResult['data'] != null) {
      final address = addressResult['data'] as Map<String, dynamic>;
      _enderecoCompleto = address['endereco_completo']?.toString();
      _enderecoCidade = address['cidade']?.toString();
      _enderecoEstado = address['estado']?.toString();
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

    // Best-effort: busca telefone/CPF/foto/veículo preferido assim que a
    // sessão é criada, para que a aba de Perfil já abra com dados reais.
    unawaited(carregarPerfil());
  }

  // --------------------------------------------------------------------
  // Autenticação
  // --------------------------------------------------------------------

  /// Cadastro direto (nome, email/telefone, senha, cpf)
  Future<Map<String, dynamic>> registrar({
    required String name,
    String? email,
    String? phone,
    String? cpf,
    required String password,
    String? tipoVeiculoPreferido,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post('/auth/register', {
      'name': name,
      'email': email,
      'phone': phone,
      'cpf': cpf,
      'password': password,
      'role': 'cliente',
      if (tipoVeiculoPreferido != null) 'tipo_veiculo_preferido': tipoVeiculoPreferido,
    });

    if (result['success'] == true) {
      await _persistSession(result);
    } else {
      _lastError = result['message']?.toString();
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  /// Inicia o login: decide se o backend vai pedir senha ou enviar um código
  Future<Map<String, dynamic>> iniciarLogin(String identifier, {bool preferSms = false}) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post('/auth/login/start', {
      'identifier': identifier,
      'role': 'cliente',
      'preferSms': preferSms,
    });

    _isLoading = false;
    if (result['success'] != true) _lastError = result['message']?.toString();
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> loginComSenha(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post('/auth/login/password', {
      'identifier': identifier,
      'password': password,
      'role': 'cliente',
    });

    if (result['success'] == true && result['requires2FA'] != true) {
      await _persistSession(result);
    } else if (result['success'] != true) {
      _lastError = result['message']?.toString();
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> verificarCodigo(String identifier, String code) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post('/auth/verify', {
      'identifier': identifier,
      'code': code,
      'role': 'cliente',
    });

    if (result['success'] == true && result['requires2FA'] != true) {
      await _persistSession(result);
    } else if (result['success'] != true) {
      _lastError = result['message']?.toString();
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  // Completa o login quando a conta tem 2FA ativado: recebe o pendingToken
  // retornado por loginComSenha/verificarCodigo (quando result['requires2FA']
  // == true) junto com o código de 6 dígitos do app autenticador.
  Future<Map<String, dynamic>> verificarDoisFatores(String pendingToken, String code) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post('/auth/2fa/verify-login', {
      'pendingToken': pendingToken,
      'code': code,
    });

    if (result['success'] == true) {
      await _persistSession(result);
    } else {
      _lastError = result['message']?.toString();
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  // --------------------------------------------------------------------
  // Autenticação em duas etapas (2FA) - configuração pela própria conta já
  // logada (tela de configurações/segurança).
  // --------------------------------------------------------------------

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

  Future<void> reenviarCodigo(String identifier) async {
    await ApiService.post('/auth/resend-code', {'identifier': identifier});
  }

  // Definir endereços (uso local na tela de mapa, antes de solicitar o serviço)
  void setCurrentAddress(String address) {
    _currentAddress = address;
    notifyListeners();
  }

  void setDestinationAddress(String address) {
    _destinationAddress = address;
    notifyListeners();
  }

  // --------------------------------------------------------------------
  // Profissionais / corridas
  // --------------------------------------------------------------------

  // Buscar profissionais próximos (GET /api/location/nearby)
  Future<void> buscarProfissionaisProximos(
    LatLng localizacaoCliente,
    String tipoServico,
    String tipoVeiculo,
  ) async {
    _isLoading = true;
    notifyListeners();

    final query =
        '/location/nearby?latitude=${localizacaoCliente.latitude}&longitude=${localizacaoCliente.longitude}&radius=15&especialidade=$tipoServico';
    final result = await ApiService.get(query);

    if (result['success'] == true) {
      _nearbyProfessionals = (result['data'] as List<dynamic>?) ?? [];
    } else {
      _lastError = result['message']?.toString();
      _nearbyProfessionals = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Solicitar serviço (POST /api/rides)
  Future<Map<String, dynamic>> solicitarServico({
    required LatLng localizacaoCliente,
    required String tipoServico,
    required String tipoVeiculo,
    required String descricaoProblema,
    required String nomeCliente,
    required String telefoneCliente,
    required double distanciaKm,
    required double precoEstimado,
    LatLng? destino,
    String? cupomCodigo,
  }) async {
    _isLoading = true;
    notifyListeners();

    final pickup = {
      'latitude': localizacaoCliente.latitude,
      'longitude': localizacaoCliente.longitude,
      'descricao': descricaoProblema,
      'tipo_servico': tipoServico,
      'tipo_veiculo': tipoVeiculo,
      'nome_cliente': nomeCliente,
      'telefone_cliente': telefoneCliente,
    };

    final destination = destino != null
        ? {'latitude': destino.latitude, 'longitude': destino.longitude}
        : {'latitude': localizacaoCliente.latitude, 'longitude': localizacaoCliente.longitude};

    final result = await ApiService.post('/rides', {
      'pickup_location': pickup,
      'destination': destination,
      'distance': distanciaKm,
      'estimated_price': precoEstimado,
      if (cupomCodigo != null && cupomCodigo.isNotEmpty) 'coupon_code': cupomCodigo,
    });

    _isLoading = false;
    if (result['success'] != true) _lastError = result['message']?.toString();
    notifyListeners();

    return result;
  }

  // Valida um cupom antes de confirmar a corrida (não consome o cupom
  // ainda - só a criação da corrida em si consome, via solicitarServico).
  Future<Map<String, dynamic>> validarCupom(String code, double valorCorrida) async {
    return ApiService.post('/coupons/validate', {'code': code, 'ride_value': valorCorrida});
  }

  // Corrida ativa do cliente (útil ao reabrir o app)
  Future<Map<String, dynamic>?> buscarCorridaAtiva() async {
    final result = await ApiService.get('/rides/active');
    if (result['success'] == true) {
      return result['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  // Cancelar uma corrida (própria ou em andamento) - POST /api/rides/:id/cancel
  Future<Map<String, dynamic>> cancelarCorrida(String rideId) async {
    final result = await ApiService.post('/rides/$rideId/cancel', {});
    if (result['success'] != true) _lastError = result['message']?.toString();
    notifyListeners();
    return result;
  }

  // Limpar dados de endereço
  void clearAddresses() {
    _currentAddress = null;
    _destinationAddress = null;
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
    _tipoVeiculoPreferido = null;
    _enderecoCompleto = null;
    _enderecoCidade = null;
    _enderecoEstado = null;
    _currentAddress = null;
    _destinationAddress = null;
    _nearbyProfessionals = [];
    _isLoading = false;

    notifyListeners();
  }
}
