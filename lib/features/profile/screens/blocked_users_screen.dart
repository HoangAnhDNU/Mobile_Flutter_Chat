import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

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
        const SnackBar(content: Text('Đã bỏ chặn')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Người dùng đã chặn')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? const Center(child: Text('Chưa chặn ai'))
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = Map<String, dynamic>.from(_blockedUsers[index]);
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text((user['blocked_name'] ?? '?')[0].toUpperCase()),
                      ),
                      title: Text(user['blocked_name'] ?? 'Unknown'),
                      trailing: TextButton(
                        onPressed: () => _unblock(user['blocked_id'] ?? ''),
                        child: const Text('Bỏ chặn', style: TextStyle(color: Colors.red)),
                      ),
                    );
                  },
                ),
    );
  }
}
