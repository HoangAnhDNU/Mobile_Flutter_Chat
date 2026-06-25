import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_colors.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  String _showLastSeen = 'everyone';
  String _showAvatar = 'everyone';
  bool _showReadReceipts = true;
  int _disappearingMessages = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getPrivacySettings();
    if (mounted) {
      setState(() {
        _showLastSeen = data['show_last_seen'] ?? 'everyone';
        _showAvatar = data['show_avatar'] ?? 'everyone';
        _showReadReceipts = data['show_read_receipts'] ?? true;
        _disappearingMessages = data['disappearing_messages'] ?? 0;
        _loading = false;
      });
    }
  }

  Future<void> _save(Map<String, dynamic> updates) async {
    try {
      await ApiService.updatePrivacySettings(updates);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quyền riêng tư')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionTitle('Ai được xem thông tin của bạn'),
                _dropdownTile(
                  'Lần cuối online',
                  _showLastSeen,
                  ['everyone', 'nobody'],
                  ['Tất cả', 'Không ai'],
                  (v) {
                    setState(() => _showLastSeen = v);
                    _save({'show_last_seen': v});
                  },
                ),
                _dropdownTile(
                  'Ảnh đại diện',
                  _showAvatar,
                  ['everyone', 'nobody'],
                  ['Tất cả', 'Không ai'],
                  (v) {
                    setState(() => _showAvatar = v);
                    _save({'show_avatar': v});
                  },
                ),
                SwitchListTile(
                  title: const Text('Xác nhận đã đọc'),
                  subtitle: const Text('Hiển thị tick xanh khi bạn đọc tin nhắn'),
                  value: _showReadReceipts,
                  onChanged: (v) {
                    setState(() => _showReadReceipts = v);
                    _save({'show_read_receipts': v});
                  },
                ),
                const Divider(),
                _sectionTitle('Tin nhắn tự xóa'),
                _dropdownTile(
                  'Tự xóa sau',
                  _disappearingMessages.toString(),
                  ['0', '86400', '604800', '7776000'],
                  ['Tắt', '24 giờ', '7 ngày', '90 ngày'],
                  (v) {
                    final val = int.tryParse(v) ?? 0;
                    setState(() => _disappearingMessages = val);
                    _save({'disappearing_messages': val});
                  },
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _dropdownTile(String title, String value, List<String> values, List<String> labels, Function(String) onChanged) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: List.generate(values.length, (i) {
          return DropdownMenuItem(value: values[i], child: Text(labels[i]));
        }),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
