// lib/api_config.dart

class ApiConfig {
  // 1. Khai báo Base URL (Địa chỉ gốc của Backend)
  // TODO: Cập nhật IP máy tính của bạn ở đây khi kết nối mạng WiFi mới
  //
  // Cách lấy IP hiện tại trên macOS: ipconfig getifaddr en0
  // - BlueStacks / máy thật: dùng IP LAN của máy tính (bên dưới).
  // - Emulator Android Studio (AVD): đổi thành http://10.0.2.2:3000
  // - Chrome/máy tính: có thể dùng http://localhost:3000
  static const String baseUrl = 'http://172.17.17.207:3000';

  // 2. Endpoint chẩn đoán bệnh qua ảnh
  static const String analyzePoultry = '$baseUrl/api/poultry/analyze';
  static const String getAllScans = '$baseUrl/api/poultry';
  static const String getScanById = '$baseUrl/api/poultry/'; // + id

  // 3. Endpoint quản lý chuồng & tiêm phòng
  static const String vaccinationBase = '$baseUrl/api/vaccination';

  /// Danh sách toàn bộ chuồng trại.
  static const String coops = '$vaccinationBase/coops';

  /// Danh mục vắc-xin chuẩn.
  static const String vaccineCatalog = '$vaccinationBase/vaccines';

  /// Dashboard chi tiết 1 chuồng (lịch sử tiêm, mũi kế tiếp, cảnh báo hiệu lực).
  static String coopDashboard(String coopId) => '$vaccinationBase/coops/$coopId/dashboard';

  /// Danh mục giống gà (cho form thêm chuồng).
  static const String breeds = '$baseUrl/api/coops/breeds';

  /// Tạo chuồng mới.
  static const String createCoop = '$baseUrl/api/coops';

  /// Xuất chuồng (đóng lứa nuôi).
  static String harvestCoop(String coopId) => '$baseUrl/api/coops/$coopId/harvest';

  /// Lịch sử scan (rút gọn).
  static String scanHistory({int limit = 50}) => '$baseUrl/api/poultry?limit=$limit';

  /// Thông tin xuất chuồng của 1 chuồng.
  static String coopHarvest(String coopId) => '$baseUrl/api/coops/$coopId/harvest';

  /// Xác nhận đã tiêm 1 mũi cho 1 chuồng.
  static String completeVaccine(String coopId, String vaccineId) =>
      '$vaccinationBase/coops/$coopId/vaccines/$vaccineId/complete';

  // 4. Thời tiết + đánh giá môi trường chuồng
  // (nguồn Open-Meteo: miễn phí, không cần API key)

  /// Thành phố mặc định hiển thị trên màn hình Home.
  /// Đổi tên này nếu trang trại ở tỉnh/thành khác.
  static const String farmCity = 'Hồ Chí Minh';

  /// Thời tiết hiện tại của 1 thành phố.
  static String currentWeather({String? city}) =>
      '$baseUrl/api/weather/current?city=${Uri.encodeComponent(city ?? farmCity)}';
}
