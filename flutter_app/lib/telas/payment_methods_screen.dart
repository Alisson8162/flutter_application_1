import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Tela real de métodos de pagamento, usando o SDK da Stripe.
///
/// CORRIGIDO: em cliente_home.dart existia um diálogo `_showPaymentMethods()`
/// inteiramente mockado (cartão "**** 1234" fixo, botão "Adicionar cartão"
/// sem nenhuma ação). Esta tela substitui aquele mock: lista os cartões
/// reais do cliente (via GET /api/payments/methods) e permite adicionar um
/// cartão novo coletando os dados DIRETAMENTE com o SDK da Stripe - o número
/// do cartão nunca passa pelo nosso backend, apenas o `payment_method_id`
/// retornado pela Stripe.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<dynamic> _methods = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() => _loading = true);
    final result = await ApiService.get('/payments/methods');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _methods = (result['data'] as List<dynamic>?) ?? [];
      } else {
        _error = result['message']?.toString();
      }
    });
  }

  Future<void> _addCard() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    // 1) Pede ao backend um SetupIntent (cria/reaproveita o Stripe Customer)
    final setupResult = await ApiService.post('/payments/setup-intent', {});
    if (setupResult['success'] != true) {
      setState(() {
        _saving = false;
        _error = setupResult['message']?.toString() ?? 'Não foi possível iniciar o cadastro do cartão';
      });
      return;
    }

    final clientSecret = setupResult['data']['client_secret'] as String;

    try {
      // 2) Confirma o SetupIntent DIRETAMENTE com a Stripe, usando os dados
      // preenchidos no CardFormField exibido no diálogo - o número do
      // cartão nunca chega ao nosso servidor.
      final setupIntent = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: clientSecret,
        params: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      final paymentMethodId = setupIntent.paymentMethodId;
      if (paymentMethodId == null) {
        throw Exception('A Stripe não retornou o ID do método de pagamento');
      }

      // 3) Avisa o backend para persistir os metadados (bandeira, últimos 4
      // dígitos) do cartão recém-confirmado.
      final confirmResult = await ApiService.post('/payments/confirm-method', {
        'payment_method_id': paymentMethodId,
        'set_as_default': _methods.isEmpty,
      });

      if (!mounted) return;

      if (confirmResult['success'] == true) {
        await _loadMethods();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cartão adicionado com sucesso!')),
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

  Future<void> _setDefault(String id) async {
    await ApiService.put('/payments/methods/$id/default', {});
    _loadMethods();
  }

  Future<void> _remove(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remover cartão', style: AppText.h2(AppColors.textPrimary)),
        content: Text('Tem certeza que deseja remover este cartão?', style: AppText.body(AppColors.textDim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: AppText.bodyMedium(AppColors.textDim))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Remover', style: AppText.bodyMedium(AppColors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    await ApiService.delete('/payments/methods/$id');
    _loadMethods();
  }

  void _showAddCardSheet() {
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
              Text('Adicionar cartão', style: AppText.h2(AppColors.textPrimary)),
              const SizedBox(height: 16),
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
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: AppText.caption(AppColors.red)),
                ),
              AppPrimaryButton(
                label: 'Salvar cartão',
                loading: _saving,
                color: AppColors.green,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _addCard();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Métodos de pagamento', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : RefreshIndicator(
              onRefresh: _loadMethods,
              color: AppColors.green,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  if (_error != null && _methods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(_error!, style: AppText.body(AppColors.red)),
                    ),
                  if (_methods.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('Nenhum cartão cadastrado ainda', style: AppText.body(AppColors.textDim))),
                    ),
                  ..._methods.map((m) {
                    final isDefault = m['is_default'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.mdBr,
                        border: Border.all(color: isDefault ? AppColors.green : AppColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.credit_card_rounded, color: AppColors.textDim),
                        title: Text('${m['brand'] ?? 'Cartão'} •••• ${m['ultimos_quatro']}',
                            style: AppText.bodyMedium(AppColors.textPrimary)),
                        subtitle: Text(
                          'Validade ${m['exp_month']}/${m['exp_year']}${isDefault ? ' • Padrão' : ''}',
                          style: AppText.caption(AppColors.textDim),
                        ),
                        trailing: PopupMenuButton<String>(
                          color: AppColors.surfaceElevated,
                          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textDim),
                          onSelected: (value) {
                            if (value == 'default') _setDefault(m['id']);
                            if (value == 'remove') _remove(m['id']);
                          },
                          itemBuilder: (ctx) => [
                            if (!isDefault)
                              PopupMenuItem(value: 'default', child: Text('Definir como padrão', style: AppText.body(AppColors.textPrimary))),
                            PopupMenuItem(value: 'remove', child: Text('Remover', style: AppText.body(AppColors.red))),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        foregroundColor: const Color(0xFF06120A),
        onPressed: _showAddCardSheet,
        icon: const Icon(Icons.add_rounded),
        label: Text('Adicionar cartão', style: AppText.button(const Color(0xFF06120A))),
      ),
    );
  }
}
