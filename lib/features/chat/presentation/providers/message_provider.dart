import 'package:flutter/foundation.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';

/// Trạng thái tin nhắn
enum MessageStatus {
  initial,
  loading,
  loaded,
  sending,
  error,
}

/// Provider quản lý tin nhắn trong một chat
class MessageNotifier extends ChangeNotifier {
  final GetMessagesUseCase getMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;

  MessageNotifier({
    required this.getMessagesUseCase,
    required this.sendMessageUseCase,
  });

  // State
  MessageStatus _status = MessageStatus.initial;
  List<MessageEntity> _messages = [];
  String? _errorMessage;
  String? _currentChatId;
  int _currentPage = 1;
  bool _hasMore = true;

  // Getters
  MessageStatus get status => _status;
  List<MessageEntity> get messages => _messages;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == MessageStatus.loading;
  bool get isSending => _status == MessageStatus.sending;
  bool get hasMore => _hasMore;

  /// Tải tin nhắn của một chat
  Future<void> loadMessages(String chatId) async {
    if (_currentChatId == chatId && _messages.isNotEmpty) {
      // Đã load rồi, chỉ refresh
      return refreshMessages();
    }

    _currentChatId = chatId;
    _currentPage = 1;
    _status = MessageStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await getMessagesUseCase(GetMessagesParams(
      chatId: chatId,
      page: 1,
    ));

    result.fold(
      (failure) {
        _status = MessageStatus.error;
        _errorMessage = failure.message;
      },
      (messages) {
        _messages = messages;
        _status = MessageStatus.loaded;
        _hasMore = messages.length >= 50;
      },
    );
    notifyListeners();
  }

  /// Refresh tin nhắn
  Future<void> refreshMessages() async {
    if (_currentChatId == null) return;

    _currentPage = 1;
    
    final result = await getMessagesUseCase(GetMessagesParams(
      chatId: _currentChatId!,
      page: 1,
    ));

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (messages) {
        _messages = messages;
        _hasMore = messages.length >= 50;
      },
    );
    notifyListeners();
  }

  /// Tải thêm tin nhắn cũ (pagination)
  Future<void> loadMoreMessages() async {
    if (_currentChatId == null || _status == MessageStatus.loading || !_hasMore) {
      return;
    }

    final nextPage = _currentPage + 1;

    final result = await getMessagesUseCase(GetMessagesParams(
      chatId: _currentChatId!,
      page: nextPage,
    ));

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (newMessages) {
        _messages = [..._messages, ...newMessages];
        _currentPage = nextPage;
        _hasMore = newMessages.length >= 50;
      },
    );
    notifyListeners();
  }

  /// Gửi tin nhắn văn bản
  Future<bool> sendMessage({
    required String content,
    String? replyToId,
  }) async {
    if (_currentChatId == null) return false;

    _status = MessageStatus.sending;
    notifyListeners();

    final result = await sendMessageUseCase(SendMessageParams(
      chatId: _currentChatId!,
      content: content,
      replyToId: replyToId,
    ));

    return result.fold(
      (failure) {
        _status = MessageStatus.loaded;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (message) {
        // Thêm tin nhắn mới vào đầu danh sách
        _messages.insert(0, message);
        _status = MessageStatus.loaded;
        notifyListeners();
        return true;
      },
    );
  }

  /// Thêm tin nhắn mới từ WebSocket
  void addNewMessage(MessageEntity message) {
    // Kiểm tra tin nhắn đã tồn tại chưa
    if (!_messages.any((m) => m.id == message.id)) {
      _messages.insert(0, message);
      notifyListeners();
    }
  }

  /// Cập nhật trạng thái tin nhắn
  void updateMessageStatus(String messageId, MessageStatus newStatus) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      // Cần tạo method copyWith trong MessageEntity
      notifyListeners();
    }
  }

  /// Xóa tin nhắn khỏi danh sách
  void removeMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  /// Clear state khi rời khỏi chat
  void clearMessages() {
    _currentChatId = null;
    _messages = [];
    _status = MessageStatus.initial;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  /// Xóa thông báo lỗi
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
