import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'profissional_main.dart';

/// Tela de assinatura mensal do profissional.
///
/// NOVO MODELO DE NEGÓCIO: o cliente não paga mais pelo app - quem paga é o
/// profissional, através desta mensalidade, que é o que mantém a conta
/// ativa (`professionals.conta_ativa`). Sem assinatura em dia, o
/// profissional não consegue ficar online (ver ProfissionalHome).
///
/// Usa o mesmo padrão de PaymentMethodsScreen: o cartão é coletado
/// DIRETAMENTE pelo SDK da Stripe (CardFormField) - o número do cartão
/// nunca passa pelo nosso backend.
class SubscriptionScreen extends StatefulWidget {
  // Quando aberta logo após o cadastro, mostra um botão "Continuar sem
  // assinar agora" que leva para a tela principal do profissional (ele
  // ainda não fica online sem assinatura, mas não fica preso nesta tela).
  final bool fromRegistration;

  const SubscriptionScreen({super.key, this.fromRegistration = false});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _contaAtiva = false;
  bool _documentacaoAprovada = false;
  String _subscriptionStatus = 'inactive';
  String? _currentPeriodEnd;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    final result = await ApiService.get('/professionals/subscription/status');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        _contaAtiva = data['conta_ativa'] == true;
        _documentacaoAprovada = data['documentacao_aprovada'] == true;
        _subscriptionStatus = data['subscription_status']?.toString() ?? 'inactive';
        _currentPeriodEnd = data['current_period_end']?.toString();
      } else {
        _error = result['message']?.toString();
      }
    });
  }

  Future<void> _assinar() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final setupResult = await ApiService.post('/professionals/subscription/setup-intent', {});
    if (setupResult['success'] != true) {
      setState(() {
        _saving = false;
        _error = setupResult['message']?.toString() ?? 'Não foi possível iniciar a assinatura';
      });
      return;
    }

    final clientSecret = setupResult['data']['client_secret'] as String;

    try {
      final setupIntent = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: clientSecret,
        params: const PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
      );

      final paymentMethodId = setupIntent.paymentMethodId;
      if (paymentMethodId == null) {
        throw Exception('A Stripe não retornou o ID do método de pagamento');
      }

      final confirmResult = await ApiService.post('/professionals/subscription/confirm', {
        'payment_method_id': paymentMethodId,
      });

      if (!mounted) return;

      if (confirmResult['success'] == true) {
        await _loadStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(confirmResult['message']?.toString() ?? 'Assinatura confirmada!')),
        );
      } else {
        setState(() => _error = confirmResult['message']?.toString());
      }
    } on StripeException catch (e) {
      setState(() => _error = e.error.localizedMessage ?? 'Erro ao processar o cartão');
    } catch (e) {
      setState(() => _error = 'Erro ao processar o cartão: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _continuarSemAssinar() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ProfissionalMain()),
      (r) => false,
    );
  }

  Future<void> _cancelar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Cancelar assinatura', style: AppText.h2(AppColors.textPrimary)),
        content: Text(
          'Você continua ativo até o fim do período já pago. Depois disso, sua conta é desativada até você assinar de novo.',
          style: AppText.body(AppColors.textDim),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Voltar', style: AppText.bodyMedium(AppColors.textDim))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Cancelar assinatura', style: AppText.bodyMedium(AppColors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await ApiService.post('/professionals/subscription/cancel', {});
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Cancelado')));
      _loadStatus();
    }
  }

  Color get _statusColor {
    switch (_subscriptionStatus) {
      case 'active':
        return AppColors.green;
      case 'past_due':
        return AppColors.amber;
      default:
        return AppColors.red;
    }
  }

  String get _statusLabel {
    switch (_subscriptionStatus) {
      case 'active':
        return 'Mensalidade em dia';
      case 'past_due':
        return 'Pagamento atrasado';
      case 'canceled':
        return 'Assinatura cancelada';
      default:
        return 'Sem assinatura ativa';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Assinatura', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.fromRegistration,
        leading: widget.fromRegistration
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                onPressed: _continuarSemAssinar,
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : RefreshIndicator(
              onRefresh: _loadStatus,
              color: AppColors.green,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdBr,
                      border: Border.all(color: _statusColor.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(_statusLabel, style: AppText.bodyMedium(AppColors.textPrimary)),
                          ],
                        ),
                        if (_currentPeriodEnd != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Válida até ${_currentPeriodEnd!.split("T").first}',
                            style: AppText.caption(AppColors.textDim),
                          ),
                        ],
                        if (!_documentacaoAprovada) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Sua documentação ainda está em análise - mesmo com a assinatura ativa, '
                            'você só fica visível para clientes depois da aprovação.',
                            style: AppText.caption(AppColors.amber),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_contaAtiva) ...[
                    Text(
                      'Assine para ficar online',
                      style: AppText.h2(AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A mensalidade mantém sua conta ativa na plataforma. Sem ela, você não recebe corridas.',
                      style: AppText.body(AppColors.textDim),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadius.smBr,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: CardFormField(
                        style: CardFormStyle(
                          backgroundColor: AppColors.surfaceElevated,
                          borderColor: AppColors.border,
                          textColor: AppColors.textPrimary,
                          placeholderColor: AppColors.textFaint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: AppText.caption(AppColors.red)),
                      ),
                    AppPrimaryButton(
                      label: 'Assinar mensalidade',
                      loading: _saving,
                      color: AppColors.green,
                      onPressed: _assinar,
                    ),
                    if (widget.fromRegistration) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _continuarSemAssinar,
                          child: Text(
                            'Continuar sem assinar agora',
                            style: AppText.body(AppColors.textDim),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    AppOutlinedButton(
                      label: 'Cancelar assinatura',
                      onPressed: _cancelar,
                      height: 52,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
