import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';
import '../theme/app_theme.dart';

/// Chat entre cliente e profissional durante uma corrida ativa.
///
/// Histórico vem de GET /api/rides/:id/messages; envio é sempre via
/// POST /api/rides/:id/messages (o WebSocket em si não aceita mensagens do
/// cliente, só entrega broadcasts do servidor - ver server.js). As
/// mensagens que aparecem na tela vêm todas do WebSocket (inclusive as que
/// o próprio usuário envia, ecoadas de volta pelo backend), então não há
/// duplicação entre "otimista" e "real".
class ChatScreen extends StatefulWidget {
  final String rideId;
  final String otherPartyName;
  final Color accent;

  const ChatScreen({
    super.key,
    required this.rideId,
    required this.otherPartyName,
    this.accent = AppColors.green,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final WsService _wsService = WsService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  String? _myUserId;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await ApiService.userId;
    await _loadHistory();
    _wsService.connectToTrip(widget.rideId, onMessage: _handleIncoming);
  }

  Future<void> _loadHistory() async {
    final result = await ApiService.get('/rides/${widget.rideId}/messages');
    if (!mounted) return;

    if (result['success'] == true) {
      final list = (result['data'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _messages.addAll(list);
        _loading = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _loading = false);
    }
  }

  void _handleIncoming(Map<String, dynamic> message) {
    if (!mounted) return;
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _inputCtrl.clear();

    final result = await ApiService.post('/rides/${widget.rideId}/messages', {'content': text});

    if (!mounted) return;
    setState(() => _sending = false);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Não foi possível enviar a mensagem.')),
      );
    }
    // A própria mensagem aparece na lista via broadcast do WebSocket
    // (_handleIncoming), então não a adicionamos aqui manualmente.
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.otherPartyName, style: AppText.h2(AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Diga olá para ${widget.otherPartyName}',
                          style: AppText.body(AppColors.textDim),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildBubble(_messages[index]),
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> message) {
    final isMe = message['sender_id']?.toString() == _myUserId;
    final content = message['content']?.toString() ?? '';
    final senderName = message['sender_name']?.toString() ?? '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? widget.accent.withOpacity(0.9) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(senderName, style: AppText.caption(AppColors.textDim)),
              ),
            Text(
              content,
              style: AppText.body(isMe ? const Color(0xFF06120A) : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.smBr,
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                style: AppText.body(AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Digite uma mensagem…',
                  hintStyle: AppText.body(AppColors.textFaint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle),
            child: IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06120A)),
                    )
                  : const Icon(Icons.send_rounded, color: Color(0xFF06120A)),
              onPressed: _sending ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}
