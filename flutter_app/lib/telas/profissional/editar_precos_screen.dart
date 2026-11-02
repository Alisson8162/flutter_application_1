import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/profissional_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// Tela para o profissional ver/editar o preço que cobra (taxa base +
/// valor por km) depois do cadastro.
///
/// NOVO: antes o preço só podia ser definido uma vez, durante o cadastro -
/// não existia nenhuma tela para revisar ou ajustar depois.
class EditarPrecosScreen extends StatefulWidget {
  const EditarPrecosScreen({super.key});

  @override
  State<EditarPrecosScreen> createState() => _EditarPrecosScreenState();
}

class _EditarPrecosScreenState extends State<EditarPrecosScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valorBase;
  late final TextEditingController _valorKm;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProfissionalProvider>();
    _valorBase = TextEditingController(
      text: provider.valorBase != null ? provider.valorBase!.toStringAsFixed(2) : '',
    );
    _valorKm = TextEditingController(
      text: provider.valorKm != null ? provider.valorKm!.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _valorBase.dispose();
    _valorKm.dispose();
    super.dispose();
  }

  String? _priceValidator(String? value) {
    if (value == null || value.isEmpty) return "Obrigatório";
    final n = double.tryParse(value.replaceAll(',', '.'));
    if (n == null || n < 0) return "Valor inválido";
    return null;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final provider = context.read<ProfissionalProvider>();
    final result = await provider.atualizarPrecos(
      valorBase: double.parse(_valorBase.text.replaceAll(',', '.')),
      valorKm: double.parse(_valorKm.text.replaceAll(',', '.')),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preço atualizado com sucesso!'), backgroundColor: AppColors.green),
      );
      Navigator.pop(context);
    } else {
      setState(() => _error = result['message']?.toString() ?? 'Erro ao salvar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Meus preços', style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Quanto você cobra pelo atendimento?',
                style: AppText.bodyMedium(AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Esse é o valor que o cliente vê antes de te chamar. Você pode ajustar quando quiser.',
                style: AppText.caption(AppColors.textFaint),
              ),
              const SizedBox(height: 20),
              Text('Taxa base', style: AppText.caption(AppColors.textDim)),
              const SizedBox(height: 6),
              AppTextField(
                controller: _valorBase,
                hint: "Ex.: R\$ 30,00",
                keyboardType: TextInputType.number,
                useFormField: true,
                validator: _priceValidator,
              ),
              const SizedBox(height: 16),
              Text('Valor por km rodado', style: AppText.caption(AppColors.textDim)),
              const SizedBox(height: 6),
              AppTextField(
                controller: _valorKm,
                hint: 'Ex.: R\$ 2,50',
                keyboardType: TextInputType.number,
                useFormField: true,
                validator: _priceValidator,
              ),
              const SizedBox(height: 8),
              _PriceExamplePreview(valorBaseCtrl: _valorBase, valorKmCtrl: _valorKm),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: AppText.caption(AppColors.red)),
                ),
              AppPrimaryButton(
                label: 'Salvar',
                loading: _saving,
                color: AppColors.green,
                onPressed: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pequena prévia: "Uma corrida de 10km ficaria R$ X" - ajuda o profissional
/// a calibrar o preço sem precisar fazer conta de cabeça.
class _PriceExamplePreview extends StatefulWidget {
  final TextEditingController valorBaseCtrl;
  final TextEditingController valorKmCtrl;

  const _PriceExamplePreview({required this.valorBaseCtrl, required this.valorKmCtrl});

  @override
  State<_PriceExamplePreview> createState() => _PriceExamplePreviewState();
}

class _PriceExamplePreviewState extends State<_PriceExamplePreview> {
  @override
  void initState() {
    super.initState();
    widget.valorBaseCtrl.addListener(_onChange);
    widget.valorKmCtrl.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.valorBaseCtrl.removeListener(_onChange);
    widget.valorKmCtrl.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final base = double.tryParse(widget.valorBaseCtrl.text.replaceAll(',', '.'));
    final km = double.tryParse(widget.valorKmCtrl.text.replaceAll(',', '.'));
    if (base == null || km == null) return const SizedBox.shrink();

    final exemplo = base + (km * 10);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Exemplo: um atendimento a 10 km ficaria R\$ ${exemplo.toStringAsFixed(2)}',
        style: AppText.caption(AppColors.textFaint),
      ),
    );
  }
}
