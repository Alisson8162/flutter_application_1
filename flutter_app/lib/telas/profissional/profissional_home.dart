import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:provider/provider.dart';
import '../profissional/profissional_service.dart';
import '../../providers/profissional_provider.dart';
import '../../config/app_config.dart';
import 'configuracoes_page.dart';
import 'subscription_screen.dart';
import '../chat_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

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

  final String googleApiKey = AppConfig.googleMapsApiKey;

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
        backgroundColor: AppColors.surface,
        title: Text('Localização Desativada', style: AppText.h2(AppColors.textPrimary)),
        content: Text('Por favor, ative a localização para usar o aplicativo.', style: AppText.body(AppColors.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: AppText.bodyMedium(AppColors.amber)),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Permissão de Localização', style: AppText.h2(AppColors.textPrimary)),
        content: Text('Este aplicativo precisa de acesso à localização para funcionar corretamente.', style: AppText.body(AppColors.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: AppText.bodyMedium(AppColors.amber)),
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
    final result = await ProfissionalService.updateAvailability(newOnlineStatus);

    if (result['success'] == true) {
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
    } else if (result['code'] == 'ASSINATURA_INATIVA') {
      _showBlockedDialog(
        title: 'Assinatura inativa',
        message: result['message']?.toString() ??
            'Sua mensalidade não está em dia. Regularize o pagamento para ficar disponível.',
        actionLabel: 'Ver assinatura',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        ),
      );
    } else if (result['code'] == 'DOCUMENTACAO_PENDENTE') {
      _showBlockedDialog(
        title: 'Documentação em análise',
        message: result['message']?.toString() ??
            'Sua documentação ainda está em análise. Você poderá ficar online assim que for aprovada.',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Erro ao atualizar status')),
      );
    }
  }

  void _showBlockedDialog({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: AppText.h2(AppColors.textPrimary)),
        content: Text(message, style: AppText.body(AppColors.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fechar', style: AppText.bodyMedium(AppColors.textDim)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onAction?.call();
              },
              child: Text(actionLabel, style: AppText.bodyMedium(AppColors.green)),
            ),
        ],
      ),
    );
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

  void _openChat() {
    if (_currentRideId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          rideId: _currentRideId!,
          otherPartyName: _clientName ?? 'Cliente',
          accent: AppColors.amber,
        ),
      ),
    );
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
      backgroundColor: AppColors.bg,
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

          // AVISO PERSISTENTE de assinatura/documentação pendente - antes só
          // aparecia se a pessoa tentasse tocar em "ficar online"; agora fica
          // visível o tempo todo enquanto a conta não está 100% liberada.
          if (!provider.contaAtiva || !provider.documentacaoAprovada)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    ),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.amberDim,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              !provider.contaAtiva
                                  ? 'Assinatura inativa - você não recebe corridas até regularizar'
                                  : 'Documentação em análise - toque para acompanhar',
                              style: AppText.bodyMedium(AppColors.amber),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.amber, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
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
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _toggleOnline,
                        icon: Icon(
                          isOnline ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                          size: 24,
                        ),
                        label: Text(
                          isOnline ? "Online" : "Offline",
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOnline ? AppColors.green : AppColors.surfaceElevated,
                          foregroundColor: isOnline ? const Color(0xFF06120A) : AppColors.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),

                    // Botão Finalizar Corrida ou Perfil
                    if (hasActiveRide) ...[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceElevated,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22, color: AppColors.textPrimary),
                          onPressed: _openChat,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 150),
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.smBr,
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))],
                        ),
                        child: ElevatedButton(
                          onPressed: _completeRide,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: const Color(0xFF201400),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
                          ),
                          child: const Text(
                            "Finalizar",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ]
                    else
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceElevated,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.account_circle_rounded,
                            size: 26,
                            color: AppColors.textPrimary,
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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgBr,
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: AppColors.amberDim, shape: BoxShape.circle),
              child: const Icon(
                Icons.car_rental_rounded,
                size: 32,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Nova Corrida!",
              style: AppText.h1(AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Cliente: $_clientName\nDistância: 3.2 km\nPreço estimado: R\$15,00",
              textAlign: TextAlign.center,
              style: AppText.body(AppColors.textDim),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Botão Recusar
                Expanded(
                  child: AppOutlinedButton(label: "Recusar", onPressed: _declineRide, height: 48),
                ),
                const SizedBox(width: 10),

                // Botão Aceitar
                Expanded(
                  child: AppPrimaryButton(label: "Aceitar", onPressed: _acceptRide, color: AppColors.amber, height: 48),
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
      color: AppColors.bg,
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      ),
    );
  }
}