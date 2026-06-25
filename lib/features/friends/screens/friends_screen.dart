import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình quản lý bạn bè: danh sách bạn, lời mời đang chờ,
/// kết bạn qua email và tạo mã QR để người khác quét.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<dynamic> _friends = [];
  List<dynamic> _requests = [];
  List<dynamic> _blockedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getFriends(),
        ApiService.getFriendRequests(),
      ]);
      _friends = results[0];
      _requests = results[1];
      final blocked = await ApiService.getBlockedUsers();
      _blockedIds = blocked.map((b) => (b as Map<String, dynamic>)['blocked_id']?.toString()).whereType<String>().toList();
    } catch (e) {
      debugPrint('Lỗi tải bạn bè: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _addFriendByEmail() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('add_by_email')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).translate('friend_email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(AppLocalizations.of(context).translate('send_request'))),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    final res = await ApiService.sendFriendRequest(email);
    if (res['ok'] == true) {
      _showSnack(res['message']?.toString() ?? AppLocalizations.of(context).translate('request_sent'));
    } else {
      _showSnack(res['error']?.toString() ?? AppLocalizations.of(context).translate('request_failed'), error: true);
    }
  }

  void _showMyQr() {
    final auth = context.read<AuthProvider>();
    final email = auth.email ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('qr_code_title')),
        content: SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: QrImageView(
                  data: email,
                  version: QrVersions.auto,
                  size: 180,
                ),
              ),
              const SizedBox(height: 12),
              Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).translate('qr_scan_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).translate('close')))],
      ),
    );
  }

  void _blockUser(Map<String, dynamic> friend) async {
    final uid = friend['id']?.toString();
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('block_user')),
        content: Text(AppLocalizations.of(context).tr('block_friend_confirm', params: {'name': friend['display_name']})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).translate('block'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.blockUser(uid);
      _showSnack(AppLocalizations.of(context).tr('blocked_user_name', params: {'name': friend['display_name']}));
      _loadAll();
    } catch (e) {
      _showSnack(AppLocalizations.of(context).translate('block_failed_short'), error: true);
    }
  }

  void _unblockUser(Map<String, dynamic> friend) async {
    final uid = friend['id']?.toString();
    if (uid == null) return;
    try {
      await ApiService.unblockUser(uid);
      _showSnack(AppLocalizations.of(context).tr('unblocked_user_name', params: {'name': friend['display_name']}));
      _loadAll();
    } catch (e) {
      _showSnack(AppLocalizations.of(context).translate('unblock_failed_short'), error: true);
    }
  }

  bool _isBlocked(Map<String, dynamic> f) {
    final uid = f['id']?.toString();
    return uid != null && _blockedIds.contains(uid);
  }

  Future<void> _startChat(Map<String, dynamic> friend) async {
    final auth = context.read<AuthProvider>();
    if (auth.uid == null) return;
    try {
      final res = await ApiService.createChat(
        participants: [auth.uid!, friend['id'].toString()],
        createdBy: auth.uid!,
      );
      if (!mounted) return;
      final chatId = res['chatId'];
      final chat = res['chat'] as Map?;
      String? chatAvatar = chat?['avatar_url']?.toString();
      String? chatName = chat?['chat_name']?.toString();
      if (chat != null && chatAvatar == null) {
        final participants = chat['participants'] as List?;
        if (participants != null) {
          final auth = context.read<AuthProvider>();
          for (final p in participants) {
            final pm = p as Map<String, dynamic>;
            if (pm['id']?.toString() != auth.uid) {
              chatAvatar = pm['avatar_url']?.toString();
              chatName ??= pm['display_name']?.toString();
              break;
            }
          }
        }
      }
      chatName ??= friend['display_name'];
      chatAvatar ??= friend['avatar_url']?.toString();
      if (chatId != null && chatId != 0) {
        Navigator.pushNamed(context, AppRoutes.chatDetail, arguments: {
          'chatId': chatId,
          'chatName': chatName,
          'chatAvatar': chatAvatar,
          'isGroup': false,
        });
      } else {
        _showSnack(AppLocalizations.of(context).translate('cannot_open_chat'), error: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(AppLocalizations.of(context).tr('error_msg', params: {'error': e}), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text(AppLocalizations.of(context).translate('friends_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.qr_code_2), tooltip: AppLocalizations.of(context).translate('my_qr'), onPressed: _showMyQr),
            IconButton(icon: const Icon(Icons.person_add_alt_1), tooltip: AppLocalizations.of(context).translate('add_by_email'), onPressed: _addFriendByEmail),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: AppLocalizations.of(context).translate('friends_title')),
              Tab(text: '${AppLocalizations.of(context).translate('requests')}${_requests.isNotEmpty ? ' (${_requests.length})' : ''}'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildFriendsList(),
                  _buildRequestsList(),
                ],
              ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text(AppLocalizations.of(context).translate('no_friends'), style: const TextStyle(color: AppColors.textSecondary))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        itemCount: _friends.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final f = _friends[index] as Map<String, dynamic>;
          return ListTile(
            leading: _avatar(f),
            title: Text(f['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(f['email'] ?? '', style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                  tooltip: AppLocalizations.of(context).translate('message'),
                  onPressed: () => _startChat(f),
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                  tooltip: AppLocalizations.of(context).translate('unfriend'),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(AppLocalizations.of(context).translate('unfriend')),
                        content: Text(AppLocalizations.of(context).tr('unfriend_confirm', params: {'name': f['display_name']})),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(AppLocalizations.of(context).translate('confirm'), style: const TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    final ok = await ApiService.unfriend(f['id'].toString());
                    if (ok) {
                      _showSnack(AppLocalizations.of(context).translate('unfriended'));
                      _loadAll();
                    } else {
                      _showSnack(AppLocalizations.of(context).translate('unfriend_failed'), error: true);
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'block') _blockUser(f);
                    if (value == 'unblock') _unblockUser(f);
                  },
                  itemBuilder: (context) => [
                    if (_isBlocked(f))
                      PopupMenuItem(value: 'unblock', child: Text(AppLocalizations.of(context).translate('unblock'), style: const TextStyle(color: AppColors.success)))
                    else
                      PopupMenuItem(value: 'block', child: Text(AppLocalizations.of(context).translate('block_user'), style: const TextStyle(color: AppColors.error))),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text(AppLocalizations.of(context).translate('no_requests'), style: const TextStyle(color: AppColors.textSecondary))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final r = _requests[index] as Map<String, dynamic>;
          return ListTile(
            leading: _avatar(r),
            title: Text(r['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(r['email'] ?? '', style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: AppColors.success),
                  tooltip: AppLocalizations.of(context).translate('accept'),
                  onPressed: () async {
                    final ok = await ApiService.acceptFriendRequest(r['friendship_id'].toString());
                    if (ok) {
                      _showSnack(AppLocalizations.of(context).translate('request_accepted'));
                      _loadAll();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: AppColors.error),
                  tooltip: AppLocalizations.of(context).translate('reject'),
                  onPressed: () async {
                    final ok = await ApiService.rejectFriendRequest(r['friendship_id'].toString());
                    if (ok) {
                      _showSnack(AppLocalizations.of(context).translate('request_rejected'));
                      _loadAll();
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'block') _blockUser(r);
                    if (value == 'unblock') _unblockUser(r);
                  },
                  itemBuilder: (context) => [
                    if (_isBlocked(r))
                      PopupMenuItem(value: 'unblock', child: Text(AppLocalizations.of(context).translate('unblock'), style: const TextStyle(color: AppColors.success)))
                    else
                      PopupMenuItem(value: 'block', child: Text(AppLocalizations.of(context).translate('block_user'), style: const TextStyle(color: AppColors.error))),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> u) {
    final url = u['avatar_url']?.toString() ?? '';
    return CircleAvatar(
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: url.startsWith('data:image') ? _img(url) : null,
      child: !url.startsWith('data:image')
          ? Text(
              (u['display_name'] ?? '?').toString().isNotEmpty ? u['display_name'][0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  ImageProvider? _img(String dataUri) {
    try {
      return MemoryImage(Uri.parse(dataUri).data!.contentAsBytes());
    } catch (_) {
      return null;
    }
  }
}
