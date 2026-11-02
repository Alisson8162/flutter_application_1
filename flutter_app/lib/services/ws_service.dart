import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'api_service.dart';

typedef OnLocation = void Function(String id, LatLng pos, Map<String, dynamic> meta);
typedef OnRideStatus = void Function(String status, Map<String, dynamic> payload);
typedef OnChatMessage = void Function(Map<String, dynamic> message);

/// Conecta ao endpoint de tempo real de uma corrida:
/// ws(s)://<host>/ws/trip/<rideId>?token=<jwt>
///
/// CORRIGIDO: apontava para um placeholder fixo "YOUR_BACKEND_DOMAIN" que
/// nunca funcionaria. Agora usa o mesmo host configurado em [ApiService],
/// então basta configurar o backend em um lugar só.
class WsService {
  WebSocketChannel? _channel;

  Future<void> connectToTrip(
    String tripId, {
    OnLocation? onLocation,
    OnRideStatus? onStatus,
    OnChatMessage? onMessage,
  }) async {
    disconnect();

    final token = await ApiService.token;
    final url = Uri.parse(
      '${ApiService.wsBaseUrl}$tripId${token != null ? '?token=$token' : ''}',
    );

    _channel = WebSocketChannel.connect(url);
    _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;

          if (data['type'] == 'location' && onLocation != null) {
            final id = data['id'] as String;
            final lat = (data['lat'] as num).toDouble();
            final lng = (data['lng'] as num).toDouble();
            onLocation(id, LatLng(lat, lng), data);
          } else if (data['type'] == 'status' && onStatus != null) {
            onStatus(data['status'] as String, data);
          } else if (data['type'] == 'message' && onMessage != null) {
            onMessage(data);
          }
        } catch (_) {
          // mensagem malformada, ignorar
        }
      },
      onError: (_) {
        // a tela pode chamar connectToTrip novamente para tentar reconectar
      },
      onDone: () {},
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }
}
