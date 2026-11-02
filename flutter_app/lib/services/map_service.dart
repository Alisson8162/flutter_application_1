// VERSÃO CORRIGIDA PARA flutter_polyline_points 3.1.0+
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapService extends ChangeNotifier {
  LatLng? userLocation;
  final Map<String, Marker> professionals = {};
  final Map<PolylineId, Polyline> polylines = {};

  Future<void> initUserLocation() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    userLocation = LatLng(pos.latitude, pos.longitude);
    notifyListeners();
  }

  void addOrUpdateProfessional(String id, LatLng pos, {String? title}) {
    final marker = Marker(
      markerId: MarkerId(id),
      position: pos,
      infoWindow: InfoWindow(title: title ?? "Profissional"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );
    professionals[id] = marker;
    notifyListeners();
  }

  void removeProfessional(String id) {
    professionals.remove(id);
    notifyListeners();
  }

  /// 🚗 Desenha rota entre dois pontos usando o novo PolylinePoints API
  Future<void> drawRoute(LatLng origin, LatLng destination, String apiKey) async {
    try {
      final poly = PolylinePoints(apiKey: apiKey);

      // ✅ Novo formato: usar PolylineRequest
      final request = PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      );

      final result = await poly.getRouteBetweenCoordinates(request: request);

      if (result.points.isEmpty) {
        print("⚠️ Nenhum ponto retornado. Erro: ${result.errorMessage}");
        _drawSimpleRoute(origin, destination);
        return;
      }

      final id = PolylineId('route_${DateTime.now().millisecondsSinceEpoch}');
      final points = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

      final polyline = Polyline(
        polylineId: id,
        points: points,
        color: Colors.green,
        width: 5,
      );

      polylines.clear();
      polylines[id] = polyline;
      notifyListeners();
    } catch (e) {
      print("❌ Erro ao desenhar rota: $e");
      _drawSimpleRoute(origin, destination);
    }
  }

  void _drawSimpleRoute(LatLng origin, LatLng destination) {
    final id = PolylineId('simple_route_${DateTime.now().millisecondsSinceEpoch}');
    final points = [origin, destination];
    final polyline = Polyline(
      polylineId: id,
      points: points,
      color: Colors.blue,
      width: 3,
    );
    polylines.clear();
    polylines[id] = polyline;
    notifyListeners();
  }
}
