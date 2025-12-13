import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../lib/services/ws_service.dart'; // CORRIGIDO
import '../telas/map_service.dart'; //
import 'package:provider/provider.dart';

class RideFlowScreen extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final String professionalType;
  final String professionalName;
  final String vehicleType;
  final double estimatedPrice;
  final String estimatedTime;

  const RideFlowScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.professionalType,
    required this.professionalName,
    required this.vehicleType,
    required this.estimatedPrice,
    required this.estimatedTime,
  });

  @override
  State<RideFlowScreen> createState() => _RideFlowScreenState();
}

class _RideFlowScreenState extends State<RideFlowScreen> {
  String tripId = 'trip_123456'; // mock
  bool searching = true;
  bool found = false;
  String proId = 'pro_1';
  LatLng proPosition = LatLng(0,0);
  late WsService ws;
  late MapService mapSvc;
  

  @override
  void initState() {
    super.initState();
    ws = context.read<WsService>();
    mapSvc = context.read<MapService>();
    // Simulação: connect and wait
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => searching = false);
      setState(() => found = true);
      proPosition = LatLng(widget.origin.latitude + 0.02, widget.origin.longitude + 0.01);
      mapSvc.addOrUpdateProfessional(proId, proPosition, title: 'Mecânico - Carlos');
      // conectar no websocket real do backend (simulado)
      ws.connectToTrip(tripId, (id, pos, meta) {
        // atualiza marker
        mapSvc.addOrUpdateProfessional(id, pos, title: meta['name'] ?? 'Profissional');
        // podemos desenhar rota do profissional até origem
        mapSvc.drawRoute(pos, widget.origin, 'AIzaSyB7WqfU91rDHwnY2x1zFk1tAd7QiJHpUlY');
      });
    });
  }

  @override
  void dispose() {
    ws.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapSvc = context.watch<MapService>();

    return Scaffold(
      appBar: AppBar(title: Text(found ? "Profissional a caminho" : (searching ? "Procurando..." : "Confirmar")), backgroundColor: Colors.transparent),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: widget.origin, zoom: 13),
          markers: Set<Marker>.of(mapSvc.professionals.values)..add(Marker(markerId: const MarkerId('you'), position: widget.origin, infoWindow: const InfoWindow(title: 'Você'))),
          polylines: Set<Polyline>.of(mapSvc.polylines.values),
        ),
        Positioned(bottom: 12, left: 12, right: 12, child: _bottomCard()),
      ]),
    );
  }

  Widget _bottomCard() {
    if (searching) {
      return Card(
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: const [
            CircularProgressIndicator(),
            SizedBox(width: 12),
            Expanded(child: Text("Procurando profissional mais próximo...", style: TextStyle(color: Colors.white))),
          ]),
        ),
      );
    }
    if (found) {
      return Card(
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(child: Text("C")),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text("Carlos - Mecânico", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("Chegando em ~8 min • Avaliação 4.8", style: TextStyle(color: Colors.white70)),
              ]),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text("Contatar")),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton(onPressed: () {}, child: const Text("Compartilhar trajeto")),
              const SizedBox(width: 8),
              TextButton(onPressed: () { /* cancelar com taxa */ }, child: const Text("Cancelar")),
            ])
          ]),
        ),
      );
    }
    // fallback confirm
    return Card(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Confirmar pedido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: () {
              // enviar requisição para backend criar trip
            }, child: const Text("Solicitar Profissional"))),
          ])
        ]),
      ),
    );
  }
}
