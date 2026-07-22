import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DiagnosisResultScreen extends StatelessWidget {
  final List<XFile> capturedImages;

  const DiagnosisResultScreen({super.key, required this.capturedImages});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          SizedBox(width: 48), // Để cân bằng khoảng trống với nút back
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120, top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Gallery hình ảnh cuộn ngang
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
                  // 2. Thẻ Cảnh báo bệnh lý (Bento Style)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
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
                            Icons.warning,
                            size: 80,
                            color: colorScheme.onErrorContainer.withValues(alpha: 0.1),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PHÁT HIỆN BỆNH LÝ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cúm gia cầm (H5N1)',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Độ tin cậy: 94%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
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
                                    'Rất Cao',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: 0.94,
                                minHeight: 8,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Quan sát lâm sàng
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
                              'Quan sát lâm sàng',
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
                            border: Border(left: BorderSide(color: colorScheme.error, width: 4)),
                          ),
                          child: Text(
                            'Chết đột ngột số lượng lớn. Gà sống thở khò khè nặng.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Mào tím tái, phù nề vùng đầu và cổ', colorScheme),
                        const SizedBox(height: 8),
                        _buildBulletPoint('Chân xuất huyết, tụ máu dưới da', colorScheme),
                        const SizedBox(height: 8),
                        _buildBulletPoint('Ủ rũ, bỏ ăn hoàn toàn, giảm đẻ trứng đột ngột', colorScheme),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Hướng xử lý khẩn cấp
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
                              'Hướng xử lý khẩn cấp',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _StepItem(
                          step: 1,
                          title: 'Cách ly đàn ngay lập tức',
                          description: 'Tuyệt đối không di chuyển gia cầm ra khỏi khu vực hiện tại. Phong tỏa chuồng nuôi.',
                          isDanger: true,
                        ),
                        _StepItem(
                          step: 2,
                          title: 'Sát trùng chuồng trại',
                          description: 'Phun thuốc sát trùng liều cao toàn bộ khu vực trong và ngoài chuồng, dụng cụ chăn nuôi.',
                        ),
                        _StepItem(
                          step: 3,
                          title: 'Báo cáo chính quyền',
                          description: 'Liên hệ ngay với cơ quan thú y địa phương để được hướng dẫn lấy mẫu và xử lý.',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Nút hành động
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.emergency),
                    label: const Text('Cảnh báo y tế'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Xác minh chuyên gia'),
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2, // Đang ở màn hình kết quả/cảnh báo -> Active Tab 2 (Alerts)
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        onTap: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst); // Về trang chủ
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Camera'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
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

// Widget tùy chỉnh để vẽ đường nối dọc (Vertical Line)
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