import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/constants/app_config.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<dynamic> _blockedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await ApiService.getBlockedUsers();
    if (mounted) setState(() { _blockedUsers = users; _loading = false; });
  }

  Future<void> _unblock(String userId) async {
    await ApiService.unblockUser(userId);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('unblocked'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).translate('blocked_users'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(child: Text(AppLocalizations.of(context).translate('no_blocked')))
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = Map<String, dynamic>.from(_blockedUsers[index]);
                    final avatarUrl = user['blocked_avatar']?.toString() ?? '';
                    final name = user['blocked_name'] ?? 'Unknown';
                    final imageUrl = avatarUrl.isNotEmpty ? AppConfig.resolveMediaUrl(avatarUrl) : null;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                        child: imageUrl == null ? Text(name[0].toUpperCase()) : null,
                      ),
                      title: Text(name),
                      trailing: TextButton(
                        onPressed: () => _unblock(user['blocked_id'] ?? ''),
                        child: Text(AppLocalizations.of(context).translate('unblock'), style: const TextStyle(color: Colors.red)),
                      ),
                    );
                  },
                ),
    );
  }
}
