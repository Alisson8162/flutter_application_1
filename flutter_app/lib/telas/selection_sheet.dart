import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/cliente_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ClienteSolicitacaoServico extends StatefulWidget {
  final LatLng localizacaoCliente;
  final String tipoServico;
  final String serviceName;
  final String tipoVeiculo;

  const ClienteSolicitacaoServico({
    super.key,
    required this.localizacaoCliente,
    required this.tipoServico,
    required this.serviceName,
    required this.tipoVeiculo,
  });

  @override
  State<ClienteSolicitacaoServico> createState() => _ClienteSolicitacaoServicoState();
}

class _ClienteSolicitacaoServicoState extends State<ClienteSolicitacaoServico> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  LatLng? _destino;

  @override
  void initState() {
    super.initState();
    // Buscar profissionais próximos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ClienteProvider>(context, listen: false);
      provider.buscarProfissionaisProximos(
        widget.localizacaoCliente,
        widget.tipoServico,
        widget.tipoVeiculo,
      );
    });
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClienteProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: Text('Solicitar ${widget.serviceName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            backgroundColor: _getServiceColor(widget.tipoServico),
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Informações do serviço
                  _buildServiceInfo(),
                  const SizedBox(height: 18),

                  // Formulário de solicitação
                  _buildSolicitationForm(),
                  const SizedBox(height: 18),

                  // Profissionais disponíveis
                  _buildAvailableProfessionals(provider),
                  const SizedBox(height: 22),

                  // Botão de solicitar
                  _buildSubmitButton(provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  Widget _buildServiceInfo() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalhes do Serviço',
            style: AppText.h2(_getServiceColor(widget.tipoServico)),
          ),
          const SizedBox(height: 12),
          Text('Serviço: ${widget.serviceName}', style: AppText.body(AppColors.textDim)),
          const SizedBox(height: 4),
          Text('Tipo de Veículo: ${_getVehicleTypeText(widget.tipoVeiculo)}', style: AppText.body(AppColors.textDim)),
          const SizedBox(height: 4),
          Text(
            'Localização: ${widget.localizacaoCliente.latitude.toStringAsFixed(4)}, ${widget.localizacaoCliente.longitude.toStringAsFixed(4)}',
            style: AppText.body(AppColors.textDim),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitationForm() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informações Adicionais', style: AppText.h2(AppColors.textPrimary)),
          const SizedBox(height: 16),

          Text('Seu Nome', style: AppText.caption(AppColors.textDim)),
          const SizedBox(height: 6),
          AppTextField(
            controller: _nomeController,
            hint: 'Como podemos te chamar?',
            useFormField: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, informe seu nome';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          Text('Telefone', style: AppText.caption(AppColors.textDim)),
          const SizedBox(height: 6),
          AppTextField(
            controller: _telefoneController,
            hint: '(11) 99999-9999',
            keyboardType: TextInputType.phone,
            useFormField: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, informe seu telefone';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          Text('Descrição do Problema', style: AppText.caption(AppColors.textDim)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.smBr,
              border: Border.all(color: AppColors.border),
            ),
            child: TextFormField(
              controller: _descricaoController,
              style: AppText.body(AppColors.textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                hintText: 'Descreva o problema do seu veículo...',
                hintStyle: AppText.body(AppColors.textFaint),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, descreva o problema';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableProfessionals(ClienteProvider provider) {
    if (provider.isLoading && provider.nearbyProfessionals.isEmpty) {
      return _sectionCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(color: AppColors.green),
          ),
        ),
      );
    }

    if (provider.nearbyProfessionals.isEmpty) {
      return _sectionCard(
        child: Text(
          'Nenhum profissional disponível no momento.',
          style: AppText.body(AppColors.textDim),
        ),
      );
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profissionais Disponíveis', style: AppText.h2(AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...provider.nearbyProfessionals.map((professional) => 
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.smBr,
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: _getServiceColor(widget.tipoServico),
                  child: Text(
                    professional['name']?.substring(0, 1) ?? 'P',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  professional['name'] ?? 'Profissional',
                  style: AppText.bodyMedium(AppColors.textPrimary),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber[400], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${professional['averageRating']?.toStringAsFixed(1) ?? '5.0'}',
                          style: AppText.caption(AppColors.textDim),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.textFaint, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '~${professional['distance']?.toStringAsFixed(1) ?? '0.0'} km',
                          style: AppText.caption(AppColors.textFaint),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getServiceColor(widget.tipoServico),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'R\$${professional['price']?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ClienteProvider provider) {
    return AppPrimaryButton(
      label: 'Solicitar Serviço',
      onPressed: provider.isLoading ? null : _submitSolicitation,
      loading: provider.isLoading,
      color: _getServiceColor(widget.tipoServico),
      foreground: Colors.white,
      icon: Icons.check_circle_rounded,
      height: 56,
    );
  }

  Future<void> _submitSolicitation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<ClienteProvider>(context, listen: false);

    // Estimativa simples de distância/preço para o profissional escolhido
    // (o back-end recalcula/valida; aqui é só o valor exibido/enviado).
    final selecionado = provider.nearbyProfessionals.isNotEmpty
        ? provider.nearbyProfessionals.first
        : null;
    final double distanciaKm = (selecionado?['distance_km'] as num?)?.toDouble() ?? 5.0;
    final double precoEstimado = (selecionado?['price'] as num?)?.toDouble() ?? 50.0;

    final result = await provider.solicitarServico(
      localizacaoCliente: widget.localizacaoCliente,
      tipoServico: widget.tipoServico,
      tipoVeiculo: widget.tipoVeiculo,
      descricaoProblema: _descricaoController.text,
      nomeCliente: _nomeController.text.isNotEmpty 
          ? _nomeController.text 
          : provider.userName ?? 'Cliente',
      telefoneCliente: _telefoneController.text,
      distanciaKm: distanciaKm,
      precoEstimado: precoEstimado,
      destino: _destino,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Serviço solicitado com sucesso!'),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final ride = result['data'] as Map<String, dynamic>?;
      Navigator.pop(context, ride);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Erro ao solicitar serviço'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // Métodos auxiliares
  Color _getServiceColor(String serviceType) {
    switch (serviceType) {
      case 'mecanico':
        return AppColors.amber;
      case 'guincho':
        return AppColors.blue;
      case 'borracharia':
        return AppColors.red;
      case 'eletrica':
        return const Color(0xFFEAB308);
      default:
        return AppColors.green;
    }
  }

  String _getVehicleTypeText(String vehicleType) {
    return vehicleType == 'leve' ? 'Veículo Leve' : 'Veículo Pesado';
  }
}
