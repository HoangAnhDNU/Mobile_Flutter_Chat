class TimeUtils {
  static DateTime toBangkokTime(DateTime dateTime) {
    return dateTime.toUtc().add(const Duration(hours: 7));
  }

  static String formatTime(DateTime dateTime) {
    final time = toBangkokTime(dateTime);
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatDateShort(DateTime dateTime) {
    final time = toBangkokTime(dateTime);
    return '${time.day}/${time.month}';
  }
}