// frontend/lib/services/weather_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/weather.dart';
import 'vaccination_service.dart' show ApiException;

/// Gọi API thời tiết của backend (backend proxy sang Open-Meteo - miễn phí,
/// không cần API key - rồi tính thêm chỉ số phù hợp cho chuồng).
class WeatherService {
  static const Duration _timeout = Duration(seconds: 12);

  Future<Weather> fetchCurrent({String? city}) async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.currentWeather(city: city)))
          .timeout(_timeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Dữ liệu thời tiết không đúng định dạng.');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data == null) {
          throw const ApiException('Backend không trả về dữ liệu thời tiết.');
        }
        return Weather.fromJson(data);
      }

      throw ApiException(
        decoded['message']?.toString() ?? 'Không lấy được thời tiết (HTTP ${response.statusCode}).',
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Lấy thời tiết quá lâu, thử lại sau.');
    } on SocketException {
      throw const ApiException('Không kết nối được để lấy thời tiết.');
    } catch (error) {
      throw ApiException('Lỗi lấy thời tiết: $error');
    }
  }
}
