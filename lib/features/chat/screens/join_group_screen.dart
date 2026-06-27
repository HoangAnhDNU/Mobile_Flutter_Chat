import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_localizations.dart';

class JoinGroupScreen extends StatefulWidget {
  final String? initialCode;

  const JoinGroupScreen({super.key, this.initialCode});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    String? code = widget.initialCode;
    if (kIsWeb && code == null) {
      final uri = Uri.parse(Uri.base.toString());
      final fragment = uri.fragment;
      if (fragment.contains('code=')) {
        final fragUri = Uri.splitQueryString(fragment.substring(fragment.indexOf('?') + 1));
        code = fragUri['code'];
      }
    }
    if (code != null && code.isNotEmpty) {
      _controller.text = code;
      _joinGroup();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _extractCode(String input) {
    final trimmed = input.trim();
    final parts = trimmed.split('/join/');
    if (parts.length > 1) return parts.last;
    return trimmed;
  }

  Future<void> _joinGroup() async {
    final code = _extractCode(_controller.text);
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await ApiService.joinViaInvite(code);
      final chatId = int.tryParse(result['chat_id']?.toString() ?? '') ?? 0;
      if (!mounted) return;
      final chatName = result['chat_name']?.toString() ?? AppLocalizations.of(context).translate('group');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('joined_group', params: {'name': chatName}))),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.chatList,
        (route) => route.isFirst,
      );
      if (chatId != 0) {
        Navigator.pushNamed(context, AppRoutes.chatDetail, arguments: {
          'chatId': chatId,
          'chatName': chatName,
          'isGroup': true,
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('join_failed', params: {'error': e})), backgroundColor: AppColors.error),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).translate('join_group'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).translate('join_code_hint'),
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).translate('join_code'),
                hintText: AppLocalizations.of(context).translate('join_code_hint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _joinGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(AppLocalizations.of(context).translate('join_group')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
