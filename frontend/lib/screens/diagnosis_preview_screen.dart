import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'diagnosis_result_screen.dart';
class DiagnosisPreviewScreen extends StatefulWidget {
  // Nhận vào 1 danh sách ảnh thay vì chỉ 1 ảnh
  final List<XFile> images; 

  const DiagnosisPreviewScreen({super.key, required this.images});

  @override
  State<DiagnosisPreviewScreen> createState() => _DiagnosisPreviewScreenState();
}

class _DiagnosisPreviewScreenState extends State<DiagnosisPreviewScreen> {
  late List<XFile> _capturedImages;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Copy danh sách ảnh được truyền từ CameraScreen
    _capturedImages = List.from(widget.images);
    _currentIndex = _capturedImages.length - 1; // Mặc định hiển thị ảnh mới chụp nhất
  }

  // Hàm xử lý khi bấm "Chụp thêm"
  void _takeMorePhotos() {
    if (_capturedImages.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ được tải lên tối đa 8 ảnh!')),
      );
      return;
    }
    // Quay lại màn hình Camera và mang theo danh sách ảnh hiện tại
    Navigator.pop(context, _capturedImages);
  }

  // Xử lý khi hoàn tất
  void _submitForDiagnosis() {
    // Ẩn SnackBar cũ nếu có
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // Hiển thị thông báo đang xử lý
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang phân tích dữ liệu bằng AI...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 1), 
      ),
    );

    // Giả lập thời gian load AI 1 giây, sau đó chuyển màn hình kết quả
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiagnosisResultScreen(
              capturedImages: _capturedImages, // Truyền danh sách ảnh sang đây
            ),
          ),
        );
      }
    });
  }

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
          // Bấm nút back ở trên cùng cũng lưu lại trạng thái ảnh
          onPressed: () => Navigator.pop(context, _capturedImages), 
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'AgriVision • North Pasture',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: colorScheme.onSurfaceVariant),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chẩn đoán AI',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info, color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lưu ý chụp tối thiểu 2 ảnh, khuyến nghị 4 ảnh, tối đa 8 ảnh. Đảm bảo ánh sáng rõ ràng và lấy nét đúng vùng có dấu hiệu bệnh.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: colorScheme.surfaceContainerHighest,
                            image: DecorationImage(
                              image: FileImage(File(_capturedImages[_currentIndex].path)),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: colorScheme.onPrimaryContainer, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Ảnh đạt chất lượng',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'ĐÃ CHỤP (${_capturedImages.length}/8)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _capturedImages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return GestureDetector(
                          onTap: _takeMorePhotos, // Gọi hàm quay về camera
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outline.withValues(alpha: 0.5),
                                style: BorderStyle.solid,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        );
                      }

                      final imageIndex = index - 1;
                      final isSelected = imageIndex == _currentIndex;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentIndex = imageIndex;
                          });
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            image: DecorationImage(
                              image: FileImage(File(_capturedImages[imageIndex].path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: isSelected
                              ? Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: const LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [Colors.black54, Colors.transparent],
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Icon(Icons.check_circle, color: Colors.white, size: 16),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16).copyWith(bottom: 32),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.95),
                border: Border(top: BorderSide(color: colorScheme.surfaceContainerHighest)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takeMorePhotos, // Gọi hàm quay về camera
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Chụp thêm'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: colorScheme.outline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _capturedImages.isNotEmpty ? _submitForDiagnosis : null,
                      icon: const Text('Hoàn tất'),
                      label: const Icon(Icons.arrow_forward),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
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