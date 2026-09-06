// Model cho lịch sử chẩn đoán ảnh (collection poultryscans).

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// Một dòng trong danh sách lịch sử scan (bản rút gọn từ backend).
class ScanSummary {
  final String id;
  final DateTime? scannedAt;
  final String poultryType;
  final String status;
  final String? thumbnail;
  final int imageCount;
  final String? observation;
  final String diseaseName;
  final double confidenceScore;
  final bool requiresExpertReview;
  final bool isVerified;

  const ScanSummary({
    required this.id,
    required this.scannedAt,
    required this.poultryType,
    required this.status,
    required this.thumbnail,
    required this.imageCount,
    required this.observation,
    required this.diseaseName,
    required this.confidenceScore,
    required this.requiresExpertReview,
    required this.isVerified,
  });

  factory ScanSummary.fromJson(Map<String, dynamic> json) {
    return ScanSummary(
      id: json['id']?.toString() ?? '',
      scannedAt: _toDate(json['scannedAt']),
      poultryType: json['poultryType']?.toString() ?? 'Gà',
      status: json['status']?.toString() ?? 'Chưa rõ',
      thumbnail: json['thumbnail']?.toString(),
      imageCount: _toInt(json['imageCount']),
      observation: json['observation']?.toString(),
      diseaseName: json['diseaseName']?.toString() ?? 'Chưa xác định',
      confidenceScore: _toDouble(json['confidenceScore']),
      requiresExpertReview: json['requiresExpertReview'] == true,
      isVerified: json['isVerified'] == true,
    );
  }

  bool get isDanger => status == 'Nguy hiểm' || status == 'Cảnh báo';

  /// Bỏ tiền tố "Người nuôi mô tả: " cho gọn khi hiện trong danh sách.
  String? get shortObservation {
    if (observation == null || observation!.isEmpty) return null;
    const prefix = 'Người nuôi mô tả: ';
    return observation!.startsWith(prefix)
        ? observation!.substring(prefix.length)
        : observation;
  }
}
