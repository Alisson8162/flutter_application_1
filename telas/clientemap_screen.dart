import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'clienteride_flow.dart';

class ClienteMapScreenWithService extends StatefulWidget {
  final String selectedService;
  final String serviceName;
  final String vehicleType;

  const ClienteMapScreenWithService({
    super.key,
    required this.selectedService,
    required this.serviceName,
    required this.vehicleType,
  });

  @override
  State<ClienteMapScreenWithService> createState() => _ClienteMapScreenWithServiceState();
}

class _ClienteMapScreenWithServiceState extends State<ClienteMapScreenWithService> {
  final Completer<GoogleMapController> _mapController = Completer();
  bool _isLoading = true;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  BitmapDescriptor? _professionalIcon;
  Map<String, dynamic>? _selectedProfessional;
  List<Map<String, dynamic>> _availableProfessionals = [];

  @override
  void initState() {
    super.initState();
    _loadMap();
    _loadCustomIcons();
  }

  Future<void> _loadCustomIcons() async {
    try {
      _professionalIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/professional.png',
      );
    } catch (e) {
      _professionalIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  Future<void> _loadMap() async {
    await _getCurrentLocation();
    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
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

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _addUserMarker();
    });

    // Carrega profissionais baseado no tipo de serviço selecionado
    _loadAvailableProfessionals();

    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15,
      ),
    );
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

  void _addUserMarker() {
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Sua Localização'),
        ),
      );

      _circles.add(
        Circle(
          circleId: const CircleId('accuracy_circle'),
          center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          radius: _currentPosition!.accuracy,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue.withOpacity(0.5),
          strokeWidth: 1,
        ),
      );
    }
  }

  void _loadAvailableProfessionals() {
    // Simulação de profissionais disponíveis baseado no serviço e tipo de veículo
    _availableProfessionals.clear();
    
    if (_currentPosition == null) return;

    final profissionalIcon = _professionalIcon ?? 
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

    // Filtra profissionais baseado no tipo de serviço selecionado
    if (widget.selectedService == 'mecanico' && widget.vehicleType == 'leve') {
      // Mecânicos para veículos leves
      _availableProfessionals.addAll([
        {
          'id': '1',
          'name': 'Mecânico João',
          'position': LatLng(
            _currentPosition!.latitude + 0.003,
            _currentPosition!.longitude + 0.003,
          ),
          'rating': 4.8,
          'distance': '0.8 km',
          'eta': '5-8 min',
          'price': 30.00,
          'vehicleType': 'leve',
          'serviceType': 'mecanico',
        },
        {
          'id': '2',
          'name': 'Mecânico Carlos',
          'position': LatLng(
            _currentPosition!.latitude - 0.004,
            _currentPosition!.longitude - 0.002,
          ),
          'rating': 4.9,
          'distance': '1.2 km',
          'eta': '8-12 min',
          'price': 35.00,
          'vehicleType': 'leve',
          'serviceType': 'mecanico',
        },
      ]);
    } else if (widget.selectedService == 'mecanico' && widget.vehicleType == 'pesado') {
      // Mecânicos para veículos pesados
      _availableProfessionals.addAll([
        {
          'id': '3',
          'name': 'Mecânico Pesado Silva',
          'position': LatLng(
            _currentPosition!.latitude + 0.005,
            _currentPosition!.longitude + 0.001,
          ),
          'rating': 4.7,
          'distance': '1.5 km',
          'eta': '10-15 min',
          'price': 120.00,
          'vehicleType': 'pesado',
          'serviceType': 'mecanico',
        },
      ]);
    } else if (widget.selectedService == 'guincho') {
      // Guinchos para veículos pesados
      _availableProfessionals.addAll([
        {
          'id': '4',
          'name': 'Guincho Maria',
          'position': LatLng(
            _currentPosition!.latitude + 0.002,
            _currentPosition!.longitude - 0.003,
          ),
          'rating': 4.6,
          'distance': '2.0 km',
          'eta': '15-25 min',
          'price': 150.00,
          'vehicleType': 'pesado',
          'serviceType': 'guincho',
        },
      ]);
    }

    // Adiciona marcadores no mapa
    for (var pro in _availableProfessionals) {
      _markers.add(
        Marker(
          markerId: MarkerId('pro_${pro['id']}'),
          position: pro['position'],
          icon: profissionalIcon,
          infoWindow: InfoWindow(title: pro['name']),
          onTap: () {
            setState(() {
              _selectedProfessional = pro;
            });
          },
        ),
      );
    }

    // Seleciona o primeiro profissional por padrão (mais próximo)
    if (_availableProfessionals.isNotEmpty && _selectedProfessional == null) {
      setState(() {
        _selectedProfessional = _availableProfessionals[0];
      });
    }
  }

  void _confirmRequest() {
    if (_selectedProfessional == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um profissional'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideFlowScreen(
          origin: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          destination: LatLng(
            _currentPosition!.latitude + 0.01,
            _currentPosition!.longitude + 0.01,
          ),
          professionalType: widget.selectedService,
          professionalName: _selectedProfessional!['name'],
          vehicleType: widget.vehicleType,
          estimatedPrice: _selectedProfessional!['price'],
          estimatedTime: _selectedProfessional!['eta'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.serviceName} - Veículo ${widget.vehicleType == 'leve' ? 'Leve' : 'Pesado'}'),
        backgroundColor: _getServiceColor(widget.selectedService),
      ),
      body: Stack(
        children: [
          // Mapa
          _isLoading || _currentPosition == null
              ? Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.greenAccent),
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    zoom: 15,
                  ),
                  markers: _markers,
                  circles: _circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) => _mapController.complete(controller),
                ),

          // Botão localização
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.white),
                  onPressed: _getCurrentLocation,
                ),
              ),
            ),
          ),

          // Painel inferior estilo Uber
          if (!_isLoading && _currentPosition != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Indicador de arraste
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Informações do serviço
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getServiceIcon(widget.selectedService),
                      color: _getServiceColor(widget.selectedService),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.serviceName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Veículo ${widget.vehicleType == 'leve' ? 'Leve' : 'Pesado'}',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_availableProfessionals.isNotEmpty)
                      Chip(
                        backgroundColor: _getServiceColor(widget.selectedService).withOpacity(0.1),
                        label: Text(
                          '${_availableProfessionals.length} disponíveis',
                          style: TextStyle(
                            color: _getServiceColor(widget.selectedService),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Lista de profissionais disponíveis
                if (_availableProfessionals.isEmpty)
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Nenhum profissional disponível no momento',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      const Text(
                        'Profissionais Disponíveis:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._availableProfessionals.map((pro) => 
                        _buildProfessionalCard(pro),
                      ).toList(),
                    ],
                  ),

                const SizedBox(height: 16),

                // Botão de confirmação
                if (_availableProfessionals.isNotEmpty && _selectedProfessional != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getServiceColor(widget.selectedService),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle),
                          const SizedBox(width: 8),
                          Text(
                            'Solicitar ${_selectedProfessional!['name']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalCard(Map<String, dynamic> professional) {
    final bool isSelected = _selectedProfessional != null && 
                          _selectedProfessional!['id'] == professional['id'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? _getServiceColor(widget.selectedService).withOpacity(0.1) : null,
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? _getServiceColor(widget.selectedService) : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedProfessional = professional;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _getServiceColor(widget.selectedService),
                child: Text(
                  professional['name'].toString().substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.yellow[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${professional['rating']}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, color: Colors.grey[600], size: 14),
                        const SizedBox(width: 4),
                        Text(
                          professional['distance'],
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    professional['eta'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'R\$${professional['price'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType) {
      case 'mecanico':
        return Colors.orange;
      case 'guincho':
        return Colors.blue;
      case 'borracharia':
        return Colors.red;
      case 'eletrica':
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType) {
      case 'mecanico':
        return Icons.build;
      case 'guincho':
        return Icons.local_shipping;
      case 'borracharia':
        return Icons.directions_car;
      case 'eletrica':
        return Icons.electric_bolt;
      default:
        return Icons.construction;
    }
  }
}

// Mapa completo para tracking de corrida em tempo real
class ClienteMapScreen extends StatefulWidget {
  final LatLng? driverLocation;
  final LatLng? pickupLocation;
  final LatLng? destination;
  final String? driverName;
  final String? rideStatus;
  final Function()? onCallPressed;
  final Function()? onCancelPressed;
  final Function()? onMessagePressed;

  const ClienteMapScreen({
    super.key,
    this.driverLocation,
    this.pickupLocation,
    this.destination,
    this.driverName,
    this.rideStatus = 'accepted',
    this.onCallPressed,
    this.onCancelPressed,
    this.onMessagePressed,
  });

  @override
  State<ClienteMapScreen> createState() => _ClienteMapScreenState();
}

class _ClienteMapScreenState extends State<ClienteMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  late GoogleMapController _googleMapController;
  Position? _currentUserPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentDriverLocation;
  Timer? _locationUpdateTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startLocationUpdates();
  }

  Future<void> _initializeMap() async {
    await _getUserLocation();
    _setupMarkers();
    _setCameraToRoute();
    setState(() => _isLoading = false);
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentUserPosition = position;
      });
    } catch (e) {
      print('Erro ao obter localização: $e');
    }
  }

  void _setupMarkers() {
    _markers.clear();

    // Marcador do motorista
    final driverLatLng = widget.driverLocation ?? 
                       _currentDriverLocation ?? 
                       widget.pickupLocation ?? 
                       const LatLng(-23.55052, -46.633308);

    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: widget.driverName ?? 'Motorista'),
        rotation: 45, // Simula direção do veículo
      ),
    );

    // Marcador do usuário (se disponível)
    if (_currentUserPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Você'),
        ),
      );
    }

    // Marcador de pickup
    if (widget.pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Ponto de Encontro'),
        ),
      );
    }

    // Marcador de destino
    if (widget.destination != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: widget.destination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destino'),
        ),
      );
    }

    // Criar polilinhas (rotas)
    _createPolylines();
  }

  void _createPolylines() {
    _polylines.clear();

    // Rota do motorista até o pickup
    if (widget.driverLocation != null && widget.pickupLocation != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_driver_to_pickup'),
          points: [widget.driverLocation!, widget.pickupLocation!],
          color: Colors.orange,
          width: 4,
          patterns: [PatternItem.dash(15), PatternItem.gap(10)],
        ),
      );
    }

    // Rota do pickup até o destino
    if (widget.pickupLocation != null && widget.destination != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_pickup_to_destination'),
          points: [widget.pickupLocation!, widget.destination!],
          color: Colors.green,
          width: 4,
        ),
      );
    }
  }

  void _setCameraToRoute() async {
    if (_googleMapController != null) {
      LatLngBounds bounds = _calculateBounds();
      
      await _googleMapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  LatLngBounds _calculateBounds() {
    List<LatLng> allPoints = [];
    
    if (widget.driverLocation != null) allPoints.add(widget.driverLocation!);
    if (_currentUserPosition != null) {
      allPoints.add(LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude));
    }
    if (widget.pickupLocation != null) allPoints.add(widget.pickupLocation!);
    if (widget.destination != null) allPoints.add(widget.destination!);

    if (allPoints.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(-23.6, -46.7),
        northeast: const LatLng(-23.5, -46.6),
      );
    }

    double minLat = allPoints[0].latitude;
    double maxLat = allPoints[0].latitude;
    double minLng = allPoints[0].longitude;
    double maxLng = allPoints[0].longitude;

    for (var point in allPoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat - 0.005, minLng - 0.005),
      northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
    );
  }

  void _startLocationUpdates() {
    // Simula atualização da localização do motorista em tempo real
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _simulateDriverMovement();
    });
  }

  void _simulateDriverMovement() {
    if (widget.driverLocation == null || widget.pickupLocation == null) return;

    setState(() {
      // Simula movimento do motorista em direção ao pickup
      final currentLat = _currentDriverLocation?.latitude ?? widget.driverLocation!.latitude;
      final currentLng = _currentDriverLocation?.longitude ?? widget.driverLocation!.longitude;
      
      final targetLat = widget.pickupLocation!.latitude;
      final targetLng = widget.pickupLocation!.longitude;
      
      // Move 10% em direção ao destino a cada atualização
      final newLat = currentLat + (targetLat - currentLat) * 0.1;
      final newLng = currentLng + (targetLng - currentLng) * 0.1;
      
      _currentDriverLocation = LatLng(newLat, newLng);
      
      // Atualiza marcador do motorista
      _markers.removeWhere((marker) => marker.markerId.value == 'driver');
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentDriverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: widget.driverName ?? 'Motorista'),
          rotation: _calculateBearing(
            currentLat, currentLng, 
            newLat, newLng
          ),
        ),
      );
      
      // Atualiza polilinha
      _createPolylines();
    });
  }

  double _calculateBearing(double startLat, double startLng, double endLat, double endLng) {
    final dLon = endLng - startLng;
    final y = sin(dLon) * cos(endLat);
    final x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLon);
    final bearing = atan2(y, x);
    return bearing * 180 / pi;
  }

  Future<void> _goToMyLocation() async {
    if (_currentUserPosition != null && _googleMapController != null) {
      await _googleMapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude),
        ),
      );
    }
  }

  Future<void> _goToDriverLocation() async {
    if (_currentDriverLocation != null && _googleMapController != null) {
      await _googleMapController.animateCamera(
        CameraUpdate.newLatLng(
          _currentDriverLocation!,
        ),
      );
    }
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa Google
          _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.orange))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.pickupLocation ?? 
                            widget.driverLocation ?? 
                            const LatLng(-23.55052, -46.633308),
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController.complete(controller);
                    _googleMapController = controller;
                    _setCameraToRoute();
                  },
                ),

          // Botões de controle
          Positioned(
            top: 60,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: _goToMyLocation,
                  ),
                  IconButton(
                    icon: Icon(Icons.directions_car, color: Colors.orange),
                    onPressed: _goToDriverLocation,
                  ),
                ],
              ),
            ),
          ),

          // Painel inferior de informações
          if (!_isLoading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildInfoPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(
                    Icons.directions_car,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName ?? 'Motorista',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _getStatusText(widget.rideStatus ?? 'accepted'),
                        style: TextStyle(
                          color: _getStatusColor(widget.rideStatus ?? 'accepted'),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.driverLocation != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '~8 min',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '1.2 km',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Barra de progresso da corrida
            _buildRideProgress(),

            const SizedBox(height: 16),

            // Botões de ação
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onCallPressed ?? () {
                    // Lógica de chamada
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ligando para ${widget.driverName}')),
                    );
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Ligar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onMessagePressed ?? () {
                    // Lógica de mensagem
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abrindo conversa')),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Mensagem'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onCancelPressed ?? () {
                    // Lógica de cancelamento
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cancelar Corrida'),
                        content: const Text('Tem certeza que deseja cancelar esta corrida?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Não'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Corrida cancelada')),
                              );
                            },
                            child: const Text('Sim', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Detalhes da rota
            if (widget.pickupLocation != null && widget.destination != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ponto de encontro',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Destino',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideProgress() {
    final status = widget.rideStatus ?? 'accepted';
    double progress = 0.3; // Valor padrão
    
    if (status == 'accepted') progress = 0.3;
    if (status == 'in_progress') progress = 0.6;
    if (status == 'completed') progress = 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          color: Colors.orange,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Motorista aceito',
              style: TextStyle(
                fontSize: 12,
                color: progress >= 0.3 ? Colors.orange : Colors.grey,
              ),
            ),
            Text(
              'A caminho',
              style: TextStyle(
                fontSize: 12,
                color: progress >= 0.6 ? Colors.orange : Colors.grey,
              ),
            ),
            Text(
              'Chegou',
              style: TextStyle(
                fontSize: 12,
                color: progress >= 1.0 ? Colors.orange : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Motorista a caminho do encontro';
      case 'in_progress':
        return 'Em andamento - a caminho do destino';
      case 'completed':
        return 'Corrida finalizada';
      case 'cancelled':
        return 'Corrida cancelada';
      default:
        return 'Aguardando motorista';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.orange;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}