import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Import thư viện gọi API
import 'diagnosis_result_screen.dart';
import '../api_config.dart';

class DiagnosisPreviewScreen extends StatefulWidget {
  final List<XFile> images; 

  const DiagnosisPreviewScreen({super.key, required this.images});

  @override
  State<DiagnosisPreviewScreen> createState() => _DiagnosisPreviewScreenState();
}

class _DiagnosisPreviewScreenState extends State<DiagnosisPreviewScreen> {
  late List<XFile> _capturedImages;
  int _currentIndex = 0;
  bool _isProcessing = false; // Biến trạng thái để hiển thị loading

  // Lời khai của người nuôi. Rất quan trọng: model chỉ nhìn được ảnh tĩnh nên
  // không thấy được hành vi, tiếng thở hay màu phân - những dấu hiệu phân biệt
  // bệnh rõ nhất. Không có mô tả này AI rất dễ chẩn đoán nhầm.
  final TextEditingController _observationController = TextEditingController();

  // Triệu chứng bấm nhanh, gom theo dấu hiệu đặc trưng của 5 bệnh trong hệ thống.
  static const List<String> _quickSymptoms = [
    'Ngoẹo cổ, đi loạng choạng',
    'Phân xanh hoặc trắng',
    'Phân có lẫn máu tươi',
    'Sưng phù mặt một bên',
    'Chảy nước mũi hôi',
    'Mụn sần ở mào, quanh mắt',
    'Mào tím tái',
    'Thở khò khè, há mỏ',
    'Ủ rũ, xù lông',
    'Bỏ ăn',
    'Chết đột ngột nhiều con',
  ];

  @override
  void initState() {
    super.initState();
    _capturedImages = List.from(widget.images);
    _currentIndex = _capturedImages.length - 1;
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  /// Bấm chip thì chèn triệu chứng vào ô mô tả, bấm lại thì bỏ ra.
  void _toggleSymptom(String symptom) {
    final parts = _observationController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.contains(symptom)) {
      parts.remove(symptom);
    } else {
      parts.add(symptom);
    }

    setState(() {
      _observationController.text = parts.join(', ');
    });
  }

  bool _isSymptomSelected(String symptom) => _observationController.text
      .split(',')
      .map((e) => e.trim())
      .contains(symptom);

  void _takeMorePhotos() {
    if (_capturedImages.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ được tải lên tối đa 8 ảnh!')),
      );
      return;
    }
    Navigator.pop(context, _capturedImages);
  }

  // Luồng gọi API thực tế
  Future<void> _submitForDiagnosis() async {
    // Ẩn SnackBar cũ nếu có
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // Bật trạng thái loading
    setState(() {
      _isProcessing = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang tải ảnh và phân tích AI...'),
        backgroundColor: Colors.blue,
        duration: Duration(minutes: 5), // Để thời gian dài, sẽ tự ẩn khi có kết quả
      ),
    );

    try {
      final uri = Uri.parse(ApiConfig.analyzePoultry);
      var request = http.MultipartRequest('POST', uri);

      // (Tùy chọn) Gửi thêm thông tin loài gia cầm
      request.fields['poultryType'] = 'Gà';

      // Lời khai người nuôi - backend đặt đoạn này ở cuối prompt vì model
      // ưu tiên phần cuối, nhờ vậy chẩn đoán bám theo triệu chứng thực tế.
      request.fields['observation'] = _observationController.text.trim();

      // Đính kèm danh sách ảnh
      for (var image in _capturedImages) {
        request.files.add(
          await http.MultipartFile.fromPath('images', image.path),
        );
      }

      // Gửi request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Tắt SnackBar loading
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> realScanData = responseData['data'];

        if (mounted) {
          // Chuyển sang màn hình kết quả và truyền dữ liệu JSON thật
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DiagnosisResultScreen(
                capturedImages: _capturedImages,
                scanData: realScanData, 
              ),
            ),
          );
        }
      } else {
        throw Exception('Lỗi Server: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối AI: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        // Tắt trạng thái loading
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Ô nhập triệu chứng người nuôi quan sát được.
  Widget _buildObservationSection(ColorScheme colorScheme) {
    final isEmpty = _observationController.text.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bạn quan sát thấy gì?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ảnh chỉ ghi lại một khoảnh khắc, không thấy được dáng đi, tiếng thở hay màu phân. '
            'Mô tả của bạn giúp AI chẩn đoán chính xác hơn nhiều.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          // Chip bấm nhanh cho các triệu chứng thường gặp.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickSymptoms.map((symptom) {
              final selected = _isSymptomSelected(symptom);
              return FilterChip(
                label: Text(symptom, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: _isProcessing ? null : (_) => _toggleSymptom(symptom),
                showCheckmark: false,
                avatar: Icon(
                  selected ? Icons.check_circle : Icons.add_circle_outline,
                  size: 16,
                  color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                selectedColor: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.25)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _observationController,
            enabled: !_isProcessing,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Ví dụ: gà ngoẹo cổ, đi loạng choạng, phân xanh trắng, bỏ ăn 2 ngày...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),

          if (isEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chưa có mô tả nên AI chỉ dựa vào ảnh, kết quả dễ nhầm và độ tin cậy sẽ bị hạ thấp.',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
          // Bấm nút back thì khóa lại nếu đang xử lý AI
          onPressed: _isProcessing ? null : () => Navigator.pop(context, _capturedImages), 
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
                            image: _capturedImages.isNotEmpty 
                                ? DecorationImage(
                                    image: FileImage(File(_capturedImages[_currentIndex].path)),
                                    fit: BoxFit.cover,
                                  ) 
                                : null,
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
                          onTap: _isProcessing ? null : _takeMorePhotos, 
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
                        onTap: _isProcessing ? null : () {
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
                _buildObservationSection(colorScheme),
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
                      onPressed: _isProcessing ? null : _takeMorePhotos,
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
                      // Khóa nút nếu chưa có ảnh hoặc đang xử lý
                      onPressed: (_capturedImages.isNotEmpty && !_isProcessing) 
                          ? _submitForDiagnosis 
                          : null,
                      // Thay icon thành thanh loading khi đang xử lý
                      icon: _isProcessing 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : const Text('Hoàn tất'),
                      label: _isProcessing ? const SizedBox.shrink() : const Icon(Icons.arrow_forward),
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