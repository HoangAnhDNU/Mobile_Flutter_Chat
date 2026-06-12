import 'package:flutter/foundation.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/usecases/get_chats_usecase.dart';

/// Trạng thái danh sách chat
enum ChatListStatus {
  initial,
  loading,
  loaded,
  error,
}

/// Provider quản lý danh sách chats
class ChatNotifier extends ChangeNotifier {
  final GetChatsUseCase getChatsUseCase;

  ChatNotifier({
    required this.getChatsUseCase,
  });

  // State
  ChatListStatus _status = ChatListStatus.initial;
  List<ChatEntity> _chats = [];
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;

  // Getters
  ChatListStatus get status => _status;
  List<ChatEntity> get chats => _chats;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ChatListStatus.loading;
  bool get hasMore => _hasMore;

  /// Lấy danh sách chats được ghim
  List<ChatEntity> get pinnedChats => 
      _chats.where((c) => c.isPinned).toList();

  /// Lấy danh sách chats không được ghim
  List<ChatEntity> get regularChats => 
      _chats.where((c) => !c.isPinned && !c.isArchived).toList();

  /// Lấy danh sách chats đã lưu trữ
  List<ChatEntity> get archivedChats => 
      _chats.where((c) => c.isArchived).toList();

  /// Tải danh sách chats (refresh)
  Future<void> loadChats() async {
    _status = ChatListStatus.loading;
    _errorMessage = null;
    _currentPage = 1;
    notifyListeners();

    final result = await getChatsUseCase(const GetChatsParams(page: 1));

    result.fold(
      (failure) {
        _status = ChatListStatus.error;
        _errorMessage = failure.message;
      },
      (chats) {
        _chats = chats;
        _status = ChatListStatus.loaded;
        _hasMore = chats.length >= 20;
      },
    );
    notifyListeners();
  }

  /// Tải thêm chats (pagination)
  Future<void> loadMoreChats() async {
    if (_status == ChatListStatus.loading || !_hasMore) return;

    final nextPage = _currentPage + 1;
    
    final result = await getChatsUseCase(GetChatsParams(page: nextPage));

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (newChats) {
        _chats = [..._chats, ...newChats];
        _currentPage = nextPage;
        _hasMore = newChats.length >= 20;
      },
    );
    notifyListeners();
  }

  /// Cập nhật chat trong danh sách (khi có tin nhắn mới)
  void updateChat(ChatEntity updatedChat) {
    final index = _chats.indexWhere((c) => c.id == updatedChat.id);
    if (index != -1) {
      _chats[index] = updatedChat;
      // Sắp xếp lại - chat có tin nhắn mới nhất lên đầu
      _chats.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        final aTime = a.lastMessage?.createdAt ?? a.createdAt;
        final bTime = b.lastMessage?.createdAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      notifyListeners();
    }
  }

  /// Thêm chat mới vào danh sách
  void addChat(ChatEntity chat) {
    _chats.insert(0, chat);
    notifyListeners();
  }

  /// Xóa chat khỏi danh sách
  void removeChat(String chatId) {
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();
  }

  /// Xóa thông báo lỗi
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
