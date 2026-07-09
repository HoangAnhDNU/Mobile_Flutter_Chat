import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/utils/app_localizations.dart';

/// Tab Thống kê hệ thống - bố cục gọn dạng lưới nhỏ + danh sách.
class AdminStatsTab extends StatefulWidget {
  const AdminStatsTab({super.key});

  @override
  State<AdminStatsTab> createState() => _AdminStatsTabState();
}

class _AdminStatsTabState extends State<AdminStatsTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Real-time: khi có người online/offline -> tải lại thống kê (im lặng)
    _presenceSub = SocketService.instance.onPresence.listen((_) {
      if (mounted) _loadStats(silent: true);
    });
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStats({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      _stats = await ApiService.adminGetStats();
    } catch (e) {
      debugPrint('Lỗi tải thống kê: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Format database size
    String formatDbSize(dynamic bytes) {
      final b = (bytes is int) ? bytes : (bytes as num?)?.toInt() ?? 0;
      if (b == 0) return 'N/A';
      if (b < 1024) return '$b B';
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
      if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Row 1: 3 chỉ số người dùng
          Row(
            children: [
              Expanded(child: _miniStat(AppLocalizations.of(context).translate('users'), _stats['total_users'], Icons.people, AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _miniStat(AppLocalizations.of(context).translate('online'), _stats['online_users'], Icons.circle, AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _miniStat(AppLocalizations.of(context).translate('locked'), _stats['locked_users'], Icons.lock, AppColors.error)),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: New users and messages today
          Row(
            children: [
              Expanded(
                child: _miniStatWithTrend(
                  'Người dùng mới hôm nay',
                  _stats['new_users_today'] ?? 0,
                  Icons.person_add,
                  AppColors.success,
                  _stats['active_users_today'] ?? 0,
                  'Hoạt động',
                  showTrend: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStatWithTrend(
                  'Tin nhắn hôm nay',
                  _stats['new_messages_today'] ?? 0,
                  Icons.message,
                  AppColors.primary,
                  _stats['messages_this_week'] ?? 0,
                  'Tuần này',
                  showTrend: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nhóm chỉ số hoạt động dạng danh sách hàng - rộng vừa nội dung
          Center(
            child: IntrinsicWidth(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statRow(AppLocalizations.of(context).translate('conversations'), _stats['total_chats'], Icons.chat_bubble_outline, Colors.teal),
                    const Divider(height: 1),
                    _statRow(AppLocalizations.of(context).translate('chat_groups'), _stats['total_groups'], Icons.groups_2_outlined, Colors.deepPurple),
                    const Divider(height: 1),
                    _statRow(AppLocalizations.of(context).translate('total_messages'), _stats['total_messages'], Icons.forum_outlined, Colors.orange),
                    const Divider(height: 1),
                    _statRow('Dung lượng DB', formatDbSize(_stats['db_size_bytes'] ?? 0), Icons.storage, Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildChart(AppLocalizations.of(context).translate('messages_7_days'), _stats['daily_messages'], AppColors.primary),
          const SizedBox(height: 24),
          _buildChart(AppLocalizations.of(context).translate('new_users_7_days'), _stats['daily_new_users'], AppColors.success),
          const SizedBox(height: 16),

          Center(
            child: Text(
              AppLocalizations.of(context).tr('updated_at', params: {'time': TimeOfDay.now().format(context)}),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(String title, dynamic data, Color color) {
    final list = (data as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    final spots = list.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['count'] as num).toDouble());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= list.length) return const SizedBox.shrink();
                        final day = list[idx]['day']?.toString() ?? '';
                        final parts = day.split('-');
                        return Text(parts.length >= 3 ? '${parts[2]}/${parts[1]}' : day, style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text('${value ?? 0}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _miniStatWithTrend(String label, dynamic value, IconData icon, Color color, dynamic secondaryValue, String secondaryLabel, {bool showTrend = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text('${value ?? 0}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          if (showTrend) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up, size: 12, color: AppColors.success),
                  const SizedBox(width: 2),
                  Text(
                    '$secondaryValue $secondaryLabel',
                    style: const TextStyle(fontSize: 9, color: AppColors.success),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 2),
            Text(
              '$secondaryValue $secondaryLabel',
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, dynamic value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(width: 32),
          const Spacer(),
          Text('${value ?? 0}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
