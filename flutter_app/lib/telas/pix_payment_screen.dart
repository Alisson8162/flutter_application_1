import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Tela de pagamento via PIX de uma corrida já concluída.
///
/// Recebe o `rideId` (o id da corrida no backend - tabela `rides` do
/// Postgres, POST /api/payments/rides/:id/charge-pix) e:
///  1. Gera a cobrança e mostra o QR code + código "copia e cola";
///  2. Faz polling em GET /api/payments/rides/:id/status a cada alguns
///     segundos aguardando a confirmação (o pagamento PIX é assíncrono -
///     não confirma na hora como o cartão);
///  3. Mostra a tela de sucesso assim que `payment_status` vira "paid".
class PixPaymentScreen extends StatefulWidget {
  final String rideId;
  final double amount;

  const PixPaymentScreen({super.key, required this.rideId, required this.amount});

  @override
  State<PixPaymentScreen> createState() => _PixPaymentScreenState();
}

enum _PixState { loading, ready, paid, error }

class _PixPaymentScreenState extends State<PixPaymentScreen> {
  _PixState state = _PixState.loading;
  String? qrCodeText;
  String? qrCodeImageUrl;
  String? errorMessage;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _generateCharge();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateCharge() async {
    setState(() {
      state = _PixState.loading;
      errorMessage = null;
    });

    final result = await ApiService.post('/payments/rides/${widget.rideId}/charge-pix', {});

    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      setState(() {
        qrCodeText = data['qrCodeText'] as String?;
        qrCodeImageUrl = data['qrCodeImageUrl'] as String?;
        state = _PixState.ready;
      });
      _startPolling();
    } else {
      setState(() {
        state = _PixState.error;
        errorMessage = result['message']?.toString() ?? 'Não foi possível gerar a cobrança PIX.';
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final result = await ApiService.get('/payments/rides/${widget.rideId}/status');
    if (!mounted) return;

    if (result['success'] == true) {
      final status = (result['data']?['payment_status'] as String?) ?? '';
      if (status == 'paid') {
        _pollTimer?.cancel();
        setState(() => state = _PixState.paid);
      }
    }
  }

  void _copyCode() {
    if (qrCodeText == null) return;
    Clipboard.setData(ClipboardData(text: qrCodeText!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código PIX copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Pagamento via PIX', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (state) {
      case _PixState.loading:
        return const Center(child: CircularProgressIndicator(color: AppColors.green));

      case _PixState.error:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 44),
            const SizedBox(height: 14),
            Text(
              errorMessage ?? 'Erro ao gerar cobrança',
              style: AppText.body(AppColors.textDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(label: 'Tentar novamente', onPressed: _generateCharge, color: AppColors.green),
          ],
        );

      case _PixState.paid:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: AppColors.greenDim, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.green, size: 48),
            ),
            const SizedBox(height: 18),
            Text('Pagamento confirmado!', style: AppText.h1(AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'R\$ ${widget.amount.toStringAsFixed(2)} recebidos via PIX.',
              style: AppText.body(AppColors.textDim),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Concluir',
              onPressed: () => Navigator.pop(context, true),
              color: AppColors.green,
            ),
          ],
        );

      case _PixState.ready:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'R\$ ${widget.amount.toStringAsFixed(2)}',
                style: AppText.display(AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Escaneie o QR code com o app do seu banco',
                style: AppText.body(AppColors.textDim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              if (qrCodeImageUrl != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.mdBr,
                  ),
                  child: Image.network(qrCodeImageUrl!, fit: BoxFit.contain),
                ),
              const SizedBox(height: 20),
              Text('Ou use o código copia e cola', style: AppText.caption(AppColors.textDim)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.smBr,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  qrCodeText ?? '',
                  style: AppText.caption(AppColors.textDim).copyWith(fontFamily: 'monospace'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 14),
              AppOutlinedButton(label: 'Copiar código', onPressed: _copyCode),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textFaint),
                  ),
                  const SizedBox(width: 10),
                  Text('Aguardando confirmação do pagamento...', style: AppText.caption(AppColors.textFaint)),
                ],
              ),
            ],
          ),
        );
    }
  }
}
