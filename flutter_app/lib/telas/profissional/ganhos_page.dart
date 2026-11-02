// Adicione no topo:
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../profissional/profissional_service.dart';
import '../../providers/profissional_provider.dart';
import '../../theme/app_theme.dart';

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
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }

    final weeklyTotal = _earningsData['weekly_total'] ?? 0;
    final weeklyRides = _earningsData['weekly_rides'] ?? 0;
    final weeklyTips = _earningsData['weekly_tips'] ?? 0;
    final dailyEarnings = _earningsData['daily_earnings'] ?? List.filled(7, 0);
    final rideHistory = _earningsData['ride_history'] ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text("Ganhos e Relatórios", style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Resumo Semanal", style: AppText.h1(AppColors.textPrimary)),
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

            Text("Ganhos Diários", style: AppText.h2(AppColors.textPrimary)),
            const SizedBox(height: 15),

            // Gráfico de ganhos
            Container(
              height: 250,
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdBr,
                border: Border.all(color: AppColors.border),
              ),
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
                            style: const TextStyle(color: AppColors.textFaint),
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
                            color: AppColors.amber,
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          )
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            Text("Histórico de Corridas", style: AppText.h2(AppColors.textPrimary)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: const Icon(Icons.local_taxi_rounded, color: AppColors.amber),
        title: Text("Corrida #${ride['id']}", style: AppText.bodyMedium(AppColors.textPrimary)),
        subtitle: Text("${ride['pickup_address']} - ${ride['destination_address']}",
            style: AppText.caption(AppColors.textDim)),
        trailing: Text("R\$ ${ride['price']?.toStringAsFixed(2) ?? '0.00'}",
            style: AppText.bodyMedium(AppColors.textPrimary)),
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: AppText.h2(AppColors.amber)),
          const SizedBox(height: 5),
          Text(label, style: AppText.caption(AppColors.textDim)),
        ],
      ),
    );
  }
}