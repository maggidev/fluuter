import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/node_service.dart';

/// Tela de console que exibe os logs do bot em tempo real.
class LogsScreen extends StatefulWidget {
  final NodeService nodeService;

  const LogsScreen({super.key, required this.nodeService});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // Carregar logs existentes
    _logs.addAll(widget.nodeService.logs);

    // Escutar novos logs
    widget.nodeService.onLog.listen((log) {
      if (mounted) {
        setState(() => _logs.add(log));
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _logColor(String log) {
    if (log.contains('[ERRO]') || log.contains('[FATAL]')) return const Color(0xFFEF5350);
    if (log.contains('[PAIRING]')) return const Color(0xFF25D366);
    if (log.contains('[BOT]')) return const Color(0xFF42A5F5);
    if (log.contains('[MEDIA]')) return const Color(0xFFAB47BC);
    if (log.contains('[DELETE]')) return const Color(0xFFFF7043);
    if (log.contains('[TCP]')) return const Color(0xFFFFC107);
    return const Color(0xFFB0BEC5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, size: 22),
            SizedBox(width: 8),
            Text('Console de Logs'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom_rounded : Icons.pause_rounded,
              color: _autoScroll ? const Color(0xFF25D366) : Colors.grey,
            ),
            tooltip: _autoScroll ? 'Auto-scroll ativo' : 'Auto-scroll pausado',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copiar todos os logs',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _logs.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copiados para a área de transferência')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Limpar console',
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF1E1E1E),
        child: _logs.isEmpty
            ? const Center(
                child: Text(
                  'Aguardando logs...',
                  style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: _logColor(log),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
