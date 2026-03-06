/// Modelo de dados para um arquivo de mídia capturado pelo bot.
class MediaItem {
  final int? id;
  final String msgId;
  final String from;
  final String pushName;
  final String filePath;
  final String mediaType;
  final String timestamp;

  const MediaItem({
    this.id,
    required this.msgId,
    required this.from,
    required this.pushName,
    required this.filePath,
    required this.mediaType,
    required this.timestamp,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      msgId: json['id'] as String? ?? '',
      from: json['from'] as String? ?? '',
      pushName: json['pushName'] as String? ?? 'Desconhecido',
      filePath: json['filePath'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'imageMessage',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'msgId': msgId,
      'fromJid': from,
      'pushName': pushName,
      'filePath': filePath,
      'mediaType': mediaType,
      'timestamp': timestamp,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as int?,
      msgId: map['msgId'] as String? ?? '',
      from: map['fromJid'] as String? ?? '',
      pushName: map['pushName'] as String? ?? 'Desconhecido',
      filePath: map['filePath'] as String? ?? '',
      mediaType: map['mediaType'] as String? ?? 'imageMessage',
      timestamp: map['timestamp'] as String? ?? '',
    );
  }

  bool get isImage => mediaType == 'imageMessage';
  bool get isVideo => mediaType == 'videoMessage';
  bool get isAudio => mediaType == 'audioMessage';

  String get formattedPhone => from.replaceAll('@s.whatsapp.net', '').replaceAll('@g.us', '');
}
