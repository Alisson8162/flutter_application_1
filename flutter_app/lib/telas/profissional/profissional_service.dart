import '../../services/api_service.dart';

/// Serviço com as chamadas de API específicas do fluxo do profissional.
///
/// CORRIGIDO: importava um arquivo `services/service.dart` que não existe
/// mais (era o `ApiService` duplicado). Agora usa a única implementação em
/// `lib/services/api_service.dart`, cujos métodos retornam diretamente um
/// `Map<String, dynamic>` já decodificado do JSON de resposta.
class ProfissionalService {
  // Atualizar localização do profissional
  static Future<bool> updateLocation(double latitude, double longitude) async {
    final result = await ApiService.post('/location/update', {
      'latitude': latitude,
      'longitude': longitude,
    });
    return result['success'] == true;
  }

  // Buscar corridas pendentes
  static Future<List<dynamic>> getPendingRides() async {
    final result = await ApiService.get('/rides/pending');
    if (result['success'] == true) {
      return (result['data'] as List<dynamic>?) ?? [];
    }
    return [];
  }

  // Aceitar corrida
  static Future<bool> acceptRide(String rideId) async {
    final result = await ApiService.post('/rides/$rideId/accept', {});
    return result['success'] == true;
  }

  // Iniciar corrida (profissional chegou / atendimento em andamento)
  static Future<bool> startRide(String rideId) async {
    final result = await ApiService.post('/rides/$rideId/start', {});
    return result['success'] == true;
  }

  // Finalizar corrida
  static Future<bool> completeRide(String rideId, {double? finalPrice}) async {
    final result = await ApiService.post('/rides/$rideId/complete', {
      if (finalPrice != null) 'final_price': finalPrice,
    });
    return result['success'] == true;
  }

  // Cancelar corrida
  static Future<bool> cancelRide(String rideId) async {
    final result = await ApiService.post('/rides/$rideId/cancel', {});
    return result['success'] == true;
  }

  // Atualizar disponibilidade
  // Retorna o resultado completo (não só um bool) porque o backend agora
  // pode recusar com um motivo específico - documentação pendente ou
  // assinatura/mensalidade inativa (campo `code` na resposta) - e a tela
  // precisa mostrar a mensagem certa, não só "deu erro".
  static Future<Map<String, dynamic>> updateAvailability(bool disponivel) async {
    return ApiService.put('/professionals/availability', {
      'disponivel': disponivel,
    });
  }

  // Buscar ganhos
  static Future<Map<String, dynamic>> getEarnings() async {
    final result = await ApiService.get('/professionals/earnings');
    if (result['success'] == true) {
      return (result['data'] as Map<String, dynamic>?) ?? {};
    }
    return {};
  }

  // Histórico de corridas do profissional
  static Future<List<dynamic>> getRideHistory({int page = 1, int limit = 10}) async {
    final result = await ApiService.get('/rides/professional/history?page=$page&limit=$limit');
    if (result['success'] == true) {
      return (result['data'] as List<dynamic>?) ?? [];
    }
    return [];
  }

  // Status da documentação
  static Future<Map<String, dynamic>> getDocumentStatus() async {
    final result = await ApiService.get('/professionals/documents/status');
    if (result['success'] == true) {
      return (result['data'] as Map<String, dynamic>?) ?? {};
    }
    return {};
  }
}
