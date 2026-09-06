import 'package:flutter/material.dart';

import '../colors.dart';
import '../models/coop.dart';
import '../services/vaccination_service.dart';
import '../utils/date_format.dart';

/// Chi tiết 1 chuồng: lịch sử tiêm, mũi kế tiếp, cảnh báo hiệu lực.
class CoopDetailScreen extends StatefulWidget {
  final String coopId;
  final String? coopName;

  const CoopDetailScreen({super.key, required this.coopId, this.coopName});

  @override
  State<CoopDetailScreen> createState() => _CoopDetailScreenState();
}

class _CoopDetailScreenState extends State<CoopDetailScreen> {
  final VaccinationService _service = VaccinationService();
  late Future<CoopDashboard> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchCoopDashboard(widget.coopId);
  }

  Future<void> _reload() async {
    final future = _service.fetchCoopDashboard(widget.coopId);
    // Dùng thân khối: `() => _future = future` trả về chính Future vừa gán,
    // mà setState cấm callback trả về Future (sẽ ném FlutterError không ai bắt).
    setState(() {
      _future = future;
    });
    // Chờ xong để RefreshIndicator giữ vòng xoay đúng thời lượng, nhưng KHÔNG
    // ném lại lỗi: FutureBuilder đã hiển thị lỗi rồi. Trước đây chỗ này ném lại
    // nên RefreshIndicator và _confirmInjection nhận exception không ai bắt,
    // khiến app báo lỗi dù mũi tiêm đã ghi nhận thành công.
    try {
      await future;
    } catch (_) {
      // đã có FutureBuilder lo phần hiển thị
    }
  }

  Future<void> _confirmInjection(VaccinationRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận đã tiêm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.vaccineName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Chuồng: ${widget.coopName ?? widget.coopId}'),
            Text('Ngày dự kiến: ${formatDate(record.scheduledDate)}'),
            if (record.method != null) Text('Cách cấp: ${record.method}'),
            const SizedBox(height: 12),
            const Text(
              'Thao tác này sẽ ghi nhận mũi tiêm lên hệ thống và không thể hoàn tác trong app.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AgriTechColors.primary,
              foregroundColor: AgriTechColors.onPrimary,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final message = await _service.markVaccineCompleted(
        coopId: widget.coopId,
        vaccineId: record.vaccineId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AgriTechColors.primary),
      );
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: Text(
          widget.coopName ?? 'Chi tiết chuồng',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: FutureBuilder<CoopDashboard>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DetailErrorState(message: snapshot.error.toString(), onRetry: _reload);
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            color: AgriTechColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _HeaderCard(data: data),
                const SizedBox(height: 16),
                _StatusMessages(data: data),
                const SizedBox(height: 16),
                if (data.nextVaccine != null)
                  _NextVaccineCard(
                    record: data.nextVaccine!,
                    submitting: _submitting,
                    onConfirm: () => _confirmInjection(data.nextVaccine!),
                  )
                else
                  const _AllDoneCard(),
                const SizedBox(height: 24),
                Text(
                  'PHÁC ĐỒ TIÊM PHÒNG (${data.totalCompleted}/${data.totalRequired})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(data.records.length, (index) {
                  final record = data.records[index];
                  return _RecordTile(
                    record: record,
                    isLast: index == data.records.length - 1,
                    submitting: _submitting,
                    onConfirm: record.isCompleted ? null : () => _confirmInjection(record),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final CoopDashboard data;

  const _HeaderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AgriTechColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        color: AgriTechColors.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.id} • ${data.quantity} ${data.species.toLowerCase()} • ${data.ageDays} ngày tuổi',
                      style: TextStyle(
                        color: AgriTechColors.onPrimary.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _SafetyGauge(score: data.safetyScore),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: data.totalRequired == 0 ? 0 : data.totalCompleted / data.totalRequired,
              minHeight: 8,
              backgroundColor: AgriTechColors.onPrimary.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(AgriTechColors.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã tiêm ${data.totalCompleted}/${data.totalRequired} mũi (${data.progressPercent}%)',
                style: TextStyle(
                  color: AgriTechColors.onPrimary.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
              Text(
                'Vào đàn ${formatDate(data.flockStartDate)}',
                style: TextStyle(
                  color: AgriTechColors.onPrimary.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SafetyGauge extends StatelessWidget {
  final int score;

  const _SafetyGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              backgroundColor: AgriTechColors.onPrimary.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(AgriTechColors.onPrimaryContainer),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: AgriTechColors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              Text(
                'an toàn',
                style: TextStyle(
                  color: AgriTechColors.onPrimary.withValues(alpha: 0.8),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 3 câu trả lời nghiệp vụ backend tính sẵn:
/// đã tiêm chưa - mũi gần nhất còn hiệu lực không - tiếp theo tiêm gì.
class _StatusMessages extends StatelessWidget {
  final CoopDashboard data;

  const _StatusMessages({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEffectivenessWarning = data.effectivenessMsg.contains('CẢNH BÁO');
    final isNextOverdue = data.nextActionMsg.contains('QUÁ HẠN');

    return Column(
      children: [
        _MessageRow(
          icon: Icons.fact_check_outlined,
          color: AgriTechColors.primary,
          text: data.statusMsg,
        ),
        const SizedBox(height: 10),
        _MessageRow(
          icon: isEffectivenessWarning ? Icons.timer_off_outlined : Icons.timelapse,
          color: isEffectivenessWarning ? colorScheme.error : AgriTechColors.secondary,
          text: data.effectivenessMsg,
        ),
        const SizedBox(height: 10),
        _MessageRow(
          icon: isNextOverdue ? Icons.warning_amber_rounded : Icons.event_available,
          color: isNextOverdue ? colorScheme.error : AgriTechColors.primary,
          text: data.nextActionMsg,
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _MessageRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Dải màu đặt lùi vào trong và tự bo tròn, thay cho Border(left:) kèm
    // borderRadius - cách đó vẽ ra hình "ngoặc đơn" cong ở 4 góc trông rất lạ.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextVaccineCard extends StatelessWidget {
  final VaccinationRecord record;
  final bool submitting;
  final VoidCallback onConfirm;

  const _NextVaccineCard({
    required this.record,
    required this.submitting,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLate = record.isOverdue;
    // accent: màu đậm dùng cho nút/chip (nằm trên nền sáng).
    final accent = isLate ? colorScheme.error : AgriTechColors.primary;
    // onContainer: màu chữ nằm TRÊN nền container, phải tương phản với nền đó.
    final onContainer = isLate ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLate ? colorScheme.errorContainer : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isLate ? Icons.priority_high : Icons.vaccines, color: onContainer, size: 20),
              const SizedBox(width: 8),
              Text(
                isLate ? 'MŨI QUÁ HẠN CẦN TIÊM NGAY' : 'MŨI TIÊM KẾ TIẾP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: onContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            record.vaccineName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isLate ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
            ),
          ),
          if (record.diseasePrevented != null) ...[
            const SizedBox(height: 4),
            Text(
              'Phòng: ${record.diseasePrevented}',
              style: TextStyle(
                fontSize: 13,
                color: (isLate ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer)
                    .withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.event,
                label: '${formatDate(record.scheduledDate)} (${describeDueDays(record.daysUntilDue)})',
                color: accent,
              ),
              if (record.standardTiming != null)
                _InfoChip(icon: Icons.schedule, label: record.standardTiming!, color: accent),
              if (record.method != null)
                _InfoChip(icon: Icons.medical_services_outlined, label: record.method!, color: accent),
            ],
          ),
          if (record.note != null) ...[
            const SizedBox(height: 12),
            Text(
              'Lưu ý: ${record.note}',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: (isLate ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer)
                    .withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : onConfirm,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(submitting ? 'Đang ghi nhận...' : 'Xác nhận đã tiêm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.verified, size: 40, color: colorScheme.onPrimaryContainer),
          const SizedBox(height: 10),
          Text(
            'Chuồng đã tiêm đủ phác đồ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Không còn mũi nào đến hạn.',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1 dòng trong timeline phác đồ, bấm để mở chi tiết vắc-xin.
class _RecordTile extends StatelessWidget {
  final VaccinationRecord record;
  final bool isLast;
  final bool submitting;
  final VoidCallback? onConfirm;

  const _RecordTile({
    required this.record,
    required this.isLast,
    required this.submitting,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visual = _visualFor(record, colorScheme);

    // Dùng Stack thay cho IntrinsicHeight: ExpansionTile báo sai chiều cao nội tại
    // khi subtitle xuống dòng, gây lỗi "BOTTOM OVERFLOWED BY 3.0 PIXELS".
    // Ở đây đường nối là Positioned nên tự giãn theo chiều cao thật của thẻ.
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 14,
            top: 15,
            bottom: 0,
            width: 2,
            child: ColoredBox(color: colorScheme.outline.withValues(alpha: 0.25)),
          ),
        Padding(
          padding: EdgeInsets.only(left: 42, bottom: isLast ? 0 : 12),
          child: SizedBox(
            width: double.infinity,
            child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Theme(
                  // Bỏ đường kẻ mặc định của ExpansionTile cho gọn.
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      record.vaccineName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        visual.subtitle,
                        style: TextStyle(fontSize: 12, color: visual.subtitleColor),
                      ),
                    ),
                    children: [
                      if (record.diseasePrevented != null)
                        _DetailRow(label: 'Phòng bệnh', value: record.diseasePrevented!),
                      if (record.standardTiming != null)
                        _DetailRow(label: 'Thời điểm chuẩn', value: record.standardTiming!),
                      _DetailRow(label: 'Ngày dự kiến', value: formatDate(record.scheduledDate)),
                      if (record.method != null)
                        _DetailRow(label: 'Cách cấp', value: record.method!),
                      if (record.isCompleted) ...[
                        _DetailRow(label: 'Đã tiêm lúc', value: formatDateTime(record.completedAt)),
                        if (record.administeredBy != null)
                          _DetailRow(label: 'Người tiêm', value: record.administeredBy!),
                        _DetailRow(
                          label: 'Hiệu lực đến',
                          value:
                              '${formatDate(record.effectiveUntil)} (${record.effectivenessDays} ngày)',
                        ),
                      ],
                      if (record.note != null)
                        _DetailRow(label: 'Lưu ý', value: record.note!, italic: true),
                      if (onConfirm != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: submitting ? null : onConfirm,
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Xác nhận đã tiêm mũi này'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AgriTechColors.primary,
                              side: const BorderSide(color: AgriTechColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Chấm trạng thái vẽ đè lên đường nối.
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: visual.dotColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(visual.icon, size: 16, color: visual.onDotColor),
        ),
      ],
    );
  }

  _RecordVisual _visualFor(VaccinationRecord record, ColorScheme colorScheme) {
    if (record.isCompleted) {
      final expired = record.isExpired;
      return _RecordVisual(
        dotColor: AgriTechColors.primary,
        onDotColor: AgriTechColors.onPrimary,
        icon: Icons.check,
        subtitle: expired
            ? 'Đã tiêm ${formatDate(record.completedAt)} • hết hiệu lực ${(record.daysOfEffectRemaining ?? 0).abs()} ngày trước'
            : 'Đã tiêm ${formatDate(record.completedAt)} • còn hiệu lực ${record.daysOfEffectRemaining ?? 0} ngày',
        subtitleColor: expired
            ? colorScheme.error
            : colorScheme.onSurface.withValues(alpha: 0.7),
      );
    }

    if (record.isOverdue) {
      return _RecordVisual(
        dotColor: colorScheme.error,
        onDotColor: colorScheme.onError,
        icon: Icons.priority_high,
        subtitle:
            'Quá hạn ${record.daysUntilDue.abs()} ngày • dự kiến ${formatDate(record.scheduledDate)}',
        subtitleColor: colorScheme.error,
      );
    }

    return _RecordVisual(
      dotColor: colorScheme.surfaceContainerHighest,
      onDotColor: colorScheme.onSurface.withValues(alpha: 0.6),
      icon: Icons.schedule,
      subtitle:
          'Chưa tiêm • dự kiến ${formatDate(record.scheduledDate)} (${describeDueDays(record.daysUntilDue)})',
      subtitleColor: colorScheme.onSurface.withValues(alpha: 0.7),
    );
  }
}

class _RecordVisual {
  final Color dotColor;
  final Color onDotColor;
  final IconData icon;
  final String subtitle;
  final Color subtitleColor;

  const _RecordVisual({
    required this.dotColor,
    required this.onDotColor,
    required this.icon,
    required this.subtitle,
    required this.subtitleColor,
  });
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool italic;

  const _DetailRow({required this.label, required this.value, this.italic = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _DetailErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 52, color: colorScheme.error),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AgriTechColors.primary,
                foregroundColor: AgriTechColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
