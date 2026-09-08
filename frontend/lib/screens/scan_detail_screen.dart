import 'package:flutter/material.dart';

import '../colors.dart';
import '../services/vaccination_service.dart';

/// Chi tiết một lần chẩn đoán đã lưu: ảnh, lời khai, triệu chứng AI ghi nhận,
/// và phác đồ điều trị/phòng ngừa kèm nguồn tham khảo.
class ScanDetailScreen extends StatefulWidget {
  final String scanId;

  const ScanDetailScreen({super.key, required this.scanId});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  final VaccinationService _service = VaccinationService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchScanDetail(widget.scanId);
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
        title: const Text('Chi tiết chẩn đoán',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Không tải được chi tiết.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }

          final scan = snapshot.data!;
          final ai = (scan['aiDiagnosis'] as Map<String, dynamic>?) ?? const {};
          final clinical =
              (scan['clinicalFindings'] as Map<String, dynamic>?) ?? const {};
          final basic = (scan['basicInfo'] as Map<String, dynamic>?) ?? const {};
          final media = (scan['media'] as Map<String, dynamic>?) ?? const {};

          final images = ((media['imageUrls'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList();
          final predictions =
              ((ai['predictions'] as List<dynamic>?) ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
          final symptoms = ((clinical['symptoms'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
          final dieuTri = _advice(ai['dieuTri']);
          final phongNgua = _advice(ai['phongNgua']);
          final urls = ((ai['referenceUrls'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList();

          final status = basic['currentStatus']?.toString() ?? 'Chưa rõ';
          final isDanger = status == 'Nguy hiểm' || status == 'Cảnh báo';
          final accent = isDanger ? colorScheme.error : AgriTechColors.primary;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (images.isNotEmpty) _ImageStrip(images: images),
              if (images.isNotEmpty) const SizedBox(height: 16),

              _DiagnosisHeader(
                predictions: predictions,
                status: status,
                accent: accent,
                scannedAt: scan['scannedAt']?.toString(),
              ),
              const SizedBox(height: 16),

              if (clinical['generalDescription'] != null)
                _Section(
                  icon: Icons.record_voice_over_outlined,
                  title: 'Lời khai người nuôi',
                  child: Text(
                    clinical['generalDescription'].toString(),
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: colorScheme.onSurface),
                  ),
                ),

              if (symptoms.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(
                  icon: Icons.visibility_outlined,
                  title: 'AI ghi nhận trên ảnh',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: symptoms
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 5, right: 8),
                                    child: Icon(Icons.circle,
                                        size: 6,
                                        color: colorScheme.onSurfaceVariant),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${s['bodyPart'] ?? 'Không rõ'}: ${s['condition'] ?? ''}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: colorScheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],

              if (dieuTri.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(
                  icon: Icons.medical_services_outlined,
                  title: 'Xử lý & điều trị',
                  accent: accent,
                  child: Column(
                    children: dieuTri
                        .map((a) => _AdviceTile(advice: a, accent: accent))
                        .toList(),
                  ),
                ),
              ],

              if (phongNgua.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(
                  icon: Icons.shield_outlined,
                  title: 'Phòng ngừa',
                  accent: AgriTechColors.primary,
                  child: Column(
                    children: phongNgua
                        .map((a) => _AdviceTile(
                            advice: a, accent: AgriTechColors.primary))
                        .toList(),
                  ),
                ),
              ],

              // Bản ghi quét trước khi có RAG chỉ có suggestedTreatment dạng chuỗi.
              if (dieuTri.isEmpty &&
                  phongNgua.isEmpty &&
                  ai['suggestedTreatment'] != null) ...[
                const SizedBox(height: 12),
                _Section(
                  icon: Icons.list_alt,
                  title: 'Khuyến nghị',
                  child: Text(
                    ai['suggestedTreatment'].toString(),
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: colorScheme.onSurface),
                  ),
                ),
              ],

              if (urls.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Tổng hợp từ các nguồn',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: urls
                      .map((u) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link,
                                    size: 13,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 5),
                                Text(
                                  _host(u),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<_Advice> _advice(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      final nguon = ((m['nguon'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      return _Advice(m['noiDung']?.toString() ?? '', nguon);
    }).where((a) => a.noiDung.isNotEmpty).toList();
  }
}

class _Advice {
  final String noiDung;
  final List<String> nguon;
  const _Advice(this.noiDung, this.nguon);
}

class _ImageStrip extends StatelessWidget {
  final List<String> images;

  const _ImageStrip({required this.images});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            images[index],
            width: 230,
            height: 170,
            fit: BoxFit.cover,
            // Link ảnh gắn với IP máy chủ lúc quét, đổi WiFi là hỏng link.
            errorBuilder: (_, _, _) => Container(
              width: 230,
              height: 170,
              color: colorScheme.surfaceContainerHighest,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined,
                      size: 28, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 6),
                  Text('Không tải được ảnh',
                      style: TextStyle(
                          fontSize: 11, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosisHeader extends StatelessWidget {
  final List<Map<String, dynamic>> predictions;
  final String status;
  final Color accent;
  final String? scannedAt;

  const _DiagnosisHeader({
    required this.predictions,
    required this.status,
    required this.accent,
    required this.scannedAt,
  });

  @override
  Widget build(BuildContext context) {
    final top = predictions.isNotEmpty ? predictions.first : null;
    final date = scannedAt == null ? null : DateTime.tryParse(scannedAt!)?.toLocal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            top?['diseaseName']?.toString() ?? 'Chưa xác định',
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Độ tin cậy ${top?['confidenceScore'] ?? 0}% • $status',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (date != null) ...[
            const SizedBox(height: 2),
            Text(
              'Quét lúc ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
          if (predictions.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: predictions
                  .skip(1)
                  .map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${p['diseaseName']} ${p['confidenceScore']}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11.5),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? accent;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = accent ?? colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _AdviceTile extends StatelessWidget {
  final _Advice advice;
  final Color accent;

  const _AdviceTile({required this.advice, required this.accent});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            advice.noiDung,
            style: TextStyle(
                fontSize: 13, height: 1.45, color: colorScheme.onSurface),
          ),
          if (advice.nguon.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(Icons.verified_outlined,
                    size: 12, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Tổng hợp từ: ${advice.nguon.map(_host).join(', ')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _host(String url) {
  final host = Uri.tryParse(url)?.host ?? url;
  return host.startsWith('www.') ? host.substring(4) : host;
}
