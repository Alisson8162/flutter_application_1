import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

typedef OnLocation = void Function(String id, LatLng pos, Map<String, dynamic> meta);

class WsService {
  // configurável
  final String wsBaseUrl = "wss://YOUR_BACKEND_DOMAIN/ws/trip/";
  WebSocketChannel? _channel;

  void connectToTrip(String tripId, OnLocation onLocation) {
    disconnect();
    final url = "$wsBaseUrl$tripId";
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen((message) {
      try {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        // exemplo esperado: { "type": "location", "id": "pro123", "lat": -23.5, "lng": -46.6, "eta": 300 }
        if (data['type'] == 'location') {
          final id = data['id'] as String;
          final lat = (data['lat'] as num).toDouble();
          final lng = (data['lng'] as num).toDouble();
          onLocation(id, LatLng(lat, lng), data);
        }
      } catch (e) {
        // ignorar / log
      }
    }, onError: (err) {
      // reconectar ou notificar
    }, onDone: () {
      // finalizado pelo servidor
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void send(Map<String, dynamic> payload) {
    if (_channel != null) _channel!.sink.add(jsonEncode(payload));
  }
}
