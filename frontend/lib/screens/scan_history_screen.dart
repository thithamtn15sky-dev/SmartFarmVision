import 'package:flutter/material.dart';

import '../colors.dart';
import '../models/scan.dart';
import '../services/vaccination_service.dart';
import 'scan_detail_screen.dart';

/// Lịch sử các lần chẩn đoán ảnh, đọc từ collection poultryscans.
class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final VaccinationService _service = VaccinationService();
  late Future<List<ScanSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchScanHistory();
  }

  Future<void> _reload() async {
    final future = _service.fetchScanHistory();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder lo phần hiển thị lỗi
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Lịch sử chẩn đoán',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<ScanSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off,
              text: 'Không tải được lịch sử.\n${snapshot.error}',
              onRetry: _reload,
            );
          }

          final scans = snapshot.data ?? const [];
          if (scans.isEmpty) {
            return _Message(
              icon: Icons.history,
              text: 'Chưa có lần chẩn đoán nào.\nHãy chụp ảnh gà ở tab Camera.',
              onRetry: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            color: AgriTechColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: scans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ScanCard(
                scan: scans[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanDetailScreen(scanId: scans[index].id),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final ScanSummary scan;
  final VoidCallback onTap;

  const _ScanCard({required this.scan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = scan.isDanger ? colorScheme.error : AgriTechColors.primary;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(url: scan.thumbnail, count: scan.imageCount),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scan.diseaseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${scan.confidenceScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 12, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(scan.scannedAt),
                          style: TextStyle(
                              fontSize: 11.5,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          scan.isDanger
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          size: 12,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            scan.status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: accent),
                          ),
                        ),
                      ],
                    ),
                    if (scan.shortObservation != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        scan.shortObservation!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  final int count;

  const _Thumbnail({required this.url, required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: url == null
                ? _placeholder(colorScheme)
                : Image.network(
                    url!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    // Ảnh lưu theo IP của máy chủ lúc quét; đổi mạng là link cũ hỏng,
                    // nên phải có ảnh thay thế thay vì để vỡ giao diện.
                    errorBuilder: (_, _, _) => _placeholder(colorScheme),
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : _placeholder(colorScheme),
                  ),
          ),
          if (count > 1)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) => Container(
        width: 64,
        height: 64,
        color: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.image_not_supported_outlined,
            size: 22, color: colorScheme.onSurfaceVariant),
      );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Future<void> Function() onRetry;

  const _Message({required this.icon, required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AgriTechColors.primary),
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Không rõ thời gian';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$d/$m/${date.year} $h:$min';
}
