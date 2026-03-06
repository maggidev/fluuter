import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/node_service.dart';

/// Card de conexão exibido no Dashboard.
/// Mostra o status atual, o Pairing Code gerado e permite inserir o número.
class ConnectionCard extends StatefulWidget {
  final NodeService nodeService;

  const ConnectionCard({super.key, required this.nodeService});

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Color _statusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return const Color(0xFF25D366); // Verde WhatsApp
      case ConnectionStatus.connecting:
        return const Color(0xFFFFC107); // Amarelo
      case ConnectionStatus.disconnected:
        return const Color(0xFFEF5350); // Vermelho
    }
  }

  String _statusLabel(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Conectado';
      case ConnectionStatus.connecting:
        return 'Conectando...';
      case ConnectionStatus.disconnected:
        return 'Desconectado';
    }
  }

  IconData _statusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Icons.check_circle_rounded;
      case ConnectionStatus.connecting:
        return Icons.sync_rounded;
      case ConnectionStatus.disconnected:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.nodeService;
    final status = svc.connectionStatus;
    final color = _statusColor(status);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ──────────────────────────────────────────────────
            Row(
              children: [
                Icon(_statusIcon(status), color: color, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Bot',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      _statusLabel(status),
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                if (status == ConnectionStatus.connected && svc.connectedUser != null)
                  Chip(
                    label: Text(
                      svc.connectedUser!,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: color.withOpacity(0.15),
                  ),
              ],
            ),

            const Divider(height: 24),

            // ── Pairing Code ───────────────────────────────────────────────
            if (status != ConnectionStatus.connected) ...[
              if (svc.awaitingPhone || svc.pairingCode == null) ...[
                Text(
                  'Número de Telefone',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Ex: 5511999999999',
                          prefixIcon: const Icon(Icons.phone_android),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final phone = _phoneController.text.trim();
                        if (phone.length >= 10) {
                          svc.requestPairingCode(phone);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Digite um número válido com DDD e código do país'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Gerar Código'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (svc.pairingCode != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF25D366), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Pairing Code',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF25D366),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        svc.pairingCode!,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: svc.pairingCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Código copiado!')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copiar código'),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Abra o WhatsApp > Dispositivos Vinculados > Vincular com número de telefone',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            if (status == ConnectionStatus.connected) ...[
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    svc.connectedPhone ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
