// frontend/lib/services/vaccination_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/coop.dart';
import '../models/scan.dart';

/// Lỗi có thông điệp thân thiện để hiển thị thẳng lên UI.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class VaccinationService {
  static const Duration _timeout = Duration(seconds: 15);

  /// Lấy danh sách toàn bộ chuồng trại.
  Future<List<CoopSummary>> fetchCoops() async {
    final json = await _get(Uri.parse(ApiConfig.coops));
    final data = (json['data'] as List<dynamic>?) ?? const [];
    return data.whereType<Map<String, dynamic>>().map(CoopSummary.fromJson).toList();
  }

  /// Lấy dashboard chi tiết của 1 chuồng.
  Future<CoopDashboard> fetchCoopDashboard(String coopId) async {
    final json = await _get(Uri.parse(ApiConfig.coopDashboard(coopId)));
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ApiException('Backend không trả về dữ liệu chuồng.');
    }
    return CoopDashboard.fromJson(data);
  }

  /// Xác nhận đã tiêm 1 mũi vắc-xin cho chuồng.
  Future<String> markVaccineCompleted({
    required String coopId,
    required String vaccineId,
    String? administeredBy,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse(ApiConfig.completeVaccine(coopId, vaccineId)),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (administeredBy != null && administeredBy.isNotEmpty)
                'administered_by': administeredBy,
            }),
          )
          .timeout(_timeout);

      final json = _decode(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json['message']?.toString() ?? 'Đã ghi nhận mũi tiêm.';
      }
      throw ApiException(_errorMessage(json, response.statusCode));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(_timeout);
      final json = _decode(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json;
      }
      throw ApiException(_errorMessage(json, response.statusCode));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      throw const ApiException('Dữ liệu backend trả về không đúng định dạng.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Không đọc được phản hồi từ server (HTTP ${response.statusCode}).');
    }
  }

  String _errorMessage(Map<String, dynamic> json, int statusCode) {
    final message = json['message'] ?? json['error'];
    if (message != null) return message.toString();
    return 'Server trả về lỗi HTTP $statusCode.';
  }

  String _networkMessage(Object error) {
    if (error is TimeoutException) {
      return 'Server phản hồi quá lâu. Kiểm tra backend có đang chạy không.';
    }
    if (error is SocketException) {
      return 'Không kết nối được tới ${ApiConfig.baseUrl}.\n'
          'Kiểm tra backend đã chạy và IP trong api_config.dart có đúng máy tính của bạn không.';
    }
    return 'Lỗi kết nối: $error';
  }
  /// Danh mục giống gà, dùng đổ vào form thêm chuồng.
  Future<List<Breed>> fetchBreeds() async {
    final json = await _get(Uri.parse(ApiConfig.breeds));
    final data = (json['data'] as List<dynamic>?) ?? const [];
    return data.whereType<Map<String, dynamic>>().map(Breed.fromJson).toList();
  }

  /// Tạo chuồng mới. Backend tự sinh lịch tiêm theo phác đồ của giống.
  Future<String> createCoop({
    String? id,
    required String name,
    required String breedId,
    required int quantity,
    required DateTime flockStartDate,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.createCoop),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (id != null && id.trim().isNotEmpty) 'id': id.trim(),
              'name': name.trim(),
              'breed_id': breedId,
              'quantity': quantity,
              'flock_start_date': flockStartDate.toIso8601String(),
            }),
          )
          .timeout(_timeout);

      final json = _decode(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json['message']?.toString() ?? 'Đã tạo chuồng.';
      }
      throw ApiException(json['message']?.toString() ?? 'Không tạo được chuồng.');
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Tạo chuồng quá lâu, thử lại sau.');
    } on SocketException {
      throw const ApiException('Không kết nối được máy chủ.');
    } catch (error) {
      throw ApiException('Lỗi tạo chuồng: $error');
    }
  }

  /// Xuất chuồng: đóng lứa nuôi, chuồng chuyển sang tab "Đã xuất chuồng".
  Future<String> harvestCoop({required String coopId, int? finalQuantity}) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.harvestCoop(coopId)),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'final_quantity': ?finalQuantity}),
          )
          .timeout(_timeout);

      final json = _decode(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json['message']?.toString() ?? 'Đã xuất chuồng.';
      }
      throw ApiException(_errorMessage(json, response.statusCode));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  /// Lịch sử các lần chẩn đoán ảnh.
  Future<List<ScanSummary>> fetchScanHistory({int limit = 50}) async {
    final json = await _get(Uri.parse(ApiConfig.scanHistory(limit: limit)));
    final data = (json['data'] as List<dynamic>?) ?? const [];
    return data.whereType<Map<String, dynamic>>().map(ScanSummary.fromJson).toList();
  }

  /// Chi tiết đầy đủ 1 lần scan (kèm phác đồ điều trị và nguồn).
  Future<Map<String, dynamic>> fetchScanDetail(String scanId) async {
    final json = await _get(Uri.parse('${ApiConfig.getScanById}$scanId'));
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Backend không trả về chi tiết lần scan.');
    }
    return data;
  }

}
