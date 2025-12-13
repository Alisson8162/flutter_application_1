// Adicione no topo:
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../profissional/profissional_service.dart';
import '../profissional/profissional_provider.dart';

class GanhosPage extends StatefulWidget {
  const GanhosPage({super.key});

  @override
  State<GanhosPage> createState() => _GanhosPageState();
}

class _GanhosPageState extends State<GanhosPage> {
  Map<String, dynamic> _earningsData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      final data = await ProfissionalService.getEarnings();
      setState(() {
        _earningsData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar ganhos: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfissionalProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }

    final weeklyTotal = _earningsData['weekly_total'] ?? 0;
    final weeklyRides = _earningsData['weekly_rides'] ?? 0;
    final weeklyTips = _earningsData['weekly_tips'] ?? 0;
    final dailyEarnings = _earningsData['daily_earnings'] ?? List.filled(7, 0);
    final rideHistory = _earningsData['ride_history'] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Ganhos e Relatórios"),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Resumo Semanal",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // Cards de resumo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ResumoCard(label: "Total", value: "R\$ ${weeklyTotal.toStringAsFixed(2)}"),
                _ResumoCard(label: "Corridas", value: weeklyRides.toString()),
                _ResumoCard(label: "Gorjetas", value: "R\$ ${weeklyTips.toStringAsFixed(2)}"),
              ],
            ),
            const SizedBox(height: 30),

            const Text("Ganhos Diários",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 15),

            // Gráfico de ganhos
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  backgroundColor: Colors.transparent,
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const dias = ["S", "T", "Q", "Q", "S", "S", "D"];
                          return Text(
                            dias[value.toInt() % 7],
                            style: const TextStyle(color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < 7; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (dailyEarnings[i] ?? 0).toDouble(),
                            color: Colors.greenAccent,
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          )
                        ],
                      ),
                  ],
                ),
              )
            ),

                
            const SizedBox(height: 30),

            const Text("Histórico de Corridas",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            for (int i = 0; i < rideHistory.length; i++)
              _RideHistoryItem(ride: rideHistory[i]),
          ],
        ),
      ),
    );
  }
}

class _RideHistoryItem extends StatelessWidget {
  final Map<String, dynamic> ride;

  const _RideHistoryItem({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.local_taxi, color: Colors.greenAccent),
        title: Text("Corrida #${ride['id']}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: Text("${ride['pickup_address']} - ${ride['destination_address']}",
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        trailing: Text("R\$ ${ride['price']?.toStringAsFixed(2) ?? '0.00'}", 
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final String label;
  final String value;
  const _ResumoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}