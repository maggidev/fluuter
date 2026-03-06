/// Modelo de dados para uma mensagem apagada capturada pelo bot.
class DeletedMessage {
  final int? id;
  final String msgId;
  final String from;
  final String pushName;
  final String? text;
  final String timestamp;
  final String deletedAt;
  final String? mediaPath;

  const DeletedMessage({
    this.id,
    required this.msgId,
    required this.from,
    required this.pushName,
    this.text,
    required this.timestamp,
    required this.deletedAt,
    this.mediaPath,
  });

  /// Cria um [DeletedMessage] a partir de um mapa JSON (recebido via TCP).
  factory DeletedMessage.fromJson(Map<String, dynamic> json) {
    return DeletedMessage(
      msgId: json['id'] as String? ?? '',
      from: json['from'] as String? ?? '',
      pushName: json['pushName'] as String? ?? 'Desconhecido',
      text: json['text'] as String?,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      deletedAt: json['deletedAt'] as String? ?? DateTime.now().toIso8601String(),
      mediaPath: json['filePath'] as String?,
    );
  }

  /// Converte para mapa para persistência no SQFlite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'msgId': msgId,
      'fromJid': from,
      'pushName': pushName,
      'text': text,
      'timestamp': timestamp,
      'deletedAt': deletedAt,
      'mediaPath': mediaPath,
    };
  }

  /// Cria um [DeletedMessage] a partir de um mapa do SQFlite.
  factory DeletedMessage.fromMap(Map<String, dynamic> map) {
    return DeletedMessage(
      id: map['id'] as int?,
      msgId: map['msgId'] as String? ?? '',
      from: map['fromJid'] as String? ?? '',
      pushName: map['pushName'] as String? ?? 'Desconhecido',
      text: map['text'] as String?,
      timestamp: map['timestamp'] as String? ?? '',
      deletedAt: map['deletedAt'] as String? ?? '',
      mediaPath: map['mediaPath'] as String?,
    );
  }

  /// Formata o número de telefone removendo o sufixo @s.whatsapp.net.
  String get formattedPhone => from.replaceAll('@s.whatsapp.net', '').replaceAll('@g.us', '');

  /// Retorna a data/hora de deleção formatada para exibição.
  String get formattedDeletedAt {
    try {
      final dt = DateTime.parse(deletedAt).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return deletedAt;
    }
  }
}
