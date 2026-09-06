// Định dạng ngày kiểu Việt Nam mà không cần thêm package intl.

String _two(int value) => value.toString().padLeft(2, '0');

/// 04/09/2026
String formatDate(DateTime? date) {
  if (date == null) return '--/--/----';
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

/// 04/09/2026 08:30
String formatDateTime(DateTime? date) {
  if (date == null) return '--/--/----';
  return '${formatDate(date)} ${_two(date.hour)}:${_two(date.minute)}';
}

/// Diễn giải khoảng cách ngày so với hôm nay: "trễ 5 ngày", "còn 3 ngày"...
String describeDueDays(int days) {
  if (days < 0) return 'trễ ${days.abs()} ngày';
  if (days == 0) return 'đến hạn hôm nay';
  return 'còn $days ngày';
}
