// lib/telas/cliente_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../telas/map_service.dart';
import '../telas/clientemap_screen.dart';
import '../telas/reportar_problema.dart';
import '../telas/central_ajuda.dart';
import 'clienteselection_sheet.dart';
import 'clienteride_flow.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class ClienteHome extends StatefulWidget {
  const ClienteHome({super.key});

  @override
  State<ClienteHome> createState() => _ClienteHomeState();
}

class _ClienteHomeState extends State<ClienteHome> {
  int _selectedIndex = 0;
  late FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _rideSubscription;
  bool _hasActiveRide = false;
  Map<String, dynamic>? _currentRide;

  @override
  void initState() {
    super.initState();
    _initializeFirebase(); // ✅ Inicializa Firebase primeiro
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    _listenForActiveRides(); // ✅ Só escuta corridas DEPOIS do Firebase estar pronto
  }

  void _listenForActiveRides() {
    // Escuta por corridas ativas do usuário
    _rideSubscription = _firestore
      .collection('ride_requests')
      .where('clientId', isEqualTo: 'cliente_123')
      .where('status', whereIn: ['accepted', 'in_progress'])
      .snapshots()
      .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final ride = snapshot.docs.first;
          setState(() {
            _hasActiveRide = true;
            _currentRide = ride.data();
          });
          _showActiveRideNotification(_currentRide!);
        } else {
          setState(() {
            _hasActiveRide = false;
            _currentRide = null;
          });
        }
      });
  }

  void _showActiveRideNotification(Map<String, dynamic> ride) {
    final driverName = ride['driverName'] ?? 'Motorista';
    final status = ride['status'];

    if (status == 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $driverName aceitou sua corrida!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Acompanhar',
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
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Ver rota',
            onPressed: () {
              _navigateToRideTracking(ride);
            },
          ),
        ),
      );
    }
  }

  void _navigateToRideTracking(Map<String, dynamic> ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideTrackingScreen(
          rideId: ride['id'],
          driverLocation: LatLng(
            ride['driverLocation']['latitude'],
            ride['driverLocation']['longitude'],
          ),
          pickupLocation: LatLng(
            ride['pickupLocation']['latitude'],
            ride['pickupLocation']['longitude'],
          ),
          destination: LatLng(
            ride['destination']['latitude'],
            ride['destination']['longitude'],
          ),
          driverName: ride['driverName'],
          vehicleType: ride['vehicleType'],
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
    _rideSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fala Comigo'),
        backgroundColor: Colors.green,
        actions: [
          // Badge para notificações de corrida
          if (_hasActiveRide)
            Badge(
              backgroundColor: Colors.red,
              label: const Text('1', style: TextStyle(color: Colors.white)),
              child: IconButton(
                icon: const Icon(Icons.directions_car),
                onPressed: () {
                  if (_currentRide != null) {
                    _navigateToRideTracking(_currentRide!);
                  }
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              _showNotifications();
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelp();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _widgetOptions.elementAt(_selectedIndex),
      floatingActionButton: _selectedIndex == 0 ? _buildEmergencyButton() : null,
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.history),
                if (_hasActiveRide)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Histórico',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.green),
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
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                if (_hasActiveRide) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
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
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Pagamentos'),
            onTap: () {
              _showPaymentMethods();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Favoritos'),
            onTap: () {
              _showFavorites();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () {
              _showSettings();
              Navigator.pop(context);
            },
          ),
          const Divider(),
          if (_hasActiveRide)
            ListTile(
              leading: const Icon(Icons.directions_car, color: Colors.green),
              title: const Text('Corrida Ativa'),
              subtitle: const Text('Acompanhe seu profissional'),
              onTap: () {
                Navigator.pop(context);
                if (_currentRide != null) {
                  _navigateToRideTracking(_currentRide!);
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.indigoAccent),
            title: const Text("Central de Ajuda"),
            onTap: () {
              Navigator.pushNamed(context, '/ajuda');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Ajuda'),
            onTap: () {
              _showHelp();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () {
              _logout();
            },
          ),
        ],
      ),
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
      backgroundColor: _hasActiveRide ? Colors.orange : Colors.green,
      child: Icon(
        _hasActiveRide ? Icons.directions_car : Icons.directions_car,
        color: Colors.white,
      ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notificações'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                if (_hasActiveRide && _currentRide != null)
                  ListTile(
                    leading: const Icon(Icons.car_repair, color: Colors.green),
                    title: const Text('Profissional a caminho'),
                    subtitle: Text('${_currentRide!['driverName']} chegará em ~8 min'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToRideTracking(_currentRide!);
                    },
                  ),
                const ListTile(
                  leading: Icon(Icons.car_repair),
                  title: Text('Mecânico confirmado'),
                  subtitle: Text('Carlos chegará em 8 minutos'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentMethods() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Métodos de Pagamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Cartão Crédito'),
                subtitle: const Text('**** 1234'),
                trailing: const Icon(Icons.check, color: Colors.green),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Adicionar cartão'),
                onTap: () {},
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
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
          title: const Text('Ajuda'),
          content: const Text(
            'Precisa de ajuda?\n\n'
            '• Toque no botão verde para solicitar um profissional\n'
            '• Selecione o tipo de serviço necessário\n'
            '• Acompanhe em tempo real no mapa\n\n'
            'Central de Atendimento: (11) 9999-9999',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
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
          title: const Text('Sair'),
          content: const Text('Tem certeza que deseja sair?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              child: const Text('Sair'),
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
      padding: const EdgeInsets.all(16),
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
                    ? [Colors.orange, Colors.orangeAccent]
                    : [Colors.green, Colors.lightGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
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
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasActiveRide) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.directions_car, color: Colors.white),
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
                    fontSize: 16,
                  ),
                ),
                if (hasActiveRide && currentRide != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${currentRide!['driverName']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Chegando em ~8 min',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
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
                            foregroundColor: Colors.orange,
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

          const SizedBox(height: 24),

          // Serviços disponíveis
          const Text(
            'Serviços Disponíveis',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildServiceCard(
                context,
                'Mecânico',
                Icons.build,
                Colors.orange,
                'Problemas no motor, embreagem, etc.',
                'mecanico',
              ),
              _buildServiceCard(
                context,
                'Guincho',
                Icons.local_shipping,
                Colors.blue,
                'Reboque para oficina',
                'guincho',
              ),
              _buildServiceCard(
                context,
                'Borracharia',
                Icons.directions_car,
                Colors.red,
                'Troca de pneus e reparos',
                'borracharia',
              ),
              _buildServiceCard(
                context,
                'Elétrica',
                Icons.electric_bolt,
                Colors.yellow,
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
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dica do Dia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifique a pressão dos pneus regularmente para melhor desempenho e segurança.',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRideTracking(BuildContext context, Map<String, dynamic> ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideTrackingScreen(
          rideId: ride['id'],
          driverLocation: LatLng(
            ride['driverLocation']['latitude'],
            ride['driverLocation']['longitude'],
          ),
          pickupLocation: LatLng(
            ride['pickupLocation']['latitude'],
            ride['pickupLocation']['longitude'],
          ),
          destination: LatLng(
            ride['destination']['latitude'],
            ride['destination']['longitude'],
          ),
          driverName: ride['driverName'],
          vehicleType: ride['vehicleType'],
        ),
      ),
    );
  }

 // TAB DA HOME - Ajuste o método _buildServiceCard
  Widget _buildServiceCard(BuildContext context, String title, IconData icon, Color color, String subtitle, String serviceType) {
    return Card(
      elevation: 4,
      child: InkWell(
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
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
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
          title: Text('$serviceName - Tipo de Veículo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecione o tipo do seu veículo:'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildVehicleTypeOption(
                    context,
                    'Leve',
                    Icons.directions_car,
                    Colors.green,
                    serviceType,
                    serviceName,
                    'leve',
                  ),
                  _buildVehicleTypeOption(
                    context,
                    'Pesado',
                    Icons.local_shipping,
                    Colors.orange,
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
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Column(
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
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
  final LatLng driverLocation;
  final LatLng pickupLocation;
  final LatLng destination;
  final String driverName;
  final String vehicleType;

  const RideTrackingScreen({
    super.key,
    required this.rideId,
    required this.driverLocation,
    required this.pickupLocation,
    required this.destination,
    required this.driverName,
    required this.vehicleType,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  late FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;
  LatLng? _currentDriverLocation;
  String _rideStatus = 'accepted';

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _listenForDriverLocation();
    _listenForRideUpdates();
  }

  Future<void> _initializeFirebase() async {
    _firestore = FirebaseFirestore.instance;
    _currentDriverLocation = widget.driverLocation;
  }

  void _listenForDriverLocation() {
    _driverLocationSubscription = _firestore
        .collection('drivers')
        .doc('driver_123') // ID do motorista da corrida
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['position'] != null) {
          setState(() {
            _currentDriverLocation = LatLng(
              data['position']['latitude'],
              data['position']['longitude'],
            );
          });
        }
      }
    });
  }

  void _listenForRideUpdates() {
    _firestore
        .collection('ride_requests')
        .doc(widget.rideId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _rideStatus = data['status'] ?? 'accepted';
        });
      }
    });
  }

  // Método para cancelar a corrida
  void _cancelRide() {
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
            onPressed: () async {
              try {
                // Atualiza o status da corrida para 'cancelled' no Firestore
                await _firestore
                    .collection('ride_requests')
                    .doc(widget.rideId)
                    .update({
                  'status': 'cancelled',
                  'cancelledAt': FieldValue.serverTimestamp(),
                });
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Corrida cancelada com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Volta para a tela anterior após 2 segundos
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    Navigator.pop(context);
                  }
                });
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao cancelar corrida: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Sim', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Método para abrir o chat com o motorista
  void _openChat() {
    // Navega para a tela de chat (você precisará criar esta tela)
    // Por enquanto, vamos mostrar um SnackBar informativo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidade de chat em desenvolvimento...'),
        backgroundColor: Colors.blue,
      ),
    );
    
    // Para implementar o chat, você pode criar uma nova tela:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => ChatScreen(
    //       rideId: widget.rideId,
    //       driverId: 'driver_123',
    //       driverName: widget.driverName,
    //     ),
    //   ),
    // );
  }

  // Método para fazer chamada telefônica
  void _makePhoneCall() {
    // Abre o discador com o número do motorista
    // Você precisará ter o número do motorista no Firestore
    const phoneNumber = '11999999999'; // Exemplo
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Discando para ${widget.driverName}...'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Para implementar ligação real, use o pacote url_launcher:
    // final url = 'tel:$phoneNumber';
    // if (await canLaunch(url)) {
    //   await launch(url);
    // } else {
    //   throw 'Não foi possível discar $url';
    // }
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acompanhamento da Corrida'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // Header com informações da corrida
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _getStatusText(_rideStatus),
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone),
                  onPressed: _makePhoneCall,
                ),
              ],
            ),
          ),
          Expanded(
            child: ClienteMapScreen(
              driverLocation: _currentDriverLocation ?? widget.driverLocation,
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

// ... (restante do código permanece igual - ClienteMapScreenWithService, HistoricoTab, PerfilTab)

// Tela do mapa com serviço selecionado
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.serviceName} - ${_getVehicleTypeText(widget.vehicleType)}'),
        backgroundColor: _getServiceColor(widget.selectedService),
      ),
      body: const ClienteMapScreen(), // Usa a tela de mapa existente
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: _getServiceColor(widget.selectedService).withOpacity(0.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.serviceName} para veículo ${_getVehicleTypeText(widget.vehicleType).toLowerCase()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getServiceDescription(widget.selectedService, widget.vehicleType),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Abre a selection sheet para confirmar o serviço
                _openSelectionSheet(widget.selectedService, widget.vehicleType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getServiceColor(widget.selectedService),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text('Solicitar ${widget.serviceName}'),
            ),
          ],
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
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }

  String _getVehicleTypeText(String vehicleType) {
    return vehicleType == 'leve' ? 'Leve' : 'Pesado';
  }

  String _getServiceDescription(String serviceType, String vehicleType) {
    String vehicleText = vehicleType == 'leve' ? 'carros, motos' : 'caminhões, ônibus';
    
    switch (serviceType) {
      case 'mecanico':
        return 'Mecânico especializado em veículos $vehicleText';
      case 'guincho':
        return 'Guincho adequado para veículos $vehicleText';
      case 'borracharia':
        return 'Serviço de borracharia para $vehicleText';
      case 'eletrica':
        return 'Especialista em elétrica para $vehicleText';
      default:
        return 'Serviço para $vehicleText';
    }
  }

  void _openSelectionSheet(String serviceType, String vehicleType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SelectionSheet(
        onRequest: (tipo, estimativa) async {
          Navigator.pop(ctx); // fecha sheet
          // Obter a localização atual do usuário
          final userLocation = await _getCurrentUserLocation();
          
          // Navega para a tela de confirmação do pedido com valores padrão
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => RideFlowScreen(
                origin: userLocation ?? const LatLng(-23.55052, -46.633308),
                destination: const LatLng(-23.551, -46.632), // Posição exemplo
                professionalType: serviceType,
                // Adicionando os parâmetros faltantes com valores padrão
                professionalName: _getDefaultProfessionalName(serviceType, vehicleType),
                vehicleType: vehicleType,
                estimatedPrice: _getEstimatedPrice(serviceType, vehicleType),
                estimatedTime: _getEstimatedTime(serviceType, vehicleType),
              ),
            ),
          );
        },
      ),
    );
  }

  // Método auxiliar para obter localização atual
  Future<LatLng?> _getCurrentUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print("Erro ao obter localização: $e");
      return null;
    }
  }

  // Método auxiliar para nome padrão do profissional
  String _getDefaultProfessionalName(String serviceType, String vehicleType) {
    if (serviceType == 'mecanico') {
      return vehicleType == 'leve' ? 'Mecânico João' : 'Mecânico Pesado Silva';
    } else if (serviceType == 'guincho') {
      return 'Guincho Maria';
    } else if (serviceType == 'borracharia') {
      return 'Borracharia Carlos';
    } else if (serviceType == 'eletrica') {
      return 'Eletricista Ana';
    }
    return 'Profissional';
  }

  // Método auxiliar para preço estimado
  double _getEstimatedPrice(String serviceType, String vehicleType) {
    if (serviceType == 'mecanico') {
      return vehicleType == 'leve' ? 80.0 : 150.0;
    } else if (serviceType == 'guincho') {
      return vehicleType == 'leve' ? 120.0 : 250.0;
    } else if (serviceType == 'borracharia') {
      return vehicleType == 'leve' ? 60.0 : 120.0;
    } else if (serviceType == 'eletrica') {
      return vehicleType == 'leve' ? 70.0 : 140.0;
    }
    return 50.0;
  }

  // Método auxiliar para tempo estimado
  String _getEstimatedTime(String serviceType, String vehicleType) {
    if (serviceType == 'guincho') {
      return vehicleType == 'leve' ? '15-25 min' : '25-40 min';
    } else {
      return vehicleType == 'leve' ? '8-15 min' : '15-30 min';
    }
  }
}
// TAB DE HISTÓRICO
class HistoricoTab extends StatelessWidget {
  const HistoricoTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Histórico de Serviços',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildHistoryItem(
                  'Mecânico - Carlos',
                  '15 Nov 2024',
                  'R\$ 120,00',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildHistoryItem(
                  'Guincho - Maria',
                  '10 Nov 2024',
                  'R\$ 80,00',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildHistoryItem(
                  'Borracharia - João',
                  '05 Nov 2024',
                  'R\$ 60,00',
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String title, String date, String price, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(date),
        trailing: Text(
          price,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.green,
            child: Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'João Silva',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'joao.silva@email.com',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Telefone'),
                  subtitle: const Text('(11) 99999-9999'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {},
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Endereço'),
                  subtitle: const Text('Rua Exemplo, 123 - São Paulo, SP'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {},
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text('Pagamento'),
                  subtitle: const Text('Cartão Crédito **** 1234'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}