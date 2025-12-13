import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfissionalProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  bool _isOnline = false;
  bool _hasActiveRide = false;

  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isOnline => _isOnline;
  bool get hasActiveRide => _hasActiveRide;

  bool get isAuthenticated => _token != null;

  // Carregar dados do usuário
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    _userName = prefs.getString('userName');
    _userEmail = prefs.getString('userEmail');
    _isOnline = prefs.getBool('isOnline') ?? false;
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

  // Atualizar status online
  Future<void> setOnline(bool online) async {
    _isOnline = online;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnline', online);
    notifyListeners();
  }

  // Atualizar status de corrida
  void setActiveRide(bool active) {
    _hasActiveRide = active;
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
    _isOnline = false;
    _hasActiveRide = false;
    
    notifyListeners();
  }
}