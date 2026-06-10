class AppConfig {
  // ⚠️ Đổi thành IP LAN của máy tính khi test trên thiết bị thật
  // Ví dụ: '192.168.1.5'
  // Emulator dùng: '10.0.2.2'
  static const String serverHost = '192.168.0.106';
  static const int serverPort = 3000;

  static const String baseUrl = 'http://$serverHost:$serverPort/api';
  static const String wsUrl = 'ws://$serverHost:$serverPort';
}
