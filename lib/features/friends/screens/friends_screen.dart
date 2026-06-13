import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
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
        title: const Text('Kết bạn qua email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email người muốn kết bạn',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Gửi lời mời')),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    final res = await ApiService.sendFriendRequest(email);
    if (res['ok'] == true) {
      _showSnack(res['message']?.toString() ?? 'Đã gửi lời mời');
    } else {
      _showSnack(res['error']?.toString() ?? 'Gửi lời mời thất bại', error: true);
    }
  }

  void _showMyQr() {
    final auth = context.read<AuthProvider>();
    final email = auth.email ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mã QR kết bạn của bạn'),
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
              const Text(
                'Người khác quét mã này để lấy email và gửi lời mời kết bạn cho bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
  }

  Future<void> _startChat(Map<String, dynamic> friend) async {
    final auth = context.read<AuthProvider>();
    if (auth.uid == null) return;
    try {
      debugPrint('Starting chat with friend: ${friend['id']}');
      final res = await ApiService.createChat(
        participants: [auth.uid!, friend['id'].toString()],
        createdBy: auth.uid!,
      );
      debugPrint('CreateChat response: $res');
      if (!mounted) return;
      final chatId = res['chatId'];
      debugPrint('ChatId: $chatId');
      if (chatId != null && chatId != 0) {
        Navigator.pushNamed(context, AppRoutes.chatDetail, arguments: {
          'chatId': chatId,
          'chatName': friend['display_name'],
          'chatAvatar': friend['avatar_url'],
          'isGroup': false,
        });
      } else {
        _showSnack('Không thể mở cuộc trò chuyện', error: true);
      }
    } catch (e) {
      debugPrint('Error starting chat: $e');
      if (!mounted) return;
      _showSnack('Lỗi: $e', error: true);
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
          title: const Text('Bạn bè', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.qr_code_2), tooltip: 'Mã QR của tôi', onPressed: _showMyQr),
            IconButton(icon: const Icon(Icons.person_add_alt_1), tooltip: 'Kết bạn qua email', onPressed: _addFriendByEmail),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              const Tab(text: 'Bạn bè'),
              Tab(text: 'Lời mời${_requests.isNotEmpty ? ' (${_requests.length})' : ''}'),
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
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Chưa có bạn bè. Hãy kết bạn qua email hoặc QR!', style: TextStyle(color: AppColors.textSecondary))),
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
                  tooltip: 'Nhắn tin',
                  onPressed: () => _startChat(f),
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                  tooltip: 'Hủy kết bạn',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hủy kết bạn'),
                        content: Text('Bạn có chắc muốn hủy kết bạn với ${f['display_name']}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Xác nhận', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    final ok = await ApiService.unfriend(f['id'].toString());
                    if (ok) {
                      _showSnack('Đã hủy kết bạn');
                      _loadAll();
                    } else {
                      _showSnack('Hủy kết bạn thất bại', error: true);
                    }
                  },
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
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Không có lời mời kết bạn nào', style: TextStyle(color: AppColors.textSecondary))),
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
                  tooltip: 'Chấp nhận',
                  onPressed: () async {
                    final ok = await ApiService.acceptFriendRequest(r['friendship_id'].toString());
                    if (ok) {
                      _showSnack('Đã chấp nhận lời mời');
                      _loadAll();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: AppColors.error),
                  tooltip: 'Từ chối',
                  onPressed: () async {
                    final ok = await ApiService.rejectFriendRequest(r['friendship_id'].toString());
                    if (ok) {
                      _showSnack('Đã từ chối lời mời');
                      _loadAll();
                    }
                  },
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
