import 'dart:convert';
import '../../services/service.dart';

class ProfissionalService {
  // Atualizar localização do profissional
  static Future<bool> updateLocation(double latitude, double longitude) async {
    try {
      final response = await ApiService.post('/location/update', {
        'latitude': latitude,
        'longitude': longitude,
      });
      
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar localização: $e');
      return false;
    }
  }

  // Buscar corridas pendentes
  static Future<List<dynamic>> getPendingRides() async {
    try {
      final response = await ApiService.get('/rides/pending');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Erro ao buscar corridas: $e');
      return [];
    }
  }

  // Aceitar corrida
  static Future<bool> acceptRide(String rideId) async {
    try {
      final response = await ApiService.post('/rides/$rideId/accept', {});
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao aceitar corrida: $e');
      return false;
    }
  }

  // Finalizar corrida
  static Future<bool> completeRide(String rideId) async {
    try {
      final response = await ApiService.post('/rides/$rideId/complete', {});
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao finalizar corrida: $e');
      return false;
    }
  }

  // Atualizar disponibilidade
  static Future<bool> updateAvailability(bool disponivel) async {
    try {
      final response = await ApiService.put('/professionals/availability', {
        'disponivel': disponivel,
      });
      
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar disponibilidade: $e');
      return false;
    }
  }

  // Buscar ganhos
  static Future<Map<String, dynamic>> getEarnings() async {
    try {
      final response = await ApiService.get('/professionals/earnings');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print('Erro ao buscar ganhos: $e');
      return {};
    }
  }
}