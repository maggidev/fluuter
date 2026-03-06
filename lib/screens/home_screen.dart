import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/node_service.dart';
import '../widgets/connection_card.dart';
import 'deleted_messages_screen.dart';
import 'gallery_screen.dart';
import 'logs_screen.dart';

/// Tela principal do aplicativo com navegação por abas (BottomNavigationBar).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final nodeService = context.watch<NodeService>();

    final screens = [
      _DashboardTab(nodeService: nodeService),
      DeletedMessagesScreen(nodeService: nodeService),
      GalleryScreen(nodeService: nodeService),
      LogsScreen(nodeService: nodeService),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: nodeService.connectionStatus == ConnectionStatus.connected,
              child: const Icon(Icons.delete_sweep_outlined),
            ),
            selectedIcon: const Icon(Icons.delete_sweep_rounded),
            label: 'Apagadas',
          ),
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            selectedIcon: const Icon(Icons.photo_library_rounded),
            label: 'Galeria',
          ),
          NavigationDestination(
            icon: const Icon(Icons.terminal_outlined),
            selectedIcon: const Icon(Icons.terminal_rounded),
            label: 'Console',
          ),
        ],
      ),
    );
  }
}

/// Aba de Dashboard com cards de status e estatísticas.
class _DashboardTab extends StatelessWidget {
  final NodeService nodeService;

  const _DashboardTab({required this.nodeService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, size: 24, color: Color(0xFF25D366)),
            SizedBox(width: 10),
            Text(
              'WhatsApp Bot',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: _StatusDot(status: nodeService.connectionStatus),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          nodeService.sendCommand({'action': 'get_status'});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Card de Conexão ──────────────────────────────────────────
            ConnectionCard(nodeService: nodeService),
            const SizedBox(height: 16),

            // ── Cards de Estatísticas ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.delete_sweep_rounded,
                    label: 'Mensagens\nApagadas',
                    color: Colors.red,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.photo_library_rounded,
                    label: 'Mídias\nCapturadas',
                    color: Colors.blue,
                    onTap: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Card de Instruções ───────────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF25D366)),
                        SizedBox(width: 8),
                        Text(
                          'Como conectar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InstructionStep(
                      number: '1',
                      text: 'Digite seu número com código do país (ex: 5511999999999)',
                    ),
                    _InstructionStep(
                      number: '2',
                      text: 'Toque em "Gerar Código" e aguarde o Pairing Code',
                    ),
                    _InstructionStep(
                      number: '3',
                      text: 'No WhatsApp, vá em Dispositivos Vinculados > Vincular com número',
                    ),
                    _InstructionStep(
                      number: '4',
                      text: 'Digite o código de 8 dígitos exibido no app',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final ConnectionStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ConnectionStatus.connected:
        color = const Color(0xFF25D366);
        break;
      case ConnectionStatus.connecting:
        color = const Color(0xFFFFC107);
        break;
      case ConnectionStatus.disconnected:
        color = const Color(0xFFEF5350);
        break;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF25D366),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
