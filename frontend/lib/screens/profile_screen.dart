import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme_notifier.dart';
import '../widgets/app_bottom_nav_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Hồ sơ',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 24),
          Text(
            'Cài đặt',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildThemeToggle(context),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.notifications_none,
            label: 'Thông báo',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.agriculture_outlined,
            label: 'Thông tin trang trại',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.help_outline,
            label: 'Trợ giúp & Hỗ trợ',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Đăng xuất',
            isDestructive: true,
            onTap: () {},
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentTab: AppTab.profile),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AgriTechColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AgriTechColors.onPrimary.withValues(alpha: 0.15),
            child: const Icon(Icons.person, size: 36, color: AgriTechColors.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quản lý trang trại',
                  style: TextStyle(
                    color: AgriTechColors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SmartFarm • North Pasture',
                  style: TextStyle(
                    color: AgriTechColors.onPrimary.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Material(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: colorScheme.primary,
            ),
            title: Text(
              'Chế độ tối',
              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
            ),
            value: isDark,
            activeThumbColor: AgriTechColors.primary,
            onChanged: (value) {
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
