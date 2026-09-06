import 'package:flutter/material.dart';

import '../colors.dart';
import '../models/coop.dart';
import '../services/vaccination_service.dart';
import 'add_coop_screen.dart';
import '../utils/date_format.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'coop_detail_screen.dart';

class CoopsScreen extends StatefulWidget {
  const CoopsScreen({super.key});

  @override
  State<CoopsScreen> createState() => _CoopsScreenState();
}

class _CoopsScreenState extends State<CoopsScreen> with SingleTickerProviderStateMixin {
  final VaccinationService _service = VaccinationService();
  late Future<List<CoopSummary>> _future;
  late final TabController _tabController;
  bool _harvesting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _service.fetchCoops();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Bấm xuất chuồng: hỏi lại số con thực xuất rồi đóng lứa.
  /// Sau khi xuất, chuồng tự chuyển sang tab "Đã xuất chuồng".
  Future<void> _harvest(CoopSummary coop) async {
    final harvest = coop.harvest;
    final controller = TextEditingController(
      text: (harvest?.currentQuantity ?? coop.quantity).toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xuất chuồng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(coop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Vào đàn ${harvest?.initialQuantity ?? coop.quantity} con'),
            const SizedBox(height: 14),
            const Text('Số con thực xuất:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sau khi xuất, chuồng sẽ chuyển sang tab "Đã xuất chuồng" và không nhận thêm mũi tiêm.',
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
            child: const Text('Xuất chuồng'),
          ),
        ],
      ),
    );

    final soCon = int.tryParse(controller.text.trim());
    controller.dispose();
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _harvesting = true;
    });
    try {
      final message = await _service.harvestCoop(
        coopId: coop.id,
        finalQuantity: soCon,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AgriTechColors.primary),
      );
      await _reload();
      if (mounted) _tabController.animateTo(1);
    } on ApiException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _harvesting = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    final future = _service.fetchCoops();
    // Dùng thân khối: `() => _future = future` trả về chính Future vừa gán,
    // mà setState cấm callback trả về Future (sẽ ném FlutterError không ai bắt).
    setState(() {
      _future = future;
    });
    // Chờ request xong để RefreshIndicator giữ vòng xoay đúng thời lượng.
    await future.catchError((_) => <CoopSummary>[]);
  }

  Future<void> _openDetail(CoopSummary coop) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CoopDetailScreen(coopId: coop.id, coopName: coop.name)),
    );
    // Quay lại từ màn chi tiết: tải lại để cập nhật mũi vừa xác nhận tiêm.
    if (mounted) _reload();
  }

  Future<void> _openAddCoop() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddCoopScreen()),
    );
    // Chỉ tải lại khi thật sự có chuồng mới được tạo.
    if (created == true && mounted) _reload();
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
          'Quản lý chuồng trại',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: _reload,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AgriTechColors.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: AgriTechColors.primary,
          tabs: const [
            Tab(text: 'Đang nuôi'),
            Tab(text: 'Đã xuất chuồng'),
          ],
        ),
      ),
      body: FutureBuilder<List<CoopSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString(), onRetry: _reload);
          }

          final coops = snapshot.data ?? const <CoopSummary>[];
          if (coops.isEmpty) {
            return _EmptyState(onRetry: _reload);
          }

          // Tách theo trạng thái: chuồng đã xuất không còn nằm chung
          // với đàn đang nuôi nữa.
          final dangNuoi =
              coops.where((c) => !(c.harvest?.isHarvested ?? false)).toList();
          final daXuat =
              coops.where((c) => c.harvest?.isHarvested ?? false).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _CoopList(
                coops: dangNuoi,
                onReload: _reload,
                onOpen: _openDetail,
                onHarvest: _harvesting ? null : _harvest,
                showBanner: true,
                emptyText: 'Không còn đàn nào đang nuôi.',
              ),
              _CoopList(
                coops: daXuat,
                onReload: _reload,
                onOpen: _openDetail,
                onHarvest: null,
                showBanner: false,
                emptyText: 'Chưa có lứa nào được xuất chuồng.',
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCoop,
        backgroundColor: AgriTechColors.primary,
        foregroundColor: AgriTechColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Thêm chuồng'),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentTab: AppTab.coops),
    );
  }
}

/// Dải tổng quan: tổng đàn, số chuồng đang trễ lịch tiêm.
class _OverviewBanner extends StatelessWidget {
  final List<CoopSummary> coops;

  const _OverviewBanner({required this.coops});

  @override
  Widget build(BuildContext context) {
    final totalBirds = coops.fold<int>(0, (sum, c) => sum + c.quantity);
    final overdueCoops = coops.where((c) => c.hasOverdue).length;
    final doneCoops = coops.where((c) => c.isFullyVaccinated).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AgriTechColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BannerStat(
              value: '${coops.length}',
              label: 'Chuồng',
              icon: Icons.holiday_village_rounded,
            ),
          ),
          _bannerDivider(),
          Expanded(
            child: _BannerStat(
              value: _formatCount(totalBirds),
              label: 'Tổng đàn',
              icon: Icons.pets,
            ),
          ),
          _bannerDivider(),
          Expanded(
            child: _BannerStat(
              value: '$overdueCoops',
              label: overdueCoops > 0 ? 'Trễ lịch' : 'Đủ lịch',
              icon: overdueCoops > 0 ? Icons.warning_amber_rounded : Icons.verified,
              highlight: overdueCoops > 0,
              subtitle: overdueCoops == 0 ? '$doneCoops chuồng xong' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerDivider() => Container(
        width: 1,
        height: 42,
        color: AgriTechColors.onPrimary.withValues(alpha: 0.2),
      );

  static String _formatCount(int value) {
    if (value < 1000) return '$value';
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands.truncateToDouble() == thousands ? 0 : 1)}k';
  }
}

class _BannerStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool highlight;
  final String? subtitle;

  const _BannerStat({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AgriTechColors.secondaryContainer : AgriTechColors.onPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          subtitle ?? label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CoopCard extends StatelessWidget {
  final CoopSummary coop;
  final VoidCallback onTap;
  // Null khi chuồng đã xuất hoặc chưa tới lứa - lúc đó không hiện nút.
  final VoidCallback? onHarvest;

  const _CoopCard({required this.coop, required this.onTap, this.onHarvest});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      coop.species.toLowerCase().contains('vịt') ? Icons.water_drop : Icons.egg,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coop.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${coop.id} • ${coop.quantity} ${coop.species.toLowerCase()} • ${coop.ageDays} ngày tuổi',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(coop: coop),
                ],
              ),
              const SizedBox(height: 16),
              _VaccinationProgress(coop: coop),
              const SizedBox(height: 14),
              _NextVaccineLine(coop: coop),
              if (coop.harvest != null && coop.harvest!.hasSchedule) ...[
                const SizedBox(height: 10),
                _HarvestLine(harvest: coop.harvest!),
              ],
              // Chỉ mời xuất chuồng khi đàn đã tới lứa, tránh bấm nhầm giữa lứa.
              if (onHarvest != null && (coop.harvest?.canHarvest ?? false)) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onHarvest,
                    style: FilledButton.styleFrom(
                      backgroundColor: AgriTechColors.primary,
                      foregroundColor: AgriTechColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text('Xuất chuồng'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final CoopSummary coop;

  const _StatusBadge({required this.coop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    late final String label;
    late final Color background;
    late final Color foreground;

    if (coop.hasOverdue) {
      label = 'Trễ ${coop.overdueCount} mũi';
      background = colorScheme.errorContainer;
      foreground = colorScheme.onErrorContainer;
    } else if (coop.isFullyVaccinated) {
      label = 'Đủ mũi';
      background = colorScheme.primaryContainer;
      foreground = colorScheme.onPrimaryContainer;
    } else {
      label = 'Đang tiêm';
      background = colorScheme.secondaryContainer;
      foreground = colorScheme.onSecondaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: foreground),
      ),
    );
  }
}

class _VaccinationProgress extends StatelessWidget {
  final CoopSummary coop;

  const _VaccinationProgress({required this.coop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = coop.hasOverdue ? colorScheme.error : AgriTechColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tiến độ tiêm phòng',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            Row(
              children: [
                Text(
                  '${coop.totalCompleted}/${coop.totalRequired} mũi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.shield_moon_outlined, size: 14, color: _safetyColor(coop.safetyScore, colorScheme)),
                const SizedBox(width: 2),
                Text(
                  '${coop.safetyScore}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _safetyColor(coop.safetyScore, colorScheme),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: coop.totalRequired == 0 ? 0 : coop.totalCompleted / coop.totalRequired,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

class _NextVaccineLine extends StatelessWidget {
  final CoopSummary coop;

  const _NextVaccineLine({required this.coop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (coop.isFullyVaccinated) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: AgriTechColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã hoàn thành toàn bộ phác đồ tiêm.',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.75)),
            ),
          ),
        ],
      );
    }

    final days = coop.daysUntilDue ?? 0;
    final isLate = days < 0;
    final color = isLate ? colorScheme.error : colorScheme.onSurface.withValues(alpha: 0.75);
    final timing = isLate
        ? 'trễ ${days.abs()} ngày'
        : (days == 0 ? 'đến hạn hôm nay' : 'còn $days ngày');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isLate ? Icons.error_outline : Icons.vaccines_outlined,
          size: 16,
          color: isLate ? colorScheme.error : AgriTechColors.secondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: color),
              children: [
                const TextSpan(text: 'Mũi kế: '),
                TextSpan(
                  text: coop.nextDueVaccineName ?? coop.nextDueVaccine ?? 'Chưa xác định',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' • ${formatDate(coop.nextDueDate)} ($timing)'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Color _safetyColor(int score, ColorScheme colorScheme) {
  if (score >= 80) return AgriTechColors.primary;
  if (score >= 50) return AgriTechColors.secondary;
  return colorScheme.error;
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 56, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Không tải được danh sách chuồng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AgriTechColors.primary,
                foregroundColor: AgriTechColors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRetry,
      color: AgriTechColors.primary,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.holiday_village_outlined, size: 56, color: colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Chưa có chuồng nào trong hệ thống',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng thông tin xuất chuồng trên thẻ chuồng: tỷ lệ sống + số ngày còn lại.
/// Gà thịt lớn nhanh nên đây là thông tin phải theo dõi hằng ngày, để quá lứa
/// là tốn cám mà giá bán lại giảm.
class _HarvestLine extends StatelessWidget {
  final HarvestInfo harvest;

  const _HarvestLine({required this.harvest});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (harvest.status) {
      HarvestStatus.overdue => (colorScheme.error, Icons.running_with_errors),
      HarvestStatus.ready => (AgriTechColors.primary, Icons.check_circle),
      HarvestStatus.soon => (AgriTechColors.secondary, Icons.hourglass_bottom),
      HarvestStatus.done => (colorScheme.onSurfaceVariant, Icons.inventory_2),
      _ => (colorScheme.onSurfaceVariant, Icons.eco_outlined),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  harvest.breedName ?? 'Chưa gán giống',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'Sống ${harvest.harvestRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: harvest.harvestRate >= 90
                      ? AgriTechColors.primary
                      : colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (harvest.growthPercent != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: harvest.growthPercent! / 100,
                minHeight: 5,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '${harvest.currentQuantity}/${harvest.initialQuantity} con • '
            '${harvest.ageDays}/${harvest.totalGrowDays} ngày tuổi',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            harvest.label,
            style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Danh sách chuồng dùng chung cho cả 2 tab.
class _CoopList extends StatelessWidget {
  final List<CoopSummary> coops;
  final Future<void> Function() onReload;
  final void Function(CoopSummary) onOpen;
  final Future<void> Function(CoopSummary)? onHarvest;
  final bool showBanner;
  final String emptyText;

  const _CoopList({
    required this.coops,
    required this.onReload,
    required this.onOpen,
    required this.onHarvest,
    required this.showBanner,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (coops.isEmpty) {
      // Vẫn bọc scroll để kéo-refresh dùng được cả khi danh sách trống.
      return RefreshIndicator(
        onRefresh: onReload,
        color: AgriTechColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 44, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    emptyText,
                    style: TextStyle(
                        fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final headerCount = showBanner ? 1 : 0;
    return RefreshIndicator(
      onRefresh: onReload,
      color: AgriTechColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        itemCount: coops.length + headerCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (showBanner && index == 0) return _OverviewBanner(coops: coops);
          final coop = coops[index - headerCount];
          return _CoopCard(
            coop: coop,
            onTap: () => onOpen(coop),
            onHarvest: onHarvest == null ? null : () => onHarvest!(coop),
          );
        },
      ),
    );
  }
}
