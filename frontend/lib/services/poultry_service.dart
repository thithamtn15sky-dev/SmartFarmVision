// frontend/lib/services/poultry_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class PoultryService {
  // Đổi từ localhost sang 10.0.2.2 để máy ảo Android kết nối được với backend máy tính
  final String baseUrl = "http://10.0.2.2:3000/api/poultry";

  Future<void> addPoultry(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    if (response.statusCode != 201) {
      throw Exception('Không thể lưu dữ liệu: ${response.statusCode}');
    }
  }
}
