import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_localizations.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  String _showLastSeen = 'everyone';
  String _showAvatar = 'everyone';
  String _showReadReceipts = 'everyone';
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
        final rr = data['show_read_receipts'];
        if (rr is bool) {
          _showReadReceipts = rr ? 'everyone' : 'nobody';
        } else {
          _showReadReceipts = rr?.toString() ?? 'everyone';
        }
        _loading = false;
      });
    }
  }

  Future<void> _save(Map<String, dynamic> updates) async {
    try {
      await ApiService.updatePrivacySettings(updates);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).tr('save_error', params: {'error': e}))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).translate('privacy_settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionTitle(AppLocalizations.of(context).translate('who_can_see_info')),
                _dropdownTile(
                  AppLocalizations.of(context).translate('last_seen'),
                  _showLastSeen,
                  ['everyone', 'friends', 'nobody'],
                  [AppLocalizations.of(context).translate('everyone'), AppLocalizations.of(context).translate('friends'), AppLocalizations.of(context).translate('nobody')],
                  (v) {
                    setState(() => _showLastSeen = v);
                    _save({'show_last_seen': v});
                  },
                ),
                _dropdownTile(
                  AppLocalizations.of(context).translate('avatar'),
                  _showAvatar,
                  ['everyone', 'friends', 'nobody'],
                  [AppLocalizations.of(context).translate('everyone'), AppLocalizations.of(context).translate('friends'), AppLocalizations.of(context).translate('nobody')],
                  (v) {
                    setState(() => _showAvatar = v);
                    _save({'show_avatar': v});
                  },
                ),
                _dropdownTile(
                  AppLocalizations.of(context).translate('read_receipts'),
                  _showReadReceipts,
                  ['everyone', 'friends', 'nobody'],
                  [AppLocalizations.of(context).translate('everyone'), AppLocalizations.of(context).translate('friends'), AppLocalizations.of(context).translate('nobody')],
                  (v) {
                    setState(() => _showReadReceipts = v);
                    _save({'show_read_receipts': v});
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
