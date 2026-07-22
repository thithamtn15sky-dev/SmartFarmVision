import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; 
import 'package:image_picker/image_picker.dart'; // Thêm thư viện chọn ảnh
import 'diagnosis_preview_screen.dart';
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  int _selectedCameraIndex = 0;
  final ImagePicker _picker = ImagePicker(); // Khởi tạo ImagePicker
  List<XFile> _capturedImages = [];

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        await _initCameraController(_cameras![_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint("Lỗi lấy danh sách camera: $e");
    }
  }

  Future<void> _initCameraController(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      debugPrint("Lỗi khởi tạo hoặc người dùng từ chối quyền camera: $e");
    }
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    setState(() {
      _isReady = false;
    });
    await _initCameraController(_cameras![_selectedCameraIndex]);
  }

  // Hàm mở thư viện ảnh
  Future<void> _openGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        debugPrint("Đã chọn ảnh từ thư viện: ${image.path}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tải ảnh lên từ thư viện!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi khi mở thư viện ảnh: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_isReady && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize?.height ?? 1,
                  height: _controller!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.green)),

          // Gradient
          Positioned(
            top: 0, left: 0, right: 0, height: 160,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 250,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // 2. Thanh công cụ phía trên
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGlassButton(Icons.flash_on, colorScheme),
                
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.center_focus_strong, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Đặt vật nuôi vào trung\ntâm khung hình',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                _buildGlassButton(Icons.cameraswitch, colorScheme, onTap: _switchCamera),
              ],
            ),
          ),

          // 3. Khung lấy nét ở giữa
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: SizedBox(
                width: 280,
                height: 280,
                child: CustomPaint(
                  painter: ViewfinderPainter(color: colorScheme.primary),
                ),
              ),
            ),
          ),

          // 4. Các nút điều khiển phía dưới
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Nút Mở Thư Viện Ảnh (Gallery)
                      GestureDetector(
                        onTap: _openGallery,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 2),
                            color: Colors.grey[800],
                          ),
                          child: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                        ),
                      ),

                      // Nút Chụp Ảnh
                      GestureDetector(
                        onTap: () async {
                          if (_isReady && _controller != null && _controller!.value.isInitialized) {
                            try {
                              final XFile image = await _controller!.takePicture();
                              debugPrint("Đã chụp ảnh tại: ${image.path}");
                              
                              if (context.mounted) {
                                // CHUYỂN HƯỚNG VÀ TRUYỀN ẢNH VỪA CHỤP SANG MÀN HÌNH PREVIEW
                                final result = await Navigator.push<List<XFile>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DiagnosisPreviewScreen(images: [..._capturedImages, image]),
                                  ),
                                );
                                if (result != null) {
                                  setState(() {
                                    _capturedImages = result;
                                  });
                                }
                              }
                            } catch (e) {
                              debugPrint("Lỗi chụp ảnh: $e");
                            }
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary, // Màu xanh đậm như trong ảnh
                              ),
                              child: const Icon(
                                Icons.photo_camera,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 56, height: 56), // Cân bằng không gian
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

                // Nút "Chụp ảnh" đơn giản, bỏ Video và QR
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      color: Colors.black45, // Nền tối như ảnh cung cấp
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Chụp ảnh',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 1, 
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context); 
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

  Widget _buildGlassButton(IconData icon, ColorScheme colorScheme, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 48,
            height: 48,
            color: colorScheme.surface.withValues(alpha: 0.2),
            child: Icon(icon, color: colorScheme.onPrimary),
          ),
        ),
      ),
    );
  }
}

// Lớp vẽ khung lấy nét
class ViewfinderPainter extends CustomPainter {
  final Color color;

  ViewfinderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cornerLength = 32.0;

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)), borderPaint);

    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(Offset(w / 3, 0), Offset(w / 3, h), gridPaint);
    canvas.drawLine(Offset(w * 2 / 3, 0), Offset(w * 2 / 3, h), gridPaint);
    canvas.drawLine(Offset(0, h / 3), Offset(w, h / 3), gridPaint);
    canvas.drawLine(Offset(0, h * 2 / 3), Offset(w, h * 2 / 3), gridPaint);

    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    var pathTL = Path()..moveTo(0, cornerLength)..lineTo(0, 24)..quadraticBezierTo(0, 0, 24, 0)..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, cornerPaint);

    var pathTR = Path()..moveTo(w - cornerLength, 0)..lineTo(w - 24, 0)..quadraticBezierTo(w, 0, w, 24)..lineTo(w, cornerLength);
    canvas.drawPath(pathTR, cornerPaint);

    var pathBL = Path()..moveTo(0, h - cornerLength)..lineTo(0, h - 24)..quadraticBezierTo(0, h, 24, h)..lineTo(cornerLength, h);
    canvas.drawPath(pathBL, cornerPaint);

    var pathBR = Path()..moveTo(w, h - cornerLength)..lineTo(w, h - 24)..quadraticBezierTo(w, h, w - 24, h)..lineTo(w - cornerLength, h);
    canvas.drawPath(pathBR, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}