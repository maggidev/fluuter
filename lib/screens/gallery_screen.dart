import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/media_item.dart';
import '../services/node_service.dart';

/// Tela de galeria que exibe as mídias capturadas pelo bot em um GridView.
class GalleryScreen extends StatefulWidget {
  final NodeService nodeService;

  const GalleryScreen({super.key, required this.nodeService});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final List<MediaItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFromDatabase();
    _listenToNewMedia();
  }

  Future<void> _loadFromDatabase() async {
    final items = await DatabaseHelper.instance.getAllMediaItems();
    if (mounted) {
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    }
  }

  void _listenToNewMedia() {
    widget.nodeService.onMediaSaved.listen((payload) async {
      final item = MediaItem.fromJson(payload);
      await DatabaseHelper.instance.insertMediaItem(item);
      if (mounted) setState(() => _items.insert(0, item));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.photo_library_rounded, size: 22),
            const SizedBox(width: 8),
            const Text('Galeria de Mídias'),
            const SizedBox(width: 8),
            if (_items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_items.length}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFromDatabase,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadFromDatabase,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _buildGridItem(_items[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhuma mídia capturada',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fotos e vídeos recebidos no WhatsApp\naparecerão aqui automaticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(MediaItem item) {
    final file = File(item.filePath);
    final exists = file.existsSync();

    return GestureDetector(
      onTap: () => _openFullscreen(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Thumbnail ──────────────────────────────────────────────
            if (item.isImage && exists)
              Image.file(file, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey.shade200,
                child: Icon(
                  item.isVideo
                      ? Icons.videocam_rounded
                      : item.isAudio
                          ? Icons.audiotrack_rounded
                          : Icons.insert_drive_file_rounded,
                  size: 36,
                  color: Colors.grey.shade500,
                ),
              ),

            // ── Badge de tipo ──────────────────────────────────────────
            if (item.isVideo)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.play_circle_filled_rounded,
                    color: Colors.white, size: 22),
              ),

            // ── Overlay com nome do contato ────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  item.pushName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(MediaItem item) {
    if (!item.isImage) return;
    final file = File(item.filePath);
    if (!file.existsSync()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(item.pushName),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }
}
