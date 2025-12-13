import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../lib/cliente_provider.dart'; // Caminho corrigido

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
          appBar: AppBar(
            title: Text('Solicitar ${widget.serviceName}'),
            backgroundColor: _getServiceColor(widget.tipoServico),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Informações do serviço
                  _buildServiceInfo(),
                  const SizedBox(height: 20),
                  
                  // Formulário de solicitação
                  _buildSolicitationForm(),
                  const SizedBox(height: 20),
                  
                  // Profissionais disponíveis
                  _buildAvailableProfessionals(provider),
                  const SizedBox(height: 20),
                  
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

  Widget _buildServiceInfo() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalhes do Serviço',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getServiceColor(widget.tipoServico),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Serviço: ${widget.serviceName}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Tipo de Veículo: ${_getVehicleTypeText(widget.tipoVeiculo)}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Localização: ${widget.localizacaoCliente.latitude.toStringAsFixed(4)}, ${widget.localizacaoCliente.longitude.toStringAsFixed(4)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolicitationForm() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informações Adicionais',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _nomeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Seu Nome',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[800],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, informe seu nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _telefoneController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Telefone',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[800],
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, informe seu telefone';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descricaoController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Descrição do Problema',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[800],
                hintText: 'Descreva o problema do seu veículo...',
                hintStyle: const TextStyle(color: Colors.grey),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, descreva o problema';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableProfessionals(ClienteProvider provider) {
    if (provider.isLoading && provider.nearbyProfessionals.isEmpty) {
      return Card(
        color: Colors.grey[900],
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          ),
        ),
      );
    }

    if (provider.nearbyProfessionals.isEmpty) {
      return Card(
        color: Colors.grey[900],
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Nenhum profissional disponível no momento.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profissionais Disponíveis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...provider.nearbyProfessionals.map((professional) => 
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.yellow, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${professional['averageRating']?.toStringAsFixed(1) ?? '5.0'}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.grey, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '~${professional['distance']?.toStringAsFixed(1) ?? '0.0'} km',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
      ),
    );
  }

  Widget _buildSubmitButton(ClienteProvider provider) {
    return ElevatedButton(
      onPressed: provider.isLoading ? null : _submitSolicitation,
      style: ElevatedButton.styleFrom(
        backgroundColor: _getServiceColor(widget.tipoServico),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 5,
      ),
      child: provider.isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle),
                SizedBox(width: 8),
                Text('Solicitar Serviço', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
    );
  }

  Future<void> _submitSolicitation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<ClienteProvider>(context, listen: false);
    
    final result = await provider.solicitarServico(
      localizacaoCliente: widget.localizacaoCliente,
      tipoServico: widget.tipoServico,
      tipoVeiculo: widget.tipoVeiculo,
      descricaoProblema: _descricaoController.text,
      nomeCliente: _nomeController.text.isNotEmpty 
          ? _nomeController.text 
          : provider.userName ?? 'Cliente',
      telefoneCliente: _telefoneController.text,
      destino: _destino,
    );

    if (result['success']) {
      // Mostrar mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Aguardar e voltar
      await Future.delayed(const Duration(seconds: 2));
      
      // Voltar para a tela anterior
      Navigator.pop(context);
    } else {
      // Mostrar mensagem de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Métodos auxiliares
  Color _getServiceColor(String serviceType) {
    switch (serviceType) {
      case 'mecanico':
        return Colors.orange;
      case 'guincho':
        return Colors.blue;
      case 'borracharia':
        return Colors.red;
      case 'eletrica':
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }

  String _getVehicleTypeText(String vehicleType) {
    return vehicleType == 'leve' ? 'Veículo Leve' : 'Veículo Pesado';
  }
}