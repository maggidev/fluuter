import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/deleted_message.dart';
import '../models/media_item.dart';

/// Singleton responsável por gerenciar o banco de dados SQFlite local.
/// Persiste mensagens apagadas e mídias capturadas pelo bot.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'whatsapp_bot.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de mensagens apagadas
    await db.execute('''
      CREATE TABLE deleted_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        msgId TEXT NOT NULL UNIQUE,
        fromJid TEXT NOT NULL,
        pushName TEXT NOT NULL,
        text TEXT,
        timestamp TEXT NOT NULL,
        deletedAt TEXT NOT NULL,
        mediaPath TEXT
      )
    ''');

    // Tabela de mídias capturadas
    await db.execute('''
      CREATE TABLE media_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        msgId TEXT NOT NULL UNIQUE,
        fromJid TEXT NOT NULL,
        pushName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        mediaType TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Índices para melhorar performance de consultas
    await db.execute('CREATE INDEX idx_deleted_at ON deleted_messages(deletedAt DESC)');
    await db.execute('CREATE INDEX idx_media_timestamp ON media_items(timestamp DESC)');
  }

  // ── Operações em Mensagens Apagadas ──────────────────────────────────────

  Future<int> insertDeletedMessage(DeletedMessage msg) async {
    final db = await database;
    return db.insert(
      'deleted_messages',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<DeletedMessage>> getAllDeletedMessages() async {
    final db = await database;
    final maps = await db.query(
      'deleted_messages',
      orderBy: 'deletedAt DESC',
      limit: 500,
    );
    return maps.map(DeletedMessage.fromMap).toList();
  }

  Future<int> deleteAllDeletedMessages() async {
    final db = await database;
    return db.delete('deleted_messages');
  }

  // ── Operações em Mídias ──────────────────────────────────────────────────

  Future<int> insertMediaItem(MediaItem item) async {
    final db = await database;
    return db.insert(
      'media_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<MediaItem>> getAllMediaItems() async {
    final db = await database;
    final maps = await db.query(
      'media_items',
      orderBy: 'timestamp DESC',
    );
    return maps.map(MediaItem.fromMap).toList();
  }

  Future<int> deleteAllMediaItems() async {
    final db = await database;
    return db.delete('media_items');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}
