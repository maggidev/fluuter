import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Representa o status de conexão com o WhatsApp.
enum ConnectionStatus { disconnected, connecting, connected }

/// Serviço responsável por:
/// 1. Iniciar o processo Node.js em segundo plano (via flutter_nodejs_mobile ou processo nativo).
/// 2. Manter uma conexão TCP com o servidor Node.js na porta 3001.
/// 3. Emitir eventos recebidos do Node.js para os listeners do Flutter.
class NodeService extends ChangeNotifier {
  static const int _tcpPort = 3001;
  static const String _tcpHost = '127.0.0.1';

  Socket? _socket;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _disposed = false;

  // ── Estado Público ────────────────────────────────────────────────────────
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  String? connectedUser;
  String? connectedPhone;
  String? pairingCode;
  bool awaitingPhone = false;
  final List<String> logs = [];

  // ── Stream Controllers ────────────────────────────────────────────────────
  final _deletedMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _mediaSavedController = StreamController<Map<String, dynamic>>.broadcast();
  final _logController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onMessageDeleted => _deletedMessageController.stream;
  Stream<Map<String, dynamic>> get onMediaSaved => _mediaSavedController.stream;
  Stream<String> get onLog => _logController.stream;

  // ── Inicialização ─────────────────────────────────────────────────────────

  /// Inicia a conexão TCP com o servidor Node.js.
  /// Deve ser chamado após o processo Node.js já estar rodando.
  Future<void> connect() async {
    if (_isConnecting || _socket != null) return;
    _isConnecting = true;
    _addLog('[TCP] Tentando conectar ao servidor Node.js...');

    try {
      _socket = await Socket.connect(_tcpHost, _tcpPort,
          timeout: const Duration(seconds: 5));
      _isConnecting = false;
      _addLog('[TCP] Conectado ao servidor Node.js na porta $_tcpPort');

      // Processar dados recebidos (mensagens podem chegar fragmentadas)
      String buffer = '';
      _socket!.transform(utf8.decoder).listen(
        (data) {
          buffer += data;
          final lines = buffer.split('\n');
          buffer = lines.removeLast(); // Último fragmento incompleto
          for (final line in lines) {
            if (line.trim().isNotEmpty) _handleMessage(line.trim());
          }
        },
        onError: (error) {
          _addLog('[TCP] Erro na conexão: $error');
          _scheduleReconnect();
        },
        onDone: () {
          _addLog('[TCP] Conexão encerrada pelo servidor Node.js');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnecting = false;
      _addLog('[TCP] Falha ao conectar: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _socket = null;
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
    _addLog('[TCP] Reconectando em 5 segundos...');
  }

  // ── Processamento de Mensagens ────────────────────────────────────────────

  void _handleMessage(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final payload = json['payload'] as Map<String, dynamic>? ?? {};

      _addLog('[EVT] $type');

      switch (type) {
        case 'connection_status':
          _handleConnectionStatus(payload);
          break;
        case 'pairing_code':
          pairingCode = payload['code'] as String?;
          _addLog('[PAIRING] Código: $pairingCode');
          notifyListeners();
          break;
        case 'awaiting_phone':
          awaitingPhone = true;
          _addLog('[PAIRING] Aguardando número de telefone...');
          notifyListeners();
          break;
        case 'message_deleted':
          _deletedMessageController.add(payload);
          break;
        case 'media_saved':
          _mediaSavedController.add(payload);
          break;
        case 'logged_out':
          connectionStatus = ConnectionStatus.disconnected;
          connectedUser = null;
          _addLog('[BOT] Sessão encerrada — reconecte o dispositivo');
          notifyListeners();
          break;
        case 'error':
          _addLog('[ERRO] ${payload['message']}');
          break;
        default:
          _addLog('[?] Evento desconhecido: $type');
      }
    } catch (e) {
      _addLog('[TCP] Erro ao processar mensagem: $e');
    }
  }

  void _handleConnectionStatus(Map<String, dynamic> payload) {
    final status = payload['status'] as String?;
    switch (status) {
      case 'connecting':
        connectionStatus = ConnectionStatus.connecting;
        break;
      case 'connected':
        connectionStatus = ConnectionStatus.connected;
        connectedUser = payload['user'] as String?;
        connectedPhone = payload['phone'] as String?;
        awaitingPhone = false;
        pairingCode = null;
        _addLog('[BOT] Conectado como: $connectedUser');
        break;
      case 'disconnected':
        connectionStatus = ConnectionStatus.disconnected;
        connectedUser = null;
        _addLog('[BOT] Desconectado: ${payload['reason']}');
        break;
    }
    notifyListeners();
  }

  // ── Envio de Comandos para o Node.js ──────────────────────────────────────

  void sendCommand(Map<String, dynamic> command) {
    if (_socket == null) {
      _addLog('[CMD] Socket não disponível. Comando descartado.');
      return;
    }
    try {
      final data = jsonEncode(command) + '\n';
      _socket!.write(data);
    } catch (e) {
      _addLog('[CMD] Erro ao enviar comando: $e');
    }
  }

  /// Solicita ao Node.js a geração do Pairing Code para o número informado.
  /// O número deve estar no formato internacional sem '+' (ex: 5511999999999).
  void requestPairingCode(String phoneNumber) {
    pairingCode = null;
    notifyListeners();
    sendCommand({'action': 'get_pairing_code', 'phone': phoneNumber});
    _addLog('[CMD] Solicitando Pairing Code para: $phoneNumber');
  }

  // ── Utilitários ───────────────────────────────────────────────────────────

  void _addLog(String message) {
    final entry = '[${_timeNow()}] $message';
    logs.add(entry);
    if (logs.length > 200) logs.removeAt(0);
    _logController.add(entry);
    if (kDebugMode) debugPrint(entry);
  }

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _socket?.destroy();
    _deletedMessageController.close();
    _mediaSavedController.close();
    _logController.close();
    super.dispose();
  }
}
