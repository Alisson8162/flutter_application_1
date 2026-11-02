import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'pix_payment_screen.dart';

/// Exibida quando uma corrida é marcada como concluída e ainda não foi paga
/// (a cobrança automática no cartão padrão - feita pelo backend assim que a
/// corrida termina - falhou ou o cliente não tem cartão salvo). Deixa o
/// cliente escolher entre cartão, PIX ou saldo da carteira.
///
/// Retorna `true` via Navigator.pop quando o pagamento é confirmado, ou
/// `false`/`null` se o cliente fechar a tela sem pagar (nesse caso quem
/// chamou deve continuar oferecendo a opção de pagar mais tarde).
class PaymentMethodPickerScreen extends StatefulWidget {
  final String rideId;
  final double amount;

  const PaymentMethodPickerScreen({super.key, required this.rideId, required this.amount});

  @override
  State<PaymentMethodPickerScreen> createState() => _PaymentMethodPickerScreenState();
}

class _PaymentMethodPickerScreenState extends State<PaymentMethodPickerScreen> {
  bool _loadingBalance = true;
  double _walletBalance = 0;
  bool _chargingCard = false;
  String? _cardError;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    final result = await ApiService.get('/wallet');
    if (!mounted) return;
    setState(() {
      if (result['success'] == true) {
        _walletBalance = ((result['data']?['balance'] as num?) ?? 0).toDouble();
      }
      _loadingBalance = false;
    });
  }

  Future<void> _payWithCard() async {
    setState(() {
      _chargingCard = true;
      _cardError = null;
    });

    final result = await ApiService.post('/payments/rides/${widget.rideId}/charge', {});

    if (!mounted) return;
    setState(() => _chargingCard = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => _cardError = result['message']?.toString() ?? 'Não foi possível cobrar o cartão salvo.');
    }
  }

  Future<void> _payWithPix() async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PixPaymentScreen(rideId: widget.rideId, amount: widget.amount),
      ),
    );
    if (!mounted) return;
    if (paid == true) Navigator.pop(context, true);
  }

  Future<void> _payWithWallet() async {
    if (_walletBalance < widget.amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo insuficiente na carteira.')),
      );
      return;
    }

    final result = await ApiService.post('/payments/rides/${widget.rideId}/charge-wallet', {});
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Não foi possível pagar com a carteira.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Como você quer pagar?', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdBr,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text('Corrida concluída', style: AppText.body(AppColors.textDim)),
                  const SizedBox(height: 6),
                  Text('R\$ ${widget.amount.toStringAsFixed(2)}', style: AppText.display(AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 26),

            _buildOption(
              icon: Icons.credit_card_rounded,
              title: 'Cartão salvo',
              subtitle: _cardError ?? 'Cobrar no cartão cadastrado como padrão',
              subtitleColor: _cardError != null ? AppColors.red : null,
              loading: _chargingCard,
              onTap: _chargingCard ? null : _payWithCard,
            ),
            const SizedBox(height: 12),
            _buildOption(
              icon: Icons.qr_code_rounded,
              title: 'PIX',
              subtitle: 'Pagar com QR code ou copia e cola',
              onTap: _payWithPix,
            ),
            const SizedBox(height: 12),
            _buildOption(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Carteira',
              subtitle: _loadingBalance ? 'Consultando saldo…' : 'Saldo disponível: R\$ ${_walletBalance.toStringAsFixed(2)}',
              onTap: _loadingBalance ? null : _payWithWallet,
            ),

            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Pagar mais tarde', style: AppText.bodyMedium(AppColors.textFaint)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    bool loading = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdBr,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.greenDim, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyMedium(AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.caption(subtitleColor ?? AppColors.textDim)),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
