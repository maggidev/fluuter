import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/deleted_message.dart';
import '../services/node_service.dart';

/// Tela que exibe o histórico de mensagens apagadas capturadas pelo bot.
class DeletedMessagesScreen extends StatefulWidget {
  final NodeService nodeService;

  const DeletedMessagesScreen({super.key, required this.nodeService});

  @override
  State<DeletedMessagesScreen> createState() => _DeletedMessagesScreenState();
}

class _DeletedMessagesScreenState extends State<DeletedMessagesScreen> {
  final List<DeletedMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFromDatabase();
    _listenToNewDeletions();
  }

  Future<void> _loadFromDatabase() async {
    final msgs = await DatabaseHelper.instance.getAllDeletedMessages();
    if (mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        _loading = false;
      });
    }
  }

  void _listenToNewDeletions() {
    widget.nodeService.onMessageDeleted.listen((payload) async {
      final msg = DeletedMessage.fromJson(payload);
      await DatabaseHelper.instance.insertDeletedMessage(msg);
      if (mounted) {
        setState(() => _messages.insert(0, msg));
      }
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar histórico'),
        content: const Text(
          'Deseja apagar permanentemente todas as mensagens capturadas?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteAllDeletedMessages();
      if (mounted) setState(() => _messages.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, size: 22),
            const SizedBox(width: 8),
            const Text('Mensagens Apagadas'),
            const SizedBox(width: 8),
            if (_messages.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_messages.length}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded),
              tooltip: 'Limpar tudo',
              onPressed: _clearAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _loadFromDatabase,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadFromDatabase,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildMessageCard(_messages[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhuma mensagem apagada capturada',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'As mensagens apagadas aparecerão aqui\nassim que o bot estiver conectado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(DeletedMessage msg) {
    final hasText = msg.text != null && msg.text!.isNotEmpty;
    final hasMedia = msg.mediaPath != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ────────────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF25D366).withOpacity(0.15),
                  child: Text(
                    msg.pushName.isNotEmpty ? msg.pushName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.pushName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        msg.formattedPhone,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_rounded, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'APAGADA',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg.formattedDeletedAt,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Conteúdo da Mensagem ──────────────────────────────────────
            if (hasText)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  msg.text!,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),

            if (hasMedia && !hasText)
              Row(
                children: [
                  const Icon(Icons.image_rounded, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text(
                    'Mídia capturada',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),

            if (!hasText && !hasMedia)
              const Text(
                '[Conteúdo não disponível]',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
