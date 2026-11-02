import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  final TextEditingController _amountCtrl = TextEditingController();
  bool _addingFunds = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get('/wallet');
    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      setState(() {
        _balance = (data['balance'] as num).toDouble();
        _transactions = (data['transactions'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _showAddFundsSheet() {
    _amountCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Adicionar saldo', style: AppText.h2(AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                'Cobrado no cartão salvo como padrão em Métodos de pagamento.',
                style: AppText.caption(AppColors.textDim),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _amountCtrl,
                hint: 'Valor (ex: 50.00)',
                leading: Icons.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: 'Confirmar recarga',
                loading: _addingFunds,
                color: AppColors.green,
                onPressed: () async {
                  final value = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
                  if (value == null || value <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Informe um valor válido.')),
                    );
                    return;
                  }

                  setSheetState(() => _addingFunds = true);
                  final result = await ApiService.post('/wallet/add-funds', {'amount': value});
                  setSheetState(() => _addingFunds = false);

                  if (!mounted) return;
                  Navigator.pop(ctx);

                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saldo adicionado com sucesso!'), backgroundColor: AppColors.green),
                    );
                    _load();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message']?.toString() ?? 'Não foi possível adicionar saldo.')),
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Carteira', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.green,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.green, Color(0xFF16A34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppRadius.lgBr,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saldo disponível', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text(
                          'R\$ ${_balance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showAddFundsSheet,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Adicionar saldo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.green,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Extrato', style: AppText.h2(AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('Nenhuma movimentação ainda', style: AppText.body(AppColors.textDim)),
                      ),
                    )
                  else
                    ..._transactions.map(_buildTransactionTile),
                ],
              ),
            ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final isCredit = tx['type'] == 'credit';
    final amount = (tx['amount'] as num).toDouble();
    final description = tx['description']?.toString() ?? (isCredit ? 'Crédito' : 'Débito');
    final createdAt = DateTime.tryParse(tx['created_at']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isCredit ? AppColors.green : AppColors.red).withOpacity(0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isCredit ? AppColors.green : AppColors.red,
            size: 18,
          ),
        ),
        title: Text(description, style: AppText.bodyMedium(AppColors.textPrimary)),
        subtitle: createdAt != null
            ? Text(
                '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                style: AppText.caption(AppColors.textDim),
              )
            : null,
        trailing: Text(
          '${isCredit ? '+' : '-'} R\$ ${amount.toStringAsFixed(2)}',
          style: AppText.bodyMedium(isCredit ? AppColors.green : AppColors.red),
        ),
      ),
    );
  }
}
