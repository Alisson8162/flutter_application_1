import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/ws_service.dart';
import '../services/map_service.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import 'package:provider/provider.dart';

class RideFlowScreen extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final String professionalType;
  final String professionalName;
  final String vehicleType;
  final double estimatedPrice;
  final String estimatedTime;
  // ID real da corrida criada via POST /api/rides (ClienteProvider.solicitarServico).
  // Quando presente, a tela conecta no WebSocket real do backend e busca o
  // status/motorista de verdade. Quando ausente, mantém o comportamento de
  // demonstração anterior (sem corrida real por trás).
  final String? rideId;

  const RideFlowScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.professionalType,
    required this.professionalName,
    required this.vehicleType,
    required this.estimatedPrice,
    required this.estimatedTime,
    this.rideId,
  });

  @override
  State<RideFlowScreen> createState() => _RideFlowScreenState();
}

class _RideFlowScreenState extends State<RideFlowScreen> {
  bool searching = true;
  bool found = false;
  String proId = 'pro_1';
  String? driverName;
  String? driverPhone;
  LatLng proPosition = LatLng(0,0);
  late WsService ws;
  late MapService mapSvc;
  

  @override
  void initState() {
    super.initState();
    ws = context.read<WsService>();
    mapSvc = context.read<MapService>();

    if (widget.rideId != null) {
      _connectToRealRide(widget.rideId!);
    } else {
      // Sem rideId real (ex.: tela aberta em modo de demonstração/preview) -
      // mantém a simulação original para não quebrar a navegação existente.
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          searching = false;
          found = true;
        });
        proPosition = LatLng(widget.origin.latitude + 0.02, widget.origin.longitude + 0.01);
        mapSvc.addOrUpdateProfessional(proId, proPosition, title: 'Mecânico - Carlos');
      });
    }
  }

  Future<void> _connectToRealRide(String rideId) async {
    // Busca o estado atual da corrida (pode já estar aceita)
    final result = await ApiService.get('/rides/$rideId');
    if (result['success'] == true && result['data'] != null) {
      final ride = result['data'] as Map<String, dynamic>;
      if (mounted && ride['status'] != 'pending') {
        setState(() {
          searching = false;
          found = true;
        });
      }
    }

    await ws.connectToTrip(
      rideId,
      onLocation: (id, pos, meta) {
        if (!mounted) return;
        proPosition = pos;
        mapSvc.addOrUpdateProfessional(id, pos, title: meta['name'] ?? 'Profissional');
        mapSvc.drawRoute(pos, widget.origin, AppConfig.googleMapsApiKey);
      },
      onStatus: (status, payload) {
        if (!mounted) return;
        if (status == 'accepted') {
          final driver = payload['driver'] as Map<String, dynamic>?;
          setState(() {
            searching = false;
            found = true;
            driverName = driver?['name'];
            driverPhone = driver?['phone'];
          });
        } else if (status == 'completed' || status == 'cancelled') {
          setState(() {
            found = false;
            searching = false;
          });
        }
      },
    );
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
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(driverName ?? "Profissional a caminho", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const Text("Chegando em breve", style: TextStyle(color: Colors.white70)),
              ]),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text("Contatar")),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton(onPressed: () {}, child: const Text("Compartilhar trajeto")),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  if (widget.rideId != null) {
                    await ApiService.post('/rides/${widget.rideId}/cancel', {});
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Cancelar"),
              ),
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
