import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:provider/provider.dart';
import '../profissional/profissional_service.dart';
import '../profissional/profissional_provider.dart';
import 'configuracoes_page.dart';

class ProfissionalHome extends StatefulWidget {
  const ProfissionalHome({super.key});

  @override
  State<ProfissionalHome> createState() => _ProfissionalHomeState();
}

class LatLngTween extends Tween<LatLng> {
  LatLngTween({LatLng? begin, LatLng? end}) : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) => LatLng(
    begin!.latitude + (end!.latitude - begin!.latitude) * t,
    begin!.longitude + (end!.longitude - begin!.longitude) * t,
  );
}

class _ProfissionalHomeState extends State<ProfissionalHome>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  bool isLoadingMap = true;
  bool hasRideRequest = false;

  Position? _currentPosition;
  static const LatLng _initialPos = LatLng(-23.55052, -46.633308);
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  Set<Circle> heatMapCircles = {};

  // Variáveis para a corrida ativa
  LatLng? _clientLocation;
  LatLng? _destination;
  String? _currentRideId;
  String? _clientName;

  late AnimationController _markerAnimationController;
  late Animation<LatLng> _markerAnimation;

  final String googleApiKey = "AIzaSyB7WqfU91rDHwnY2x1zFk1tAd7QiJHpUlY";

  Timer? _ridePollingTimer;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadMap();
    _generateHeatMap();
    _initializeUserData();
  }

  void _initializeUserData() {
    // Carregar dados do usuário
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProfissionalProvider>(context, listen: false).loadUserData();
    });
  }

  void _initializeAnimations() {
    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _loadMap() async {
    await _determinePosition();
    setState(() => isLoadingMap = false);
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationPermissionDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationPermissionDialog();
      return;
    }

    // Obter posição inicial
    final pos = await Geolocator.getCurrentPosition();
    _updateDriverPosition(pos);
    
    // Iniciar listening contínuo da posição
    _startLocationUpdates();
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Localização Desativada'),
        content: const Text('Por favor, ative a localização para usar o aplicativo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissão de Localização'),
        content: const Text('Este aplicativo precisa de acesso à localização para funcionar corretamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _updateDriverPosition(position);
    });
  }

  void _updateDriverPosition(Position position) {
    setState(() {
      _currentPosition = position;
    });

    _animateMarkerToPosition(LatLng(position.latitude, position.longitude));

    // Atualizar no backend se estiver online
    final provider = Provider.of<ProfissionalProvider>(context, listen: false);
    if (provider.isOnline) {
      _updateDriverLocationInBackend(position);
    }
  }

  void _animateMarkerToPosition(LatLng newPosition) {
    final previousPosition = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : newPosition;

    _markerAnimation = LatLngTween(
      begin: previousPosition,
      end: newPosition,
    ).animate(CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.easeInOut,
    ));

    _markerAnimationController.forward(from: 0.0);

    _markerAnimation.addListener(() {
      setState(() {
        markers.removeWhere((marker) => marker.markerId.value == "motorista");
        markers.add(Marker(
          markerId: const MarkerId("motorista"),
          position: _markerAnimation.value,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: "Você"),
          rotation: _calculateBearing(previousPosition, newPosition),
        ));
      });
    });
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180.0);
    final startLng = start.longitude * (pi / 180.0);
    final endLat = end.latitude * (pi / 180.0);
    final endLng = end.longitude * (pi / 180.0);

    final y = sin(endLng - startLng) * cos(endLat);
    final x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(endLng - startLng);
    final bearing = atan2(y, x);
    return (bearing * (180.0 / pi) + 360) % 360;
  }

  Future<void> _updateDriverLocationInBackend(Position position) async {
    try {
      final success = await ProfissionalService.updateLocation(
        position.latitude, 
        position.longitude
      );
      
      if (!success) {
        print('Erro ao atualizar localização no backend');
      }
    } catch (e) {
      print('Erro ao atualizar localização: $e');
    }
  }

  void _startRidePolling() {
    _ridePollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final provider = Provider.of<ProfissionalProvider>(context, listen: false);
      if (provider.isOnline && !provider.hasActiveRide) {
        _fetchPendingRides();
      }
    });
  }

  void _stopRidePolling() {
    _ridePollingTimer?.cancel();
    _ridePollingTimer = null;
  }

  Future<void> _fetchPendingRides() async {
    try {
      final rides = await ProfissionalService.getPendingRides();
      if (rides.isNotEmpty && !hasRideRequest) {
        final ride = rides.first;
        _showRideRequest(ride);
      }
    } catch (e) {
      print('Erro ao buscar corridas: $e');
    }
  }

  void _showRideRequest(dynamic ride) {
    setState(() {
      hasRideRequest = true;
      _currentRideId = ride['id'];
      _clientLocation = LatLng(
        ride['pickup_location']['latitude'] ?? -23.55052,
        ride['pickup_location']['longitude'] ?? -46.633308,
      );
      _destination = LatLng(
        ride['destination']['latitude'] ?? -23.56052,
        ride['destination']['longitude'] ?? -46.643308,
      );
      _clientName = ride['client_name'] ?? 'Cliente';
    });
  }

  void _generateHeatMap() {
    heatMapCircles = {
      Circle(
        circleId: const CircleId('1'),
        center: const LatLng(-23.552, -46.634),
        radius: 200,
        fillColor: Colors.red.withOpacity(0.3),
        strokeColor: Colors.transparent,
      ),
      Circle(
        circleId: const CircleId('2'),
        center: const LatLng(-23.548, -46.631),
        radius: 300,
        fillColor: Colors.orange.withOpacity(0.25),
        strokeColor: Colors.transparent,
      ),
    };
  }

  Future<void> _drawRoute(
    LatLng origem,
    LatLng destino,
    String polylineId,
    Color color,
  ) async {
    try {
      PolylinePoints polylinePoints = PolylinePoints(apiKey: googleApiKey);

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origem.latitude, origem.longitude),
          destination: PointLatLng(destino.latitude, destino.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        setState(() {
          polylines.add(
            Polyline(
              polylineId: PolylineId(polylineId),
              color: color,
              width: 5,
              points: polylineCoordinates,
            ),
          );
        });
      } else {
        _drawFallbackRoute(origem, destino, polylineId, color);
      }
    } catch (e) {
      print('❌ Erro ao desenhar rota: $e');
      _drawFallbackRoute(origem, destino, polylineId, color);
    }
  }

  void _drawFallbackRoute(LatLng origem, LatLng destino, String polylineId, Color color) {
    setState(() {
      polylines.add(Polyline(
        polylineId: PolylineId(polylineId),
        color: color.withOpacity(0.5),
        width: 3,
        points: [origem, destino],
      ));
    });
  }

  void _toggleOnline() async {
    final provider = Provider.of<ProfissionalProvider>(context, listen: false);
    final newOnlineStatus = !provider.isOnline;
    
    // Atualizar no backend
    final success = await ProfissionalService.updateAvailability(newOnlineStatus);
    
    if (success) {
      provider.setOnline(newOnlineStatus);
      
      setState(() {
        if (newOnlineStatus) {
          _startRidePolling();
          if (_currentPosition != null) {
            _updateDriverLocationInBackend(_currentPosition!);
          }
        } else {
          _stopRidePolling();
          hasRideRequest = false;
          provider.setActiveRide(false);
          _clearRoutes();
        }
      });
    } else {
      // Mostrar erro
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao atualizar status')),
      );
    }
  }

  void _acceptRide() async {
    if (_currentRideId == null || _clientLocation == null) return;

    try {
      final success = await ProfissionalService.acceptRide(_currentRideId!);
      
      if (success) {
        final provider = Provider.of<ProfissionalProvider>(context, listen: false);
        provider.setActiveRide(true);
        
        setState(() {
          hasRideRequest = false;
        });

        // Desenhar rotas
        if (_currentPosition != null && _destination != null) {
          await _drawRoute(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            _clientLocation!,
            'route_to_client',
            Colors.blue,
          );
          
          await _drawRoute(
            _clientLocation!,
            _destination!,
            'route_to_destination',
            Colors.green,
          );
        }

        _addRideMarkers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao aceitar corrida')),
        );
      }
    } catch (e) {
      print('Erro ao aceitar corrida: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao aceitar corrida')),
      );
    }
  }

  void _addRideMarkers() {
    if (_clientLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId("cliente"),
        position: _clientLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: "Cliente: $_clientName"),
      ));
    }

    if (_destination != null) {
      markers.add(Marker(
        markerId: const MarkerId("destino"),
        position: _destination!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Destino"),
      ));
    }
  }

  void _declineRide() {
    setState(() => hasRideRequest = false);
  }

  void _clearRoutes() {
    setState(() {
      polylines.clear();
      markers.removeWhere((marker) => 
        marker.markerId.value == "cliente" || 
        marker.markerId.value == "destino");
    });
  }

  void _completeRide() async {
    if (_currentRideId != null) {
      final success = await ProfissionalService.completeRide(_currentRideId!);
      
      if (!success) {
        print('Erro ao completar corrida no backend');
      }
    }

    final provider = Provider.of<ProfissionalProvider>(context, listen: false);
    provider.setActiveRide(false);
    
    setState(() {
      _currentRideId = null;
      _clearRoutes();
    });
  }

  @override
  void dispose() {
    _markerAnimationController.dispose();
    _ridePollingTimer?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfissionalProvider>(context);
    final isOnline = provider.isOnline;
    final hasActiveRide = provider.hasActiveRide;

    return Scaffold(
      body: Stack(
        children: [
          // MAPA
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: isLoadingMap || _currentPosition == null
                ? _buildShimmerMapPlaceholder()
                : GoogleMap(
                    key: ValueKey(hasActiveRide),
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      zoom: 15,
                    ),
                    markers: markers,
                    polylines: polylines,
                    circles: heatMapCircles,
                    myLocationEnabled: true,
                    onMapCreated: (controller) => _mapController.complete(controller),
                  ),
          ),

          // TOPO - Botões
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botão Online/Offline
                    Container(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: ElevatedButton.icon(
                        onPressed: _toggleOnline,
                        icon: Icon(
                          isOnline ? Icons.toggle_on : Icons.toggle_off,
                          size: 24,
                        ),
                        label: Text(
                          isOnline ? "Online" : "Offline",
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOnline ? Colors.green : Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),

                    // Botão Finalizar Corrida ou Perfil
                    if (hasActiveRide)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: ElevatedButton(
                          onPressed: _completeRide,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: const Text(
                            "Finalizar",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: IconButton(
                          icon: const Icon(
                            Icons.account_circle,
                            size: 32,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ConfiguracoesPage()),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // POPUP SOLICITAÇÃO DE CORRIDA
          if (hasRideRequest)
            _buildRideRequestPopup(),
        ],
      ),
    );
  }

  Widget _buildRideRequestPopup() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.car_rental,
              size: 40,
              color: Colors.green,
            ),
            const SizedBox(height: 10),
            const Text(
              "Nova Corrida!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Cliente: $_clientName\nDistância: 3.2 km\nPreço estimado: R\$15,00",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Botão Recusar
                Expanded(
                  child: OutlinedButton(
                    onPressed: _declineRide,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Recusar"),
                  ),
                ),
                const SizedBox(width: 10),
                
                // Botão Aceitar
                Expanded(
                  child: ElevatedButton(
                    onPressed: _acceptRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Aceitar"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerMapPlaceholder() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: Colors.grey.shade900,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      ),
    );
  }
}