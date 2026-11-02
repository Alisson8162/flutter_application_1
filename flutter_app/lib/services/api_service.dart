import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço único de acesso à API.
///
/// CORRIGIDO: o projeto original tinha DUAS classes `ApiService` diferentes
/// (lib/services/api_service.dart, que sempre respondia com dados falsos
/// simulados em `Future.delayed`, e services/service.dart, com a
/// implementação real, apontando pra um IP fixo de rede local). Nenhuma tela
/// usava a versão real de fato. Agora existe apenas esta classe, que fala de
/// verdade com o backend Node/Express.
///
/// Configuração do endereço do backend:
/// - Web / Desktop / iOS simulator -> http://localhost:5000
/// - Emulador Android -> http://10.0.2.2:5000 (loopback especial do emulador)
/// - Dispositivo físico -> IP da máquina que roda o backend na mesma rede
///
/// Ajuste `_host` abaixo (ou passe via --dart-define=API_HOST=...) antes de
/// rodar em um dispositivo físico.
class ApiService {
  static const String _defaultHost = kIsWeb ? 'localhost' : '10.0.2.2';

  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: _defaultHost,
  );

  static const String port = String.fromEnvironment('API_PORT', defaultValue: '5000');

  static String get baseUrl => 'http://$host:$port/api';

  static String get wsBaseUrl => 'ws://$host:$port/ws/trip/';

  static Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> get userId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  static Future<String?> get refreshToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  static Future<void> saveTokens({required String? token, String? refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) await prefs.setString('token', token);
    if (refreshToken != null) await prefs.setString('refreshToken', refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
  }

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final t = await token;
    return {
      if (json) 'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  // Tenta trocar o refresh token salvo por um novo par de tokens. Chamado
  // automaticamente quando uma requisição autenticada volta 401 (access
  // token expirado) - ver `_withAutoRefresh` abaixo. Retorna true se
  // conseguiu renovar (e já salvou os novos tokens), false caso contrário
  // (refresh token ausente/expirado - o chamador deve tratar como sessão
  // encerrada).
  static Future<bool> _tryRefreshToken() async {
    final rt = await refreshToken;
    if (rt == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refreshToken': rt}),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = _decode(response);
      if (decoded['success'] == true && decoded['token'] != null) {
        await saveTokens(
          token: decoded['token'] as String?,
          refreshToken: decoded['refreshToken'] as String?,
        );
        return true;
      }
    } catch (_) {
      // sem conexão / erro inesperado - trata como refresh malsucedido
    }
    return false;
  }

  // Envolve uma chamada HTTP: se a resposta vier 401 (token expirado) e
  // houver um refresh token salvo, tenta renovar silenciosamente e repete a
  // chamada UMA vez com o novo token. Se o refresh falhar, devolve o 401
  // original - quem chamou trata como já tratava (result['success'] ==
  // false), sem quebrar nenhum fluxo existente.
  static Future<http.Response> _withAutoRefresh(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();
    if (response.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        response = await request();
      }
    }
    return response;
  }

  /// Decodifica a resposta HTTP em um Map, sempre no formato
  /// `{ success: bool, message/data/error: ... }` usado pelo backend.
  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': response.statusCode < 400, 'data': decoded};
    } catch (_) {
      return {
        'success': false,
        'message': 'Resposta inválida do servidor (status ${response.statusCode})',
      };
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await _withAutoRefresh(
        () async => http
            .get(
              Uri.parse('$baseUrl$endpoint'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 15)),
      );

      return _decode(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Falha de conexão: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    dynamic data,
  ) async {
    try {
      final response = await _withAutoRefresh(
        () async => http
            .post(
              Uri.parse('$baseUrl$endpoint'),
              headers: await _headers(),
              body: json.encode(data),
            )
            .timeout(const Duration(seconds: 15)),
      );

      return _decode(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Falha de conexão: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    dynamic data,
  ) async {
    try {
      final response = await _withAutoRefresh(
        () async => http
            .put(
              Uri.parse('$baseUrl$endpoint'),
              headers: await _headers(),
              body: json.encode(data),
            )
            .timeout(const Duration(seconds: 15)),
      );

      return _decode(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Falha de conexão: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _withAutoRefresh(
        () async => http
            .delete(
              Uri.parse('$baseUrl$endpoint'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 15)),
      );

      return _decode(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Falha de conexão: $e',
      };
    }
  }
  /// Upload de arquivos (multipart/form-data) - usado para fotos/documentos
  /// (POST /users/documents, POST /professionals/documents no backend).
  /// `files`: nome do campo (ex: 'foto_usuario') -> bytes da imagem.
  static Future<Map<String, dynamic>> uploadFiles(
    String endpoint,
    Map<String, Uint8List> files,
  ) async {
    try {
      Future<http.StreamedResponse> send() async {
        final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
        final t = await token;
        if (t != null) request.headers['Authorization'] = 'Bearer $t';

        for (final entry in files.entries) {
          request.files.add(
            http.MultipartFile.fromBytes(entry.key, entry.value, filename: '${entry.key}.jpg'),
          );
        }
        return request.send().timeout(const Duration(seconds: 30));
      }

      var streamed = await send();
      if (streamed.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) streamed = await send();
      }

      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } catch (e) {
      return {'success': false, 'message': 'Falha de conexão: $e'};
    }
  }
}
