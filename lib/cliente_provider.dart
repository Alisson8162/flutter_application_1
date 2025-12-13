import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

class ClienteProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _currentAddress;
  String? _destinationAddress;
  List<dynamic> _nearbyProfessionals = [];
  bool _isLoading = false;

  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get currentAddress => _currentAddress;
  String? get destinationAddress => _destinationAddress;
  List<dynamic> get nearbyProfessionals => _nearbyProfessionals;
  bool get isLoading => _isLoading;

  bool get isAuthenticated => _token != null;

  // Carregar dados do usuário
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _userName = prefs.getString('userName');
    _userEmail = prefs.getString('userEmail');
    notifyListeners();
  }

  // Salvar dados do login
  Future<void> saveLoginData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    
    _token = data['token'];
    _userId = data['user']['id'];
    _userName = data['user']['name'];
    _userEmail = data['user']['email'];
    
    await prefs.setString('token', _token!);
    await prefs.setString('userId', _userId!);
    await prefs.setString('userName', _userName!);
    await prefs.setString('userEmail', _userEmail!);
    
    notifyListeners();
  }

  // Definir endereços
  void setCurrentAddress(String address) {
    _currentAddress = address;
    notifyListeners();
  }

  void setDestinationAddress(String address) {
    _destinationAddress = address;
    notifyListeners();
  }

  // Buscar profissionais próximos
  Future<void> buscarProfissionaisProximos(
    LatLng localizacaoCliente,
    String tipoServico,
    String tipoVeiculo,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulação de busca de profissionais
      await Future.delayed(const Duration(seconds: 2));

      // Dados simulados para teste
      _nearbyProfessionals = [
        {
          'id': '1',
          'name': 'João Mecânico',
          'averageRating': 4.8,
          'distance': 2.5,
          'price': 80.0,
          'specialty': 'Mecânico',
        },
        {
          'id': '2',
          'name': 'Maria Eletricista',
          'averageRating': 4.9,
          'distance': 3.0,
          'price': 70.0,
          'specialty': 'Eletricista',
        },
        {
          'id': '3',
          'name': 'Carlos Borracheiro',
          'averageRating': 4.7,
          'distance': 1.8,
          'price': 50.0,
          'specialty': 'Borracheiro',
        },
        {
          'id': '4',
          'name': 'Ana Guincho',
          'averageRating': 4.6,
          'distance': 4.2,
          'price': 120.0,
          'specialty': 'Guincho',
        },
      ];

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Erro ao buscar profissionais: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Solicitar serviço
  Future<Map<String, dynamic>> solicitarServico({
    required LatLng localizacaoCliente,
    required String tipoServico,
    required String tipoVeiculo,
    required String descricaoProblema,
    required String nomeCliente,
    required String telefoneCliente,
    LatLng? destino,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulação de solicitação de serviço
      await Future.delayed(const Duration(seconds: 3));

      // Criar dados da solicitação
      final solicitationData = {
        'client_id': _userId,
        'client_name': nomeCliente,
        'client_phone': telefoneCliente,
        'service_type': tipoServico,
        'vehicle_type': tipoVeiculo,
        'description': descricaoProblema,
        'pickup_location': {
          'latitude': localizacaoCliente.latitude,
          'longitude': localizacaoCliente.longitude,
        },
        'destination': destino != null ? {
          'latitude': destino.latitude,
          'longitude': destino.longitude,
        } : null,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Em produção, enviaria para o backend:
      // final response = await ApiService.post('/rides', solicitationData);

      _isLoading = false;
      notifyListeners();

      return {
        'success': true,
        'message': 'Serviço solicitado com sucesso! Aguarde a confirmação de um profissional.',
        'data': solicitationData,
      };
    } catch (e) {
      print('Erro ao solicitar serviço: $e');
      _isLoading = false;
      notifyListeners();

      return {
        'success': false,
        'error': 'Erro ao solicitar serviço. Tente novamente.',
      };
    }
  }

  // Limpar dados
  void clearAddresses() {
    _currentAddress = null;
    _destinationAddress = null;
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _currentAddress = null;
    _destinationAddress = null;
    _nearbyProfessionals = [];
    _isLoading = false;
    
    notifyListeners();
  }
}