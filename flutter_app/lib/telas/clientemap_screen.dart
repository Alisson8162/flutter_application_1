import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../providers/cliente_provider.dart';
import '../services/ws_service.dart';

// Estados do pedido, todos resolvidos dentro desta MESMA tela (padrão Uber):
// o cliente vê os profissionais por perto, confirma, acompanha a busca e a
// chegada do profissional sem nenhuma navegação para outra tela/rota.
//
// IMPORTANTE sobre o modelo de negócio real (backend): o cliente NÃO
// solicita um profissional específico. POST /api/rides cria um pedido que
// fica "pending" e visível para TODOS os profissionais compatíveis
// (GET /api/rides/pending, ver profissional_home.dart) - o primeiro que
// aceitar (POST /api/rides/:id/accept) fica com a corrida. A lista de
// profissionais próximos é só informativa (dá uma ideia de disponibilidade
// e tempo/preço estimados), não é uma escolha vinculante.
enum _RequestState { selecting, searching, enRoute }

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
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _professionalIcon;
  List<Map<String, dynamic>> _availableProfessionals = [];
  double _estimatedPrice = 0;
  double _estimatedDistanceKm = 3.0;

  // Cupom de desconto
  final TextEditingController _couponCtrl = TextEditingController();
  Map<String, dynamic>? _appliedCoupon; // {code, discount, finalPrice}
  bool _validatingCoupon = false;
  String? _couponError;

  // Controla em qual etapa do pedido a tela está. Tudo é resolvido aqui
  // mesmo, trocando o painel inferior — nunca navegando para outra tela.
  _RequestState _requestState = _RequestState.selecting;
  int _etaSeconds = 240;
  Timer? _etaTimer;

  // Corrida real (backend) e conexão de tempo real para acompanhá-la.
  String? _rideId;
  Map<String, dynamic>? _acceptedDriver; // {id, name, phone} - vem do WS
  final WsService _wsService = WsService();

  @override
  void initState() {
    super.initState();
    _loadMap();
    _loadCustomIcons();
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    _wsService.disconnect();
    _couponCtrl.dispose();
    super.dispose();
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

    // Carrega profissionais próximos de verdade (GET /location/nearby)
    await _loadAvailableProfessionals();

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
        backgroundColor: AppColors.surface,
        title: Text('Localização Desativada', style: AppText.h2(AppColors.textPrimary)),
        content: Text('Por favor, ative a localização para usar o aplicativo.', style: AppText.body(AppColors.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: AppText.bodyMedium(AppColors.green)),
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
            child: Text('OK', style: AppText.bodyMedium(AppColors.green)),
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

  Future<void> _loadAvailableProfessionals() async {
    if (_currentPosition == null) return;

    final provider = context.read<ClienteProvider>();
    await provider.buscarProfissionaisProximos(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      widget.selectedService,
      widget.vehicleType,
    );
    if (!mounted) return;

    final icon = _professionalIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

    final loaded = provider.nearbyProfessionals.map<Map<String, dynamic>>((raw) {
      final p = raw as Map<String, dynamic>;
      final lat = double.tryParse('${p['current_latitude']}') ?? _currentPosition!.latitude;
      final lng = double.tryParse('${p['current_longitude']}') ?? _currentPosition!.longitude;
      final distanceKm = (p['distance_km'] as num?)?.toDouble() ?? 0.0;
      return {
        'id': p['id'],
        'name': p['name'] ?? 'Profissional',
        'position': LatLng(lat, lng),
        'rating': (double.tryParse('${p['avaliacao_media']}') ?? 5.0),
        'distanceKm': distanceKm,
        'distance': '${distanceKm.toStringAsFixed(1)} km',
        'eta': '${_estimateEtaMinutes(distanceKm)} min',
        'price': _estimatePrice(distanceKm),
      };
    }).toList();

    setState(() {
      _availableProfessionals = loaded;
      _markers.removeWhere((m) => m.markerId.value.startsWith('pro_'));
      for (final pro in _availableProfessionals) {
        _markers.add(
          Marker(
            markerId: MarkerId('pro_${pro['id']}'),
            position: pro['position'] as LatLng,
            icon: icon,
            infoWindow: InfoWindow(title: pro['name'] as String),
          ),
        );
      }

      // A estimativa de preço/distância usada no pedido é a do profissional
      // mais próximo (a lista já vem ordenada por distância pelo backend).
      if (_availableProfessionals.isNotEmpty) {
        _estimatedDistanceKm = _availableProfessionals.first['distanceKm'] as double;
        _estimatedPrice = _availableProfessionals.first['price'] as double;
      } else {
        _estimatedDistanceKm = 3.0;
        _estimatedPrice = _estimatePrice(_estimatedDistanceKm);
      }
    });
  }

  // Estimativa simples de preço - o backend não expõe uma tabela de preços,
  // então o app calcula um valor de referência (o mesmo `estimated_price`
  // enviado em POST /api/rides). Mantém a mesma ordem de grandeza que a
  // versão anterior (mecânico leve ~R$30, pesado ~R$120, guincho ~R$150).
  double _estimatePrice(double distanceKm) {
    double base;
    double perKm;
    if (widget.selectedService == 'guincho') {
      base = 80;
      perKm = 4.5;
    } else if (widget.vehicleType == 'pesado') {
      base = 90;
      perKm = 3.0;
    } else {
      base = 20;
      perKm = 2.5;
    }
    return base + perKm * distanceKm;
  }

  int _estimateEtaMinutes(double distanceKm) {
    // ~25km/h médios em trânsito urbano, com um piso de 4 minutos.
    return max(4, (distanceKm / 25 * 60).round());
  }

  String _formatEta(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _validatingCoupon = true;
      _couponError = null;
    });

    final result = await context.read<ClienteProvider>().validarCupom(code, _estimatedPrice);

    if (!mounted) return;
    setState(() => _validatingCoupon = false);

    if (result['success'] == true) {
      setState(() => _appliedCoupon = result['data'] as Map<String, dynamic>);
    } else {
      setState(() => _couponError = result['message']?.toString() ?? 'Cupom inválido');
    }
  }

  Future<void> _confirmRequest() async {
    if (_currentPosition == null) return;

    setState(() => _requestState = _RequestState.searching);

    final provider = context.read<ClienteProvider>();
    final result = await provider.solicitarServico(
      localizacaoCliente: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      tipoServico: widget.selectedService,
      tipoVeiculo: widget.vehicleType,
      descricaoProblema: widget.serviceName,
      nomeCliente: provider.userName ?? 'Cliente',
      telefoneCliente: provider.userEmail ?? '',
      distanciaKm: _estimatedDistanceKm,
      precoEstimado: _estimatedPrice,
      cupomCodigo: _appliedCoupon?['code'] as String?,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => _requestState = _RequestState.selecting);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Não foi possível solicitar o serviço.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ride = result['data'] as Map<String, dynamic>?;
    _rideId = ride?['id']?.toString();

    if (_rideId != null) {
      _wsService.connectToTrip(
        _rideId!,
        onStatus: _handleRideStatus,
        onLocation: _handleDriverLocation,
      );
    }
  }

  // Mensagens recebidas via WebSocket (ws/trip/:rideId) - ver
  // RideController no backend, que dispara broadcastToRide em cada mudança
  // de status (accepted/in_progress/completed/cancelled).
  void _handleRideStatus(String status, Map<String, dynamic> payload) {
    if (!mounted) return;

    if (status == 'accepted') {
      setState(() {
        _acceptedDriver = payload['driver'] as Map<String, dynamic>?;
        _requestState = _RequestState.enRoute;
        _etaSeconds = _estimateEtaMinutes(_estimatedDistanceKm) * 60;
      });
      _etaTimer?.cancel();
      _etaTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_etaSeconds <= 1) {
          t.cancel();
          setState(() => _etaSeconds = 0);
          return;
        }
        setState(() => _etaSeconds -= 1);
      });
    } else if (status == 'cancelled') {
      _resetToSelecting(message: 'A corrida foi cancelada.');
    }
    // 'in_progress'/'completed': o acompanhamento detalhado é feito na tela
    // de tracking (ClienteMapScreen/RideTrackingScreen); aqui não navegamos
    // automaticamente para não interromper o usuário sem aviso.
  }

  void _handleDriverLocation(String id, LatLng pos, Map<String, dynamic> meta) {
    if (!mounted || _currentPosition == null) return;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('rota_profissional'),
          points: [pos, LatLng(_currentPosition!.latitude, _currentPosition!.longitude)],
          color: _getServiceColor(widget.selectedService),
          width: 4,
        ),
      };
      _markers.removeWhere((m) => m.markerId.value == 'driver_live');
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_live'),
          position: pos,
          icon: _professionalIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    });
  }

  void _resetToSelecting({String? message}) {
    _etaTimer?.cancel();
    _wsService.disconnect();
    setState(() {
      _requestState = _RequestState.selecting;
      _polylines = {};
      _acceptedDriver = null;
      _rideId = null;
    });
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _cancelRequest() async {
    final rideId = _rideId;
    _resetToSelecting();
    if (rideId != null) {
      await context.read<ClienteProvider>().cancelarCorrida(rideId);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedido cancelado.')),
    );
  }

  Future<void> _callDriver() async {
    final phone = _acceptedDriver?['phone']?.toString();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        backgroundColor: _getServiceColor(widget.selectedService),
        automaticallyImplyLeading: _requestState == _RequestState.selecting,
        leading: _requestState != _RequestState.selecting ? const SizedBox.shrink() : null,
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
                  polylines: _polylines,
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

          // Painel inferior estilo Uber — muda de conteúdo conforme
          // _requestState, mas é sempre a MESMA tela/rota.
          if (!_isLoading && _currentPosition != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildBottomPanel(),
              ),
            ),
        ],
      ),
    );
  }

  String _appBarTitle() {
    switch (_requestState) {
      case _RequestState.selecting:
        return '${widget.serviceName} - Veículo ${widget.vehicleType == 'leve' ? 'Leve' : 'Pesado'}';
      case _RequestState.searching:
        return 'Buscando profissional...';
      case _RequestState.enRoute:
        return 'Profissional a caminho';
    }
  }

  Widget _buildBottomPanel() {
    switch (_requestState) {
      case _RequestState.searching:
        return KeyedSubtree(key: const ValueKey('searching'), child: _buildSearchingPanel());
      case _RequestState.enRoute:
        return KeyedSubtree(key: const ValueKey('enRoute'), child: _buildEnRoutePanel());
      case _RequestState.selecting:
        return KeyedSubtree(key: const ValueKey('selecting'), child: _buildSelectingPanel());
    }
  }

  Widget _buildSelectingPanel() {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Indicador de arraste
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Informações do serviço
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getServiceColor(widget.selectedService).withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getServiceIcon(widget.selectedService),
                          color: _getServiceColor(widget.selectedService),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.serviceName, style: AppText.h2(AppColors.textPrimary)),
                            Text(
                              'Veículo ${widget.vehicleType == 'leve' ? 'Leve' : 'Pesado'}',
                              style: AppText.caption(AppColors.textDim),
                            ),
                          ],
                        ),
                      ),
                      if (_availableProfessionals.isNotEmpty)
                        Chip(
                          backgroundColor: _getServiceColor(widget.selectedService).withOpacity(0.14),
                          side: BorderSide.none,
                          label: Text(
                            '${_availableProfessionals.length} disponíveis',
                            style: AppText.caption(_getServiceColor(widget.selectedService)).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Lista de profissionais disponíveis (informativo — a
                  // solicitação vai para todos os profissionais compatíveis,
                  // não é uma escolha vinculante de um específico)
                  if (_availableProfessionals.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.textFaint, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhum profissional por perto no momento,\nmas sua solicitação ainda será enviada.',
                            style: AppText.body(AppColors.textDim),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Profissionais por perto', style: AppText.bodyMedium(AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 12),
                        ..._availableProfessionals.map((pro) => 
                          _buildProfessionalCard(pro),
                        ).toList(),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Estimativa de preço
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadius.smBr,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estimativa', style: AppText.caption(AppColors.textDim)),
                            Text(
                              'R\$${_estimatedPrice.toStringAsFixed(2)}',
                              style: _appliedCoupon != null
                                  ? AppText.caption(AppColors.textFaint).copyWith(decoration: TextDecoration.lineThrough)
                                  : AppText.bodyMedium(AppColors.textPrimary),
                            ),
                          ],
                        ),
                        if (_appliedCoupon != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Com cupom ${_appliedCoupon!['code']}', style: AppText.caption(AppColors.green)),
                              Text(
                                'R\$${(_appliedCoupon!['finalPrice'] as num).toStringAsFixed(2)}',
                                style: AppText.bodyMedium(AppColors.green),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cupom de desconto
                  if (_appliedCoupon == null)
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _couponCtrl,
                            hint: 'Cupom de desconto (opcional)',
                            leading: Icons.local_offer_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _validatingCoupon ? null : _applyCoupon,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _getServiceColor(widget.selectedService),
                              side: BorderSide(color: _getServiceColor(widget.selectedService)),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
                            ),
                            child: _validatingCoupon
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Aplicar'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Cupom ${_appliedCoupon!['code']} aplicado', style: AppText.caption(AppColors.green)),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _appliedCoupon = null;
                            _couponCtrl.clear();
                          }),
                          child: Text('Remover', style: AppText.caption(AppColors.textFaint)),
                        ),
                      ],
                    ),
                  if (_couponError != null) ...[
                    const SizedBox(height: 6),
                    Text(_couponError!, style: AppText.caption(AppColors.red)),
                  ],

                  const SizedBox(height: 16),

                  // Botão de confirmação - envia o pedido para todos os
                  // profissionais compatíveis disponíveis no momento.
                  AppPrimaryButton(
                    label: 'Solicitar ${widget.serviceName}',
                    onPressed: _currentPosition != null ? _confirmRequest : null,
                    color: _getServiceColor(widget.selectedService),
                    foreground: Colors.white,
                    icon: Icons.check_circle_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Painel: buscando confirmação do profissional (mesma tela) ----
  Widget _buildSearchingPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 1)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _getServiceColor(widget.selectedService),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Buscando um profissional...',
            style: AppText.h2(AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Avisamos assim que alguém aceitar seu pedido',
            style: AppText.body(AppColors.textDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          AppOutlinedButton(label: 'Cancelar', onPressed: _cancelRequest, height: 50),
        ],
      ),
    );
  }

  // ---- Painel: profissional a caminho (mesma tela) ----
  Widget _buildEnRoutePanel() {
    final driver = _acceptedDriver;
    final driverName = driver?['name']?.toString() ?? 'Profissional';
    final color = _getServiceColor(widget.selectedService);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 1)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profissional a caminho', style: AppText.h2(AppColors.textPrimary)),
                    Text('Chega em ${_formatEta(_etaSeconds)}', style: AppText.caption(AppColors.textDim)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color,
                child: Text(
                  driverName.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName, style: AppText.bodyMedium(AppColors.textPrimary)),
                    Text('R\$${_estimatedPrice.toStringAsFixed(2)} (estimado)', style: AppText.caption(AppColors.textDim)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _callDriver,
                icon: Icon(Icons.phone_rounded, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelRequest,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
              ),
              child: const Text('Cancelar solicitação'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalCard(Map<String, dynamic> professional) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                  Text(professional['name'], style: AppText.bodyMedium(AppColors.textPrimary)),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber[400], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        (professional['rating'] as double).toStringAsFixed(1),
                        style: AppText.caption(AppColors.textDim),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on_rounded, color: AppColors.textFaint, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        professional['distance'],
                        style: AppText.caption(AppColors.textDim),
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
                  style: AppText.bodyMedium(AppColors.green),
                ),
                Text(
                  'R\$${(professional['price'] as double).toStringAsFixed(2)}',
                  style: AppText.bodyMedium(AppColors.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType) {
      case 'mecanico':
        return AppColors.amber;
      case 'guincho':
        return AppColors.blue;
      case 'borracharia':
        return AppColors.red;
      case 'eletrica':
        return const Color(0xFFEAB308);
      default:
        return AppColors.green;
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
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Mapa Google
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.amber))
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
                color: AppColors.surface,
                borderRadius: AppRadius.mdBr,
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location_rounded, color: AppColors.blue),
                    onPressed: _goToMyLocation,
                  ),
                  IconButton(
                    icon: const Icon(Icons.directions_car_rounded, color: AppColors.amber),
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.amber,
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: Color(0xFF201400),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName ?? 'Motorista',
                        style: AppText.h2(AppColors.textPrimary),
                      ),
                      Text(
                        _getStatusText(widget.rideStatus ?? 'accepted'),
                        style: AppText.caption(_getStatusColor(widget.rideStatus ?? 'accepted')),
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
                        style: AppText.h2(AppColors.green),
                      ),
                      Text(
                        '1.2 km',
                        style: AppText.caption(AppColors.textDim),
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
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text('Ligar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: const Color(0xFF06120A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onMessagePressed ?? () {
                    // Lógica de mensagem
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abrindo conversa')),
                    );
                  },
                  icon: const Icon(Icons.message_rounded, size: 18),
                  label: const Text('Mensagem'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onCancelPressed ?? () {
                    // Lógica de cancelamento
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: Text('Cancelar Corrida', style: AppText.h2(AppColors.textPrimary)),
                        content: Text('Tem certeza que deseja cancelar esta corrida?', style: AppText.body(AppColors.textDim)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Não', style: AppText.bodyMedium(AppColors.textDim)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Corrida cancelada')),
                              );
                            },
                            child: Text('Sim', style: AppText.bodyMedium(AppColors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancelar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.redDim,
                    foregroundColor: AppColors.red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Detalhes da rota
            if (widget.pickupLocation != null && widget.destination != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.smBr,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ponto de encontro',
                            style: AppText.caption(AppColors.textDim),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Destino',
                            style: AppText.caption(AppColors.textDim),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            color: AppColors.amber,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Motorista aceito',
              style: AppText.caption(progress >= 0.3 ? AppColors.amber : AppColors.textFaint),
            ),
            Text(
              'A caminho',
              style: AppText.caption(progress >= 0.6 ? AppColors.amber : AppColors.textFaint),
            ),
            Text(
              'Chegou',
              style: AppText.caption(progress >= 1.0 ? AppColors.amber : AppColors.textFaint),
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
        return AppColors.amber;
      case 'in_progress':
        return AppColors.green;
      case 'completed':
        return AppColors.blue;
      case 'cancelled':
        return AppColors.red;
      default:
        return AppColors.textDim;
    }
  }
}