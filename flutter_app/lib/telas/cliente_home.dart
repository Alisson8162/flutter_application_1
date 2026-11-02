// lib/telas/cliente_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'clientemap_screen.dart';
import 'reportar_problema.dart';
import 'central_ajuda.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../providers/cliente_provider.dart';
import '../services/ws_service.dart';
import 'chat_screen.dart';
import 'wallet_screen.dart';
import 'two_factor_settings_screen.dart';
import '../services/api_service.dart';

class ClienteHome extends StatefulWidget {
  const ClienteHome({super.key});

  @override
  State<ClienteHome> createState() => _ClienteHomeState();
}

class _ClienteHomeState extends State<ClienteHome> {
  int _selectedIndex = 0;
  bool _hasActiveRide = false;
  Map<String, dynamic>? _currentRide;
  Timer? _ridePollingTimer;
  String? _lastNotifiedStatus;

  @override
  void initState() {
    super.initState();
    _checkActiveRide();
    // Mesma ideia de polling já usada no lado do profissional
    // (profissional_home.dart) - o app ainda não tem push notifications
    // (ver relatório), então checamos periodicamente por atualizações.
    _ridePollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkActiveRide());
  }

  Future<void> _checkActiveRide() async {
    final provider = context.read<ClienteProvider>();
    final ride = await provider.buscarCorridaAtiva();
    if (!mounted) return;

    final status = ride?['status']?.toString();
    final isActive = ride != null && (status == 'accepted' || status == 'in_progress');

    setState(() {
      _hasActiveRide = isActive;
      _currentRide = isActive ? ride : null;
    });

    if (isActive && status != _lastNotifiedStatus) {
      _lastNotifiedStatus = status;
      _showActiveRideNotification(ride);
    } else if (!isActive) {
      _lastNotifiedStatus = null;
    }
  }

  void _showActiveRideNotification(Map<String, dynamic> ride) {
    final driverName = ride['driver_name'] ?? 'Profissional';
    final status = ride['status'];

    if (status == 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $driverName aceitou sua corrida!'),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Acompanhar',
            textColor: Colors.white,
            onPressed: () {
              _navigateToRideTracking(ride);
            },
          ),
        ),
      );
    } else if (status == 'in_progress') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚗 $driverName está a caminho!'),
          backgroundColor: AppColors.amber,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Ver rota',
            textColor: Colors.white,
            onPressed: () {
              _navigateToRideTracking(ride);
            },
          ),
        ),
      );
    }
  }

  void _navigateToRideTracking(Map<String, dynamic> ride) {
    final pickup = ride['pickup_location'] as Map<String, dynamic>?;
    final dest = ride['destination'] as Map<String, dynamic>?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideTrackingScreen(
          rideId: ride['id'].toString(),
          pickupLocation: LatLng(
            (pickup?['latitude'] as num?)?.toDouble() ?? 0,
            (pickup?['longitude'] as num?)?.toDouble() ?? 0,
          ),
          destination: LatLng(
            (dest?['latitude'] as num?)?.toDouble() ?? 0,
            (dest?['longitude'] as num?)?.toDouble() ?? 0,
          ),
          driverName: ride['driver_name']?.toString() ?? 'Profissional',
          driverPhone: ride['driver_phone']?.toString(),
          vehicleType: pickup?['tipo_veiculo']?.toString() ?? 'leve',
        ),
      ),
    );
  }

  // Diferentes telas/páginas do cliente
  List<Widget> get _widgetOptions => <Widget>[
        HomeTab(hasActiveRide: _hasActiveRide, currentRide: _currentRide),
        const HistoricoTab(),
        const PerfilTab(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _ridePollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Fala Comigo', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Badge para notificações de corrida
          if (_hasActiveRide)
            Badge(
              backgroundColor: AppColors.red,
              label: const Text('1', style: TextStyle(color: Colors.white)),
              child: IconButton(
                icon: const Icon(Icons.directions_car_rounded, color: AppColors.textPrimary),
                onPressed: () {
                  if (_currentRide != null) {
                    _navigateToRideTracking(_currentRide!);
                  }
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
            onPressed: () {
              _showNotifications();
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: AppColors.textPrimary),
            onPressed: () {
              _showHelp();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _widgetOptions.elementAt(_selectedIndex),
      floatingActionButton: _selectedIndex == 0 ? _buildEmergencyButton() : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Início',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.history_rounded),
                    if (_hasActiveRide)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 10,
                            minHeight: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Histórico',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Perfil',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: AppColors.green,
            unselectedItemColor: AppColors.textFaint,
            selectedLabelStyle: AppText.caption(AppColors.green),
            unselectedLabelStyle: AppText.caption(AppColors.textFaint),
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.green, Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: AppColors.green),
                ),
                const SizedBox(height: 10),
                const Text(
                  'João Silva',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'joao@email.com',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
                if (_hasActiveRide) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Corrida Ativa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _drawerItem(Icons.favorite_rounded, 'Favoritos', () {
            _showFavorites();
            Navigator.pop(context);
          }),
          _drawerItem(Icons.settings_rounded, 'Configurações', () {
            _showSettings();
            Navigator.pop(context);
          }),
          const Divider(color: AppColors.border, height: 1),
          if (_hasActiveRide)
            _drawerItem(
              Icons.directions_car_rounded,
              'Corrida Ativa',
              () {
                Navigator.pop(context);
                if (_currentRide != null) {
                  _navigateToRideTracking(_currentRide!);
                }
              },
              iconColor: AppColors.green,
              subtitle: 'Acompanhe seu profissional',
            ),
          _drawerItem(Icons.help_outline_rounded, "Central de Ajuda", () {
            Navigator.pushNamed(context, '/ajuda');
          }, iconColor: AppColors.blue),
          _drawerItem(Icons.help_rounded, 'Ajuda', () {
            _showHelp();
            Navigator.pop(context);
          }),
          _drawerItem(Icons.logout_rounded, 'Sair', _logout, iconColor: AppColors.red),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap,
      {Color iconColor = AppColors.textDim, String? subtitle}) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: AppText.bodyMedium(AppColors.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle, style: AppText.caption(AppColors.textDim)) : null,
      onTap: onTap,
    );
  }

  Widget _buildEmergencyButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ClienteMapScreen()),
        );
      },
      backgroundColor: _hasActiveRide ? AppColors.amber : AppColors.green,
      child: const Icon(Icons.directions_car_rounded, color: Color(0xFF06120A)),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Notificações', style: AppText.h2(AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                if (_hasActiveRide && _currentRide != null)
                  ListTile(
                    leading: const Icon(Icons.car_repair_rounded, color: AppColors.green),
                    title: Text('Profissional a caminho', style: AppText.bodyMedium(AppColors.textPrimary)),
                    subtitle: Text('${_currentRide!['driver_name']} chegará em ~8 min',
                        style: AppText.caption(AppColors.textDim)),
                    trailing: const Icon(Icons.arrow_forward_rounded, color: AppColors.textFaint),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToRideTracking(_currentRide!);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.car_repair_rounded, color: AppColors.textDim),
                  title: Text('Mecânico confirmado', style: AppText.bodyMedium(AppColors.textPrimary)),
                  subtitle: Text('Carlos chegará em 8 minutos', style: AppText.caption(AppColors.textDim)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fechar', style: AppText.bodyMedium(AppColors.green)),
            ),
          ],
        );
      },
    );
  }

  void _showFavorites() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
    );
  }

  void _showSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações em desenvolvimento')),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Ajuda', style: AppText.h2(AppColors.textPrimary)),
          content: Text(
            'Precisa de ajuda?\n\n'
            '• Toque no botão verde para solicitar um profissional\n'
            '• Selecione o tipo de serviço necessário\n'
            '• Acompanhe em tempo real no mapa\n\n'
            'Central de Atendimento: (11) 9999-9999',
            style: AppText.body(AppColors.textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fechar', style: AppText.bodyMedium(AppColors.green)),
            ),
          ],
        );
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Sair', style: AppText.h2(AppColors.textPrimary)),
          content: Text('Tem certeza que deseja sair?', style: AppText.body(AppColors.textDim)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: AppText.bodyMedium(AppColors.textDim)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              child: Text('Sair', style: AppText.bodyMedium(AppColors.red)),
            ),
          ],
        );
      },
    );
  }
}

// TAB DA HOME
class HomeTab extends StatelessWidget {
  final bool hasActiveRide;
  final Map<String, dynamic>? currentRide;

  const HomeTab({super.key, required this.hasActiveRide, this.currentRide});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de boas-vindas com status da corrida
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasActiveRide
                    ? [AppColors.amber, const Color(0xFFE08A00)]
                    : [AppColors.green, const Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.lgBr,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hasActiveRide ? 'Corrida em Andamento' : 'Socorro Veicular',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (hasActiveRide) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.directions_car_rounded, color: Colors.white),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasActiveRide
                      ? 'Acompanhe seu profissional em tempo real'
                      : 'Assistência 24h para seu veículo',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
                if (hasActiveRide && currentRide != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: AppRadius.smBr,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${currentRide!['driver_name']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Chegando em ~8 min',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _navigateToRideTracking(context, currentRide!);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.amber,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
                          ),
                          child: const Text('Acompanhar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Serviços disponíveis
          Text('Serviços Disponíveis', style: AppText.h1(AppColors.textPrimary)),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.05,
            children: [
              _buildServiceCard(
                context,
                'Mecânico',
                Icons.build_rounded,
                AppColors.amber,
                'Problemas no motor, embreagem, etc.',
                'mecanico',
              ),
              _buildServiceCard(
                context,
                'Guincho',
                Icons.local_shipping_rounded,
                AppColors.blue,
                'Reboque para oficina',
                'guincho',
              ),
              _buildServiceCard(
                context,
                'Borracharia',
                Icons.directions_car_rounded,
                AppColors.red,
                'Troca de pneus e reparos',
                'borracharia',
              ),
              _buildServiceCard(
                context,
                'Elétrica',
                Icons.electric_bolt_rounded,
                AppColors.green,
                'Problemas elétricos e bateria',
                'eletrica',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Promoções/Notícias
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBr,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dica do Dia', style: AppText.h2(AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'Verifique a pressão dos pneus regularmente para melhor desempenho e segurança.',
                  style: AppText.body(AppColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRideTracking(BuildContext context, Map<String, dynamic> ride) {
    final pickup = ride['pickup_location'] as Map<String, dynamic>?;
    final dest = ride['destination'] as Map<String, dynamic>?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideTrackingScreen(
          rideId: ride['id'].toString(),
          pickupLocation: LatLng(
            (pickup?['latitude'] as num?)?.toDouble() ?? 0,
            (pickup?['longitude'] as num?)?.toDouble() ?? 0,
          ),
          destination: LatLng(
            (dest?['latitude'] as num?)?.toDouble() ?? 0,
            (dest?['longitude'] as num?)?.toDouble() ?? 0,
          ),
          driverName: ride['driver_name']?.toString() ?? 'Profissional',
          driverPhone: ride['driver_phone']?.toString(),
          vehicleType: pickup?['tipo_veiculo']?.toString() ?? 'leve',
        ),
      ),
    );
  }

  // TAB DA HOME - Ajuste o método _buildServiceCard
  Widget _buildServiceCard(BuildContext context, String title, IconData icon, Color color, String subtitle, String serviceType) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: AppRadius.mdBr,
        onTap: () {
          if (hasActiveRide) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Você já tem uma corrida ativa!'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          // Direto para seleção de tipo de veículo
          _showVehicleTypeSelection(context, serviceType, title);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: AppText.bodyMedium(AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppText.caption(AppColors.textDim),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Adicione este método
  void _showVehicleTypeSelection(BuildContext context, String serviceType, String serviceName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('$serviceName - Tipo de Veículo', style: AppText.h2(AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Selecione o tipo do seu veículo:', style: AppText.body(AppColors.textDim)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildVehicleTypeOption(
                    context,
                    'Leve',
                    Icons.directions_car_rounded,
                    AppColors.green,
                    serviceType,
                    serviceName,
                    'leve',
                  ),
                  _buildVehicleTypeOption(
                    context,
                    'Pesado',
                    Icons.local_shipping_rounded,
                    AppColors.amber,
                    serviceType,
                    serviceName,
                    'pesado',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehicleTypeOption(BuildContext context, String label, IconData icon, Color color, String serviceType, String serviceName, String vehicleType) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.pop(context);
            // Navega direto para o mapa com o serviço e tipo de veículo selecionado
            _navigateToMapWithService(context, serviceType, serviceName, vehicleType);
          },
          borderRadius: AppRadius.mdBr,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: AppRadius.mdBr,
              border: Border.all(color: color),
            ),
            child: Column(
              children: [
                Icon(icon, size: 36, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: AppText.bodyMedium(color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToMapWithService(BuildContext context, String serviceType, String serviceName, String vehicleType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClienteMapScreenWithService(
          selectedService: serviceType,
          serviceName: serviceName,
          vehicleType: vehicleType,
        ),
      ),
    );
  }
}
// Tela de acompanhamento da corrida em tempo real
class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  final LatLng? driverLocation;
  final LatLng pickupLocation;
  final LatLng destination;
  final String driverName;
  final String? driverPhone;
  final String vehicleType;

  const RideTrackingScreen({
    super.key,
    required this.rideId,
    this.driverLocation,
    required this.pickupLocation,
    required this.destination,
    required this.driverName,
    this.driverPhone,
    required this.vehicleType,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final WsService _wsService = WsService();
  LatLng? _currentDriverLocation;
  String _rideStatus = 'accepted';
  bool _cancelling = false;
  double? _completedPrice;

  @override
  void initState() {
    super.initState();
    _currentDriverLocation = widget.driverLocation;
    _wsService.connectToTrip(
      widget.rideId,
      onLocation: (id, pos, meta) {
        if (!mounted) return;
        setState(() => _currentDriverLocation = pos);
      },
      onStatus: (status, payload) {
        if (!mounted) return;
        setState(() => _rideStatus = status);
        if (status == 'completed') {
          setState(() => _completedPrice = (payload['final_price'] as num?)?.toDouble());
        }
      },
    );
  }


  // Cancelar a corrida (POST /api/rides/:id/cancel - real, via ClienteProvider)
  void _cancelRide() {
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
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _cancelling = true);

              final result = await context.read<ClienteProvider>().cancelarCorrida(widget.rideId);

              if (!mounted) return;
              setState(() => _cancelling = false);

              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Corrida cancelada com sucesso!'),
                    backgroundColor: AppColors.green,
                  ),
                );
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) Navigator.pop(context);
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']?.toString() ?? 'Erro ao cancelar corrida'),
                    backgroundColor: AppColors.red,
                  ),
                );
              }
            },
            child: Text('Sim', style: AppText.bodyMedium(AppColors.red)),
          ),
        ],
      ),
    );
  }

  // Abre o chat com o profissional desta corrida.
  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          rideId: widget.rideId,
          otherPartyName: widget.driverName,
          accent: AppColors.green,
        ),
      ),
    );
  }

  // Ligação real para o motorista (usa o telefone vindo do backend)
  Future<void> _makePhoneCall() async {
    final phone = widget.driverPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefone do profissional indisponível.')),
      );
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Acompanhamento da Corrida', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header com informações da corrida
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.amberDim,
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.amber,
                  child: Icon(Icons.person, color: Color(0xFF201400)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName,
                        style: AppText.bodyMedium(AppColors.textPrimary),
                      ),
                      Text(
                        _cancelling ? 'Cancelando...' : _getStatusText(_rideStatus),
                        style: AppText.caption(AppColors.textDim),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_rounded, color: AppColors.amber),
                  onPressed: _makePhoneCall,
                ),
              ],
            ),
          ),
          if (_rideStatus == 'completed' && _completedPrice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.greenDim,
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Valor combinado: R\$ ${_completedPrice!.toStringAsFixed(2)} · pago diretamente ao profissional',
                      style: AppText.bodyMedium(AppColors.green),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ClienteMapScreen(
              driverLocation: _currentDriverLocation,
              pickupLocation: widget.pickupLocation,
              destination: widget.destination,
              driverName: widget.driverName,
              rideStatus: _rideStatus,
              onCallPressed: _makePhoneCall,
              onCancelPressed: _cancelRide,
              onMessagePressed: _openChat,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Profissional a caminho';
      case 'in_progress':
        return 'Em andamento';
      case 'completed':
        return 'Corrida finalizada';
      case 'cancelled':
        return 'Corrida cancelada';
      default:
        return 'Aguardando';
    }
  }
}

// TAB DE HISTÓRICO
class HistoricoTab extends StatelessWidget {
  const HistoricoTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Histórico de Serviços', style: AppText.h1(AppColors.textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildHistoryItem(
                  'Mecânico - Carlos',
                  '15 Nov 2024',
                  'R\$ 120,00',
                  Icons.check_circle_rounded,
                  AppColors.green,
                ),
                _buildHistoryItem(
                  'Guincho - Maria',
                  '10 Nov 2024',
                  'R\$ 80,00',
                  Icons.check_circle_rounded,
                  AppColors.green,
                ),
                _buildHistoryItem(
                  'Borracharia - João',
                  '05 Nov 2024',
                  'R\$ 60,00',
                  Icons.check_circle_rounded,
                  AppColors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String title, String date, String price, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: AppText.bodyMedium(AppColors.textPrimary)),
        subtitle: Text(date, style: AppText.caption(AppColors.textDim)),
        trailing: Text(
          price,
          style: AppText.bodyMedium(AppColors.textPrimary),
        ),
      ),
    );
  }
}

// TAB DE PERFIL
class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ClienteProvider>(context);
    final name = provider.userName ?? 'Cliente';
    final email = provider.userEmail ?? '—';
    final phone = provider.userPhone;
    final endereco = provider.enderecoCompleto;
    final cidadeEstado = [provider.enderecoCidade, provider.enderecoEstado]
        .where((e) => e != null && e.isNotEmpty)
        .join(' - ');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: RefreshIndicator(
        onRefresh: provider.carregarPerfil,
        child: ListView(
          children: [
          Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.green,
                backgroundImage: provider.fotoUrl != null ? NetworkImage(provider.fotoUrl!) : null,
                child: provider.fotoUrl == null
                    ? Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF06120A)),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(name, style: AppText.h1(AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(email, style: AppText.body(AppColors.textDim)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBr,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_rounded, color: AppColors.textDim),
                  title: Text('Telefone', style: AppText.bodyMedium(AppColors.textPrimary)),
                  subtitle: Text(
                    phone?.isNotEmpty == true ? phone! : 'Não informado',
                    style: AppText.caption(AppColors.textDim),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppColors.textFaint),
                    onPressed: () {},
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_rounded, color: AppColors.textDim),
                  title: Text('Endereço', style: AppText.bodyMedium(AppColors.textPrimary)),
                  subtitle: Text(
                    endereco?.isNotEmpty == true
                        ? '$endereco${cidadeEstado.isNotEmpty ? ' - $cidadeEstado' : ''}'
                        : 'Nenhum endereço cadastrado',
                    style: AppText.caption(AppColors.textDim),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppColors.textFaint),
                    onPressed: () {},
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.textDim),
                  title: Text('Carteira', style: AppText.bodyMedium(AppColors.textPrimary)),
                  subtitle: Text('Saldo, extrato e recarga', style: AppText.caption(AppColors.textDim)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text('Segurança', style: AppText.caption(AppColors.textDim)),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdBr,
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: Icon(
                provider.twoFactorEnabled ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: provider.twoFactorEnabled ? AppColors.green : AppColors.textDim,
              ),
              title: Text('Verificação em duas etapas', style: AppText.bodyMedium(AppColors.textPrimary)),
              subtitle: Text(
                provider.twoFactorEnabled ? 'Ativada' : 'Desativada',
                style: AppText.caption(provider.twoFactorEnabled ? AppColors.green : AppColors.textDim),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TwoFactorSettingsScreen(
                      initiallyEnabled: provider.twoFactorEnabled,
                      onSetup: provider.iniciarConfiguracao2FA,
                      onEnable: provider.ativar2FA,
                      onDisable: provider.desativar2FA,
                      accent: AppColors.green,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}
