import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/app_bottom_nav_bar.dart';

class DiagnosisResultScreen extends StatelessWidget {
  final List<XFile> capturedImages;
  // Thêm tham số nhận dữ liệu từ Backend
  final Map<String, dynamic> scanData;

  const DiagnosisResultScreen({
    super.key, 
    required this.capturedImages,
    required this.scanData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- BÓC TÁCH DỮ LIỆU TỪ BACKEND ĐỂ ĐƯA VÀO UI ---
    
    // 1. Thông tin chẩn đoán AI
    final aiDiagnosis = scanData['aiDiagnosis'] ?? {};
    final predictions = aiDiagnosis['predictions'] as List<dynamic>? ?? [];
    final bestPrediction = predictions.isNotEmpty 
        ? predictions[0] 
        : {'diseaseName': 'Chưa xác định', 'confidenceScore': 0.0};
        
    final String diseaseName = bestPrediction['diseaseName'] ?? 'Chưa xác định';
    final double confidence = (bestPrediction['confidenceScore'] ?? 0).toDouble();
    final bool requiresExpertReview = aiDiagnosis['requiresExpertReview'] ?? false;
    
    // Đánh giá mức độ rủi ro dựa trên độ tin cậy và trạng thái
    final String status = scanData['basicInfo']?['currentStatus'] ?? 'Chưa rõ';
    final bool isDanger = status == 'Nguy hiểm' || status == 'Báo động đỏ' || status == 'Cảnh báo';
    final String confidenceLevel = confidence >= 90 ? 'Rất Cao' : (confidence >= 70 ? 'Cao' : 'Trung Bình');

    // 2. Thông tin lâm sàng
    final clinicalFindings = scanData['clinicalFindings'] ?? {};
    final String generalDescription = clinicalFindings['generalDescription'] ?? 'Không có mô tả chung.';
    final List<dynamic> symptoms = clinicalFindings['symptoms'] ?? [];

    // 3. Lời khuyên do model viết dựa trên tài liệu BenhGiaCam (RAG),
    // mỗi mục kèm danh sách URL nguồn đã được đối chiếu với DB.
    // Không tách theo dấu chấm nữa vì nội dung và URL đều chứa dấu chấm,
    // tách ra sẽ băm nát thành hàng chục mảnh vụn.
    final List<_Advice> dieuTri = _parseAdvice(aiDiagnosis['dieuTri']);
    final List<_Advice> phongNgua = _parseAdvice(aiDiagnosis['phongNgua']);
    final List<String> referenceUrls =
        (aiDiagnosis['referenceUrls'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    // Bản ghi cũ (quét trước khi có RAG) không có 3 trường trên, nên vẫn
    // giữ đường lùi: tách câu từ suggestedTreatment như trước.
    final String suggestedTreatmentStr = aiDiagnosis['suggestedTreatment'] ?? 'Cần theo dõi thêm.';
    final List<String> legacySteps = (dieuTri.isEmpty && phongNgua.isEmpty)
        ? suggestedTreatmentStr
            .split('.')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : const [];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kết Quả Dự đoán AI',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: const [
          SizedBox(width: 48), // Cân bằng khoảng trống
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120, top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Gallery hình ảnh cuộn ngang (Giữ nguyên logic dùng ảnh từ Camera)
            if (capturedImages.isNotEmpty)
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: capturedImages.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 250,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                        image: DecorationImage(
                          image: FileImage(File(capturedImages[index].path)),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // 2. Thẻ Cảnh báo bệnh lý (Dữ liệu động)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDanger ? colorScheme.errorContainer : colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDanger 
                            ? colorScheme.error.withValues(alpha: 0.2)
                            : colorScheme.secondary.withValues(alpha: 0.2)
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -10,
                          right: -10,
                          child: Icon(
                            isDanger ? Icons.warning : Icons.health_and_safety,
                            size: 80,
                            color: isDanger 
                                ? colorScheme.onErrorContainer.withValues(alpha: 0.1)
                                : colorScheme.onSecondaryContainer.withValues(alpha: 0.1),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDanger ? 'PHÁT HIỆN BỆNH LÝ' : 'TÌNH TRẠNG HIỆN TẠI',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: isDanger ? colorScheme.error : colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              diseaseName, // Tên bệnh từ Backend
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDanger ? colorScheme.onErrorContainer : colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Độ tin cậy: ${confidence.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: (isDanger ? colorScheme.onErrorContainer : colorScheme.onSecondaryContainer)
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)
                                    ],
                                  ),
                                  child: Text(
                                    confidenceLevel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDanger ? colorScheme.error : colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: confidence / 100, // Giá trị từ 0.0 đến 1.0
                                minHeight: 8,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDanger ? colorScheme.error : colorScheme.secondary
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Quan sát lâm sàng (Dữ liệu động)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.visibility, color: colorScheme.secondary),
                            const SizedBox(width: 12),
                            Text(
                              'Triệu chứng lâm sàng',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(left: BorderSide(
                              color: isDanger ? colorScheme.error : colorScheme.secondary, 
                              width: 4
                            )),
                          ),
                          child: Text(
                            generalDescription, // Mô tả chung từ Backend
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Map danh sách triệu chứng chi tiết
                        if (symptoms.isEmpty)
                           _buildBulletPoint('Không phát hiện triệu chứng bất thường cụ thể.', colorScheme)
                        else
                          ...symptoms.map((symptom) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildBulletPoint(
                                '${symptom['bodyPart']}: ${symptom['condition']}', 
                                colorScheme
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Hướng xử lý (Dữ liệu động, bóc tách thành các Step)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.list_alt, color: colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              isDanger ? 'Hướng xử lý khẩn cấp' : 'Khuyến nghị chăm sóc',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        if (dieuTri.isEmpty && phongNgua.isEmpty && legacySteps.isEmpty)
                          Text('Không có khuyến nghị cụ thể.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant))
                        else if (dieuTri.isEmpty && phongNgua.isEmpty)
                          // Bản ghi cũ chưa có phác đồ RAG
                          ...List.generate(legacySteps.length, (index) {
                            return _StepItem(
                              step: index + 1,
                              title: 'Bước ${index + 1}',
                              description: legacySteps[index],
                              isDanger: isDanger && index == 0,
                              isLast: index == legacySteps.length - 1,
                            );
                          })
                        else ...[
                          if (dieuTri.isNotEmpty)
                            _ProtocolBlock(
                              icon: Icons.medical_services_outlined,
                              title: 'Xử lý & điều trị',
                              accent: isDanger ? colorScheme.error : colorScheme.primary,
                              items: dieuTri,
                            ),
                          if (phongNgua.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _ProtocolBlock(
                              icon: Icons.shield_outlined,
                              title: 'Phòng ngừa',
                              accent: colorScheme.primary,
                              items: phongNgua,
                            ),
                          ],
                          if (referenceUrls.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Tổng hợp từ các nguồn',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: referenceUrls
                                  .map((url) => Container(
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
                                              _prettyHost(url),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Nút hành động
                  if (isDanger) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Gọi API hoặc mở form gửi cảnh báo y tế
                      },
                      icon: const Icon(Icons.emergency),
                      label: const Text('Báo cáo & Cách ly'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (requiresExpertReview)
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Gửi yêu cầu cho Bác sĩ thú y xem xét
                      },
                      icon: const Icon(Icons.how_to_reg),
                      label: const Text('Gửi xác minh chuyên gia'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.secondary,
                        side: BorderSide(color: colorScheme.secondary, width: 2),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentTab: AppTab.camera),
    );
  }

  Widget _buildBulletPoint(String text, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0, right: 12.0),
          child: Icon(Icons.circle, size: 8, color: colorScheme.outline),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// Widget tùy chỉnh giữ nguyên
class _StepItem extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final bool isDanger;
  final bool isLast;

  const _StepItem({
    required this.step,
    required this.title,
    required this.description,
    this.isDanger = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDanger ? colorScheme.error : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  step.toString(),
                  style: TextStyle(
                    color: isDanger ? colorScheme.onError : colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rút gọn URL thành tên miền cho gọn chip nguồn.
String _prettyHost(String url) {
  final host = Uri.tryParse(url)?.host ?? url;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Một khối phác đồ (điều trị hoặc phòng ngừa) lấy từ collection BenhGiaCam.
/// Mỗi mục có đuôi "[Nguồn: url]" nên tách ra hiển thị riêng cho dễ đọc.
class _ProtocolBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final List<_Advice> items;

  const _ProtocolBlock({
    required this.icon,
    required this.title,
    required this.accent,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final item in items) ...[
          _ProtocolItem(advice: item, accent: accent),
          if (item != items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ProtocolItem extends StatelessWidget {
  final _Advice advice;
  final Color accent;

  const _ProtocolItem({required this.advice, required this.accent});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final body = advice.noiDung;
    final source = advice.nguon.map(_prettyHost).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colorScheme.onSurface,
            ),
          ),
          if (source.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.verified_outlined,
                    size: 13, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Tổng hợp từ: $source',
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

/// Một mục lời khuyên: nội dung do model viết + các URL nguồn đã đối chiếu.
class _Advice {
  final String noiDung;
  final List<String> nguon;
  const _Advice(this.noiDung, this.nguon);
}

List<_Advice> _parseAdvice(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((item) {
    final sources = (item['nguon'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return _Advice(item['noiDung']?.toString() ?? '', sources);
  }).where((a) => a.noiDung.isNotEmpty).toList();
}
