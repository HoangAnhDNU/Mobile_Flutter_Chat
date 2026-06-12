import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isBlocked = false;
  late String _userUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _userUid = args?['uid'] ?? '';
    if (_user == null) _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    try {
      final users = await ApiService.getUsers();
      _user = users.firstWhere(
        (u) => u['uid'] == _userUid,
        orElse: () => null,
      );

      final blocked = await ApiService.getBlockedUsers();
      _isBlocked = blocked.any((b) => b['blocked_uid'] == _userUid);
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  ImageProvider? _getImageProvider(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return CachedNetworkImageProvider(url);
  }

  Future<void> _toggleBlock() async {
    try {
      if (_isBlocked) {
        await ApiService.unblockUser(_userUid);
      } else {
        await ApiService.blockUser(_userUid);
      }
      setState(() => _isBlocked = !_isBlocked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isBlocked ? 'Đã chặn người dùng' : 'Đã bỏ chặn')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _startChat() async {
    try {
      final result = await ApiService.createChat(
        participants: [ApiService.uid!, _userUid],
        createdBy: ApiService.uid!,
      );
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.chatDetail,
        arguments: {
          'chatId': result['chatId'],
          'chatName': _user?['display_name'] ?? 'Chat',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo chat: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin người dùng'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('Không tìm thấy người dùng'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final displayName = _user!['display_name'] ?? 'Unknown';
    final email = _user!['email'] ?? '';
    final avatarUrl = _user!['avatar_url'] ?? '';
    final isOnline = (_user!['is_online'] == 1 || _user!['is_online'] == true);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: _getImageProvider(avatarUrl),
                child: avatarUrl.isEmpty
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.success : AppColors.textSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            isOnline ? 'Đang hoạt động' : 'Không hoạt động',
            style: TextStyle(
              color: isOnline ? AppColors.success : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Nhắn tin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _toggleBlock,
              icon: Icon(_isBlocked ? Icons.lock_open : Icons.block, color: AppColors.error),
              label: Text(
                _isBlocked ? 'Bỏ chặn' : 'Chặn người dùng',
                style: const TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
