import 'package:flutter/material.dart';
import '../theme_notifier.dart';
import 'camera_screen.dart'; // Thêm dòng này vào phần import
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(context),
            const SizedBox(height: 24),
            // ROW chứa 2 ô Action Card có tương tác
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Cân đo & Theo dõi',
                    subtitle: 'Ghi chép cân nặng, tăng trưởng',
                    icon: Icons.scale,
                    backgroundColor: const Color(0xFF2D5A27),
                    textColor: Colors.white,
                    onTap: () {
                      print("Đã bấm vào Cân đo & Theo dõi");
                      // Xử lý sự kiện ở đây (ví dụ: Navigator.push)
                    },
                  ),
                ),
                const SizedBox(width: 16), // Khoảng cách giữa 2 ô
               Expanded(
               child: _ActionCard(
                  title: 'Kiểm tra sức khỏe',
                  subtitle: 'Phát hiện sớm dịch bệnh',
                  icon: Icons.monitor_heart,
                  backgroundColor: const Color(0xFF7A5649),
                  textColor: Colors.white,
                  onTap: () {
                    // Chuyển hướng sang màn hình Camera khi bấm
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CameraScreen()),
                    );
                  },
                ),
                ),
               ],
            ),
            const SizedBox(height: 24),
            _buildHealthDashboard(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      title: Row(
        children: [
          Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'SmartFarm • North Pasture',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, mode, _) {
            return IconButton(
              icon: Icon(
                mode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode,
              ),
              onPressed: () => themeNotifier.value = mode == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.light,
            );
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chào buổi sáng, Quản lý',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hôm nay trang trại của bạn đang hoạt động ổn định.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthDashboard(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sức khỏe theo chuồng',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Xem tất cả',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _PenCard(
          title: 'Chuồng Gà A',
          location: 'Tầng 1 • Khu Đông',
          status: 'Tốt',
          healthScore: '98%',
          icon: Icons.egg,
        ),
        const SizedBox(height: 12),
        const _PenCard(
          title: 'Chuồng Vịt B',
          location: 'Tầng trệt • Khu Tây',
          status: 'Cần chú ý',
          healthScore: '84%',
          icon: Icons.water_drop,
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Camera'),
        BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alerts'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

// WIDGET ACTION CARD TƯƠNG TÁC
class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color backgroundColor, textColor;
  final VoidCallback onTap; // Thêm callback để bắt sự kiện click

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap, // Gọi hàm khi bấm
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 30),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8), // Khoảng cách giãn giữa 2 dòng chữ
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PenCard extends StatelessWidget {
  final String title, location, status, healthScore;
  final IconData icon;

  const _PenCard({
    required this.title,
    required this.location,
    required this.status,
    required this.healthScore,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            healthScore,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
