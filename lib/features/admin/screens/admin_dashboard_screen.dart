import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import 'admin_stats_tab.dart';
import 'admin_users_tab.dart';
import 'admin_groups_tab.dart';
import 'admin_activity_log_tab.dart';

/// Trang quản trị với thanh điều hướng dưới cùng (chỉ icon).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final _pages = const [
    AdminStatsTab(),
    AdminUsersTab(),
    AdminGroupsTab(),
    AdminActivityLogTab(),
  ];

  List<String> _getTitles(BuildContext context) => [
    AppLocalizations.of(context).translate('admin_stats'),
    AppLocalizations.of(context).translate('admin_users'),
    AppLocalizations.of(context).translate('admin_groups'),
    AppLocalizations.of(context).translate('admin_activity_log'),
  ];

  Future<void> _logout() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final titles = _getTitles(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(titles[_currentIndex], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: AppLocalizations.of(context).translate('logout'), onPressed: _logout),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _navItem(0, Icons.bar_chart_outlined, Icons.bar_chart),
              _navItem(1, Icons.people_outline, Icons.people),
              _navItem(2, Icons.groups_2_outlined, Icons.groups_2),
              _navItem(3, Icons.history_outlined, Icons.history),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon) {
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              selected ? activeIcon : icon,
              size: 30,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
