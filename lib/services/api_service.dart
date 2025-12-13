import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const bool isDevelopment = true; // Mude para false em produção
  
  // Para Android Emulator
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  
  // Para iOS Simulator: 'http://localhost:5000/api'
  // Para dispositivo físico: 'http://<SEU_IP>:5000/api'

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    if (isDevelopment) {
      print('🟡 MODO DESENV: Simulando GET para $endpoint');
      await Future.delayed(const Duration(milliseconds: 500));
      return http.Response('{"success": true, "data": []}', 200);
    }
    
    final headers = await _getHeaders();
    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
  }

  static Future<http.Response> post(String endpoint, dynamic data) async {
    if (isDevelopment) {
      print('🟡 MODO DESENV: Simulando POST para $endpoint');
      await Future.delayed(const Duration(milliseconds: 800));
      return http.Response('{"success": true, "message": "Operação simulada"}', 200);
    }
    
    final headers = await _getHeaders();
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
  }

  static Future<http.Response> put(String endpoint, dynamic data) async {
    if (isDevelopment) {
      print('🟡 MODO DESENV: Simulando PUT para $endpoint');
      await Future.delayed(const Duration(milliseconds: 800));
      return http.Response('{"success": true, "message": "Operação simulada"}', 200);
    }
    
    final headers = await _getHeaders();
    return await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
  }

  static Future<http.Response> delete(String endpoint) async {
    if (isDevelopment) {
      print('🟡 MODO DESENV: Simulando DELETE para $endpoint');
      await Future.delayed(const Duration(milliseconds: 500));
      return http.Response('{"success": true}', 200);
    }
    
    final headers = await _getHeaders();
    return await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
  }
}