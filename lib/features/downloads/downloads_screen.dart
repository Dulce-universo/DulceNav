// ============================================================
// DulceNav — downloads_screen.dart
// Panel lateral (Drawer) de descargas con diseno glassmorphism.
// Solo caracteres ASCII en el codigo fuente.
// ============================================================

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/download_manager.dart';

class DulceDownloadsDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const DulceDownloadsDrawer({
    super.key,
    required this.onClose,
  });

  String _formatTimestamp(DateTime dt) {
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${pad(dt.hour)}:${pad(dt.minute)} - ${pad(dt.day)}/${pad(dt.month)}/${dt.year}';
  }

  String _getDomainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isEmpty ? url : uri.host;
    } catch (_) {
      return url;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completado':
        return DulceColors.safeGreen;
      case 'Error':
        return DulceColors.dangerRed;
      case 'Pausado':
        return DulceColors.textDisabled;
      case 'Cancelado':
        return Colors.orangeAccent;
      default:
        return DulceColors.primary; // Descargando...
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width * 0.40;
    final downloadManager = context.watch<DownloadManager>();
    final downloads = downloadManager.items;

    return Drawer(
      width: width > 350 ? width : 350,
      backgroundColor: Colors.transparent, // Required for glassmorphism
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12121A).withOpacity(0.85),
              border: Border(
                left: BorderSide(
                  color: DulceColors.primary.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Cabecera del panel de descargas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, color: DulceColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Gestor de descargas',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: DulceColors.textSecondary, size: 20),
                          onPressed: onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  // Lista de descargas
                  Expanded(
                    child: downloads.isEmpty
                        ? Center(
                            child: Text(
                              'No hay descargas registradas',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: DulceColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: downloads.length,
                            itemBuilder: (context, index) {
                              final item = downloads[index];
                              final statusColor = _getStatusColor(item.status);
                              final domain = _getDomainFromUrl(item.url);

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E2E).withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: DulceColors.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Fila superior: Nombre de archivo e icono de estado
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.description_outlined,
                                            color: Colors.white70,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.fileName,
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  domain,
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 10,
                                                    color: DulceColors.textDisabled,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Badge de estado
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: statusColor.withOpacity(0.4)),
                                            ),
                                            child: Text(
                                              item.status,
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Barra de progreso y texto de descarga en tiempo real
                                      if (item.status == 'Descargando...' || item.status == 'Pausado') ...[
                                        LinearProgressIndicator(
                                          value: item.progress,
                                          backgroundColor: Colors.white.withOpacity(0.08),
                                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${item.downloadedSize} de ${item.totalSize}',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 10,
                                                color: DulceColors.textSecondary,
                                              ),
                                            ),
                                            if (item.status == 'Descargando...')
                                              Text(
                                                item.speed,
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 10,
                                                  color: DulceColors.accent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ] else ...[
                                        // Tamano completo y fecha
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              item.totalSize,
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: DulceColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              _formatTimestamp(item.timestamp),
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 9,
                                                color: DulceColors.textDisabled,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),

                                      // Fila de botones de accion
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (item.status == 'Descargando...') ...[
                                            _ActionButton(
                                              icon: Icon(Icons.pause_rounded),
                                              label: 'Pausar',
                                              onTap: () => downloadManager.pauseDownload(item.id),
                                            ),
                                            const SizedBox(width: 8),
                                            _ActionButton(
                                              icon: Icon(Icons.close_rounded),
                                              label: 'Cancelar',
                                              color: DulceColors.dangerRed,
                                              onTap: () => downloadManager.cancelDownload(item.id),
                                            ),
                                          ] else if (item.status == 'Completado') ...[
                                            _ActionButton(
                                              icon: Icon(Icons.launch_rounded),
                                              label: 'Abrir',
                                              color: DulceColors.safeGreen,
                                              onTap: () => downloadManager.openFile(item),
                                            ),
                                            const SizedBox(width: 8),
                                            _ActionButton(
                                              icon: Icon(Icons.folder_open_rounded),
                                              label: 'Carpeta',
                                              onTap: () => downloadManager.openFolder(item),
                                            ),
                                            const SizedBox(width: 8),
                                            _ActionButton(
                                              icon: Icon(Icons.delete_outline_rounded),
                                              label: 'Quitar',
                                              color: DulceColors.textDisabled,
                                              onTap: () => downloadManager.deleteDownload(item.id),
                                            ),
                                          ] else ...[
                                            // Pausado, Error, Cancelado
                                            _ActionButton(
                                              icon: Icon(Icons.play_arrow_rounded),
                                              label: 'Reanudar',
                                              onTap: () => downloadManager.resumeDownload(item.id),
                                            ),
                                            const SizedBox(width: 8),
                                            _ActionButton(
                                              icon: Icon(Icons.delete_outline_rounded),
                                              label: 'Quitar',
                                              color: DulceColors.textDisabled,
                                              onTap: () => downloadManager.deleteDownload(item.id),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? DulceColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: themeColor.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(size: 14, color: themeColor),
                child: icon,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
