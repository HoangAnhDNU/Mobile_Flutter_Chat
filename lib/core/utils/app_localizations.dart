import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(Localizations.localeOf(context));
  }

  static const _localizedValues = {
    'en': {
      'chats': 'Chats',
      'profile': 'Profile',
      'settings': 'Settings',
      'online': 'Online',
      'typing': 'is typing...',
      'logout': 'Sign out',
      'display_name': 'Display name',
      'email': 'Email',
      'notifications': 'Notifications',
      'dark_mode': 'Dark mode',
      'language': 'Language',
      'search_messages': 'Search messages...',
      'type_message': 'Type a message...',
      'edit_message': 'Edit message...',
      'update_name': 'Update name',
      'no_chats': 'No conversations yet',
      'start_chat': 'Tap + to start chatting',
    },
    'vi': {
      'chats': 'Trò chuyện',
      'profile': 'Hồ sơ',
      'settings': 'Cài đặt',
      'online': 'Đang hoạt động',
      'typing': 'đang soạn tin...',
      'logout': 'Đăng xuất',
      'display_name': 'Tên hiển thị',
      'email': 'Email',
      'notifications': 'Thông báo',
      'dark_mode': 'Chế độ tối',
      'language': 'Ngôn ngữ',
      'search_messages': 'Tìm kiếm tin nhắn...',
      'type_message': 'Nhập tin nhắn...',
      'edit_message': 'Chỉnh sửa tin nhắn...',
      'update_name': 'Cập nhật tên',
      'no_chats': 'Chưa có cuộc trò chuyện nào',
      'start_chat': 'Bấm + để bắt đầu chat',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}
