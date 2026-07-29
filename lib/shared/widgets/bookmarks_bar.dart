// ==============================================================
// DulceNav - bookmarks_bar.dart
// Barra horizontal de favoritos (DulceUI) debajo de la barra URL.
// Permite abrir, editar y eliminar con clic derecho y menu contextual.
// ==============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/utils/url_utils.dart';

class BookmarksBar extends StatefulWidget {
  final Function(String url) onNavigate;
  final Function(String url, {bool isIncognito}) onNewTab;

  const BookmarksBar({
    super.key,
    required this.onNavigate,
    required this.onNewTab,
  });

  @override
  State<BookmarksBar> createState() => _BookmarksBarState();
}

class _BookmarksBarState extends State<BookmarksBar> {
  final storage = StorageService.instance;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final bookmarks = storage.bookmarks;

    if (bookmarks.isEmpty) return const SizedBox.shrink();

    final parsedBookmarks = <Map<String, String>>[];
    for (final item in bookmarks) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          final url = decoded['url']?.toString() ?? item;
          final title = decoded['title']?.toString() ?? '';
          parsedBookmarks.add({
            'title': title.isEmpty ? UrlUtils.getDomain(url) : title,
            'url': url,
            'original': item,
          });
        } else {
          parsedBookmarks.add({
            'title': UrlUtils.getDomain(item),
            'url': item,
            'original': item,
          });
        }
      } catch (_) {
        parsedBookmarks.add({
          'title': UrlUtils.getDomain(item),
          'url': item,
          'original': item,
        });
      }
    }

    return Container(
      height: 34,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withOpacity(theme.highContrast ? 1.0 : 0.4),
        border: Border(
          bottom: BorderSide(
            color: theme.activeBorderColor,
            width: 1.0,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: parsedBookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = parsedBookmarks[index];
          final title = bookmark['title']!;
          final url = bookmark['url']!;

          return _BookmarkChip(
            title: title,
            url: url,
            onTap: () => widget.onNavigate(url),
            onSecondaryTap: (position) => _showContextMenu(context, position, bookmark),
          );
        },
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position, Map<String, String> bookmark) {
    final url = bookmark['url']!;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF1E1E2E).withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white12),
      ),
      items: [
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.open_in_browser_rounded, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text('Abrir', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'open_new_tab',
          child: Row(
            children: [
              Icon(Icons.tab_rounded, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text('Abrir en nueva pestana', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text('Editar', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever_rounded, size: 16, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(fontFamily: 'Outfit', color: Colors.redAccent, fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 'open') {
        widget.onNavigate(url);
      } else if (value == 'open_new_tab') {
        widget.onNewTab(url);
      } else if (value == 'edit') {
        _showEditDialog(context, bookmark);
      } else if (value == 'delete') {
        _deleteBookmark(url);
      }
    });
  }

  void _deleteBookmark(String url) async {
    await storage.removeBookmark(url);
    setState(() {});
  }

  void _showEditDialog(BuildContext context, Map<String, String> bookmark) {
    final titleController = TextEditingController(text: bookmark['title']);
    final urlController = TextEditingController(text: bookmark['url']);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white12),
          ),
          title: Text(
            'Editar favorito',
            style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nombre:', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              Text('URL:', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: urlController,
                style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newTitle = titleController.text.trim();
                final newUrl = urlController.text.trim();
                if (newTitle.isNotEmpty && newUrl.isNotEmpty) {
                  await storage.updateBookmark(bookmark['url']!, newTitle, newUrl);
                  Navigator.of(ctx).pop();
                  setState(() {});
                }
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

class _BookmarkChip extends StatefulWidget {
  final String title;
  final String url;
  final VoidCallback onTap;
  final Function(Offset position) onSecondaryTap;

  const _BookmarkChip({
    required this.title,
    required this.url,
    required this.onTap,
    required this.onSecondaryTap,
  });

  @override
  State<_BookmarkChip> createState() => _BookmarkChipState();
}

class _BookmarkChipState extends State<_BookmarkChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final domain = UrlUtils.getDomain(widget.url).toLowerCase();
    Widget icon = Icon(Icons.language_rounded, size: 14, color: Colors.white70);

    if (domain.contains('google.com')) {
      icon = Icon(Icons.search_rounded, size: 14, color: Color(0xFF4285F4));
    } else if (domain.contains('youtube.com')) {
      icon = Icon(Icons.play_circle_filled_rounded, size: 14, color: Color(0xFFFF0000));
    } else if (domain.contains('github.com')) {
      icon = Icon(Icons.code_rounded, size: 14, color: Color(0xFF6E40C9));
    } else if (domain.contains('wikipedia.org')) {
      icon = Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFF636466));
    } else if (domain.contains('reddit.com')) {
      icon = Icon(Icons.forum_rounded, size: 14, color: Color(0xFFFF4500));
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) {
          widget.onSecondaryTap(details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered ? Colors.white12 : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
