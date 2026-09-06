import 'package:flutter/material.dart';
import '../colors.dart';
import '../screens/home_screen.dart';
import '../screens/camera_screen.dart';
import '../screens/coops_screen.dart';
import '../screens/profile_screen.dart';

enum AppTab { home, camera, coops, profile }

class AppBottomNavBar extends StatelessWidget {
  final AppTab currentTab;

  const AppBottomNavBar({super.key, required this.currentTab});

  static final List<_NavItemData> _items = [
    _NavItemData(tab: AppTab.home, icon: Icons.home_rounded, label: 'Home'),
    _NavItemData(tab: AppTab.camera, icon: Icons.camera_alt_rounded, label: 'Camera'),
    _NavItemData(tab: AppTab.coops, icon: Icons.holiday_village_rounded, label: 'Coops'),
    _NavItemData(tab: AppTab.profile, icon: Icons.person_rounded, label: 'Profile'),
  ];

  void _navigate(BuildContext context, AppTab tab) {
    if (tab == currentTab) return;

    final Widget target = switch (tab) {
      AppTab.home => const HomeScreen(),
      AppTab.camera => const CameraScreen(),
      AppTab.coops => const CoopsScreen(),
      AppTab.profile => const ProfileScreen(),
    };

    // Chuyển tab: xóa toàn bộ stack cũ để tránh chồng màn hình giữa các tab.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barColor = isDark ? AgriTechColors.darkSurface : Colors.white;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _items.map((item) {
              final selected = item.tab == currentTab;
              return _NavItem(
                data: item,
                selected: selected,
                onTap: () => _navigate(context, item.tab),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final AppTab tab;
  final IconData icon;
  final String label;

  const _NavItemData({required this.tab, required this.icon, required this.label});
}

class _NavItem extends StatelessWidget {
  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unselectedColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill chỉ bọc riêng icon nên icon luôn nằm chính giữa,
            // không bị lệch do label chen ngang như bố cục Row trước đây.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 56,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AgriTechColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                data.icon,
                size: 22,
                color: selected ? AgriTechColors.onPrimary : unselectedColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AgriTechColors.primary : unselectedColor,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
