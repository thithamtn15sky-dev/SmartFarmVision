// Model ánh xạ dữ liệu chuồng trại & lịch tiêm phòng trả về từ backend
// (collection ChuongTrai + LichTiemPhong).

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Trạng thái hiển thị của 1 mũi tiêm.
enum VaccineStatus { completed, pending, overdue, skipped }

VaccineStatus _parseStatus(String? raw) {
  switch (raw) {
    case 'COMPLETED':
      return VaccineStatus.completed;
    case 'OVERDUE':
      return VaccineStatus.overdue;
    case 'SKIPPED':
      return VaccineStatus.skipped;
    default:
      return VaccineStatus.pending;
  }
}

/// Một chuồng trong danh sách (GET /api/vaccination/coops).
class CoopSummary {
  final String id;
  final String name;
  final String species;
  final int quantity;
  final String status;
  final int safetyScore;
  final DateTime? flockStartDate;
  final int ageDays;
  final int totalRequired;
  final int totalCompleted;
  final int overdueCount;
  final int progressPercent;
  final String? nextDueVaccine;
  final String? nextDueVaccineName;
  final DateTime? nextDueDate;
  final int? daysUntilDue;
  final bool isFullyVaccinated;
  final HarvestInfo? harvest;

  const CoopSummary({
    required this.id,
    required this.name,
    required this.species,
    required this.quantity,
    required this.status,
    required this.safetyScore,
    required this.flockStartDate,
    required this.ageDays,
    required this.totalRequired,
    required this.totalCompleted,
    required this.overdueCount,
    required this.progressPercent,
    required this.nextDueVaccine,
    required this.nextDueVaccineName,
    required this.nextDueDate,
    required this.daysUntilDue,
    required this.isFullyVaccinated,
    required this.harvest,
  });

  factory CoopSummary.fromJson(Map<String, dynamic> json) {
    return CoopSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Chuồng chưa đặt tên',
      species: json['species']?.toString() ?? 'Gà',
      quantity: _parseInt(json['quantity']),
      status: json['status']?.toString() ?? 'ACTIVE',
      safetyScore: _parseInt(json['safety_score'], fallback: 100),
      flockStartDate: _parseDate(json['flock_start_date']),
      ageDays: _parseInt(json['age_days']),
      totalRequired: _parseInt(json['total_required']),
      totalCompleted: _parseInt(json['total_completed']),
      overdueCount: _parseInt(json['overdue_count']),
      progressPercent: _parseInt(json['progress_percent']),
      nextDueVaccine: json['next_due_vaccine']?.toString(),
      nextDueVaccineName: json['next_due_vaccine_name']?.toString(),
      nextDueDate: _parseDate(json['next_due_date']),
      daysUntilDue: json['days_until_due'] == null ? null : _parseInt(json['days_until_due']),
      isFullyVaccinated: json['is_fully_vaccinated'] == true,
      harvest: json['harvest'] is Map<String, dynamic>
          ? HarvestInfo.fromJson(json['harvest'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get hasOverdue => overdueCount > 0;
}

/// Một mũi tiêm trong phác đồ của chuồng.
class VaccinationRecord {
  final String vaccineId;
  final String vaccineName;
  final String? diseasePrevented;
  final String? standardTiming;
  final String? method;
  final String? note;
  final int injectAtDay;
  final int effectivenessDays;
  final DateTime? scheduledDate;
  final VaccineStatus status;
  final DateTime? completedAt;
  final String? administeredBy;
  final int daysUntilDue;
  final bool isOverdue;
  final DateTime? effectiveUntil;
  final int? daysOfEffectRemaining;
  final bool isExpired;

  const VaccinationRecord({
    required this.vaccineId,
    required this.vaccineName,
    required this.diseasePrevented,
    required this.standardTiming,
    required this.method,
    required this.note,
    required this.injectAtDay,
    required this.effectivenessDays,
    required this.scheduledDate,
    required this.status,
    required this.completedAt,
    required this.administeredBy,
    required this.daysUntilDue,
    required this.isOverdue,
    required this.effectiveUntil,
    required this.daysOfEffectRemaining,
    required this.isExpired,
  });

  factory VaccinationRecord.fromJson(Map<String, dynamic> json) {
    return VaccinationRecord(
      vaccineId: json['vaccine_id']?.toString() ?? '',
      vaccineName: json['vaccine_name']?.toString() ?? json['vaccine_id']?.toString() ?? '',
      diseasePrevented: json['disease_prevented']?.toString(),
      standardTiming: json['standard_timing']?.toString(),
      method: json['method']?.toString(),
      note: json['note']?.toString(),
      injectAtDay: _parseInt(json['inject_at_day']),
      effectivenessDays: _parseInt(json['effectiveness_days']),
      scheduledDate: _parseDate(json['scheduled_date']),
      status: _parseStatus(json['status']?.toString()),
      completedAt: _parseDate(json['completed_at']),
      administeredBy: json['administered_by']?.toString(),
      daysUntilDue: _parseInt(json['days_until_due']),
      isOverdue: json['is_overdue'] == true,
      effectiveUntil: _parseDate(json['effective_until']),
      daysOfEffectRemaining:
          json['days_of_effect_remaining'] == null ? null : _parseInt(json['days_of_effect_remaining']),
      isExpired: json['is_expired'] == true,
    );
  }

  bool get isCompleted => status == VaccineStatus.completed;
}

/// Toàn bộ dữ liệu dashboard 1 chuồng
/// (GET /api/vaccination/coops/:id/dashboard).
class CoopDashboard {
  final String id;
  final String name;
  final String species;
  final int quantity;
  final String coopStatus;
  final DateTime? flockStartDate;
  final int ageDays;
  final int safetyScore;

  final int totalRequired;
  final int totalCompleted;
  final int overdueCount;
  final int progressPercent;

  final String statusMsg;
  final String effectivenessMsg;
  final String nextActionMsg;

  final VaccinationRecord? nextVaccine;
  final VaccinationRecord? lastCompletedVaccine;
  final List<VaccinationRecord> records;

  const CoopDashboard({
    required this.id,
    required this.name,
    required this.species,
    required this.quantity,
    required this.coopStatus,
    required this.flockStartDate,
    required this.ageDays,
    required this.safetyScore,
    required this.totalRequired,
    required this.totalCompleted,
    required this.overdueCount,
    required this.progressPercent,
    required this.statusMsg,
    required this.effectivenessMsg,
    required this.nextActionMsg,
    required this.nextVaccine,
    required this.lastCompletedVaccine,
    required this.records,
  });

  factory CoopDashboard.fromJson(Map<String, dynamic> json) {
    final info = (json['coop_info'] as Map<String, dynamic>?) ?? const {};
    final summary = (json['coop_summary'] as Map<String, dynamic>?) ?? const {};
    final rawRecords = (json['all_records'] as List<dynamic>?) ?? const [];

    return CoopDashboard(
      id: info['id']?.toString() ?? '',
      name: info['name']?.toString() ?? 'Chuồng chưa đặt tên',
      species: info['species']?.toString() ?? 'Gà',
      quantity: _parseInt(info['quantity']),
      coopStatus: info['status']?.toString() ?? 'ACTIVE',
      flockStartDate: _parseDate(info['flock_start_date']),
      ageDays: _parseInt(info['age_days']),
      safetyScore: _parseInt(json['safety_score'], fallback: 100),
      totalRequired: _parseInt(summary['total_required']),
      totalCompleted: _parseInt(summary['total_completed']),
      overdueCount: _parseInt(summary['overdue_count']),
      progressPercent: _parseInt(summary['progress_percent']),
      statusMsg: json['q1_status_msg']?.toString() ?? '',
      effectivenessMsg: json['q2_effectiveness_msg']?.toString() ?? '',
      nextActionMsg: json['q3_next_action_msg']?.toString() ?? '',
      nextVaccine: json['next_vaccine'] == null
          ? null
          : VaccinationRecord.fromJson(json['next_vaccine'] as Map<String, dynamic>),
      lastCompletedVaccine: json['last_completed_vaccine'] == null
          ? null
          : VaccinationRecord.fromJson(json['last_completed_vaccine'] as Map<String, dynamic>),
      records: rawRecords
          .whereType<Map<String, dynamic>>()
          .map(VaccinationRecord.fromJson)
          .toList(),
    );
  }

  bool get isFullyVaccinated => nextVaccine == null;
}


/// Thông tin xuất chuồng: tỷ lệ sống và thời gian còn lại tới lứa.
enum HarvestStatus { growing, soon, ready, overdue, done, unknown }

HarvestStatus _parseHarvestStatus(String? raw) {
  switch (raw) {
    case 'SOON':
      return HarvestStatus.soon;
    case 'READY':
      return HarvestStatus.ready;
    case 'OVERDUE':
      return HarvestStatus.overdue;
    case 'DONE':
      return HarvestStatus.done;
    case 'GROWING':
      return HarvestStatus.growing;
    default:
      return HarvestStatus.unknown;
  }
}

class HarvestInfo {
  final DateTime? harvestedAt;
  final String? breedId;
  final String? breedName;
  final int initialQuantity;
  final int currentQuantity;
  final int lostQuantity;
  final double harvestRate;
  final int? ageDays;
  final int? totalGrowDays;
  final int? growthPercent;
  final DateTime? harvestTargetDate;
  final int? daysRemaining;
  final HarvestStatus status;
  final String label;
  final double? expectedWeightKg;
  final int? expectedTotalKg;

  const HarvestInfo({
    required this.harvestedAt,
    required this.breedId,
    required this.breedName,
    required this.initialQuantity,
    required this.currentQuantity,
    required this.lostQuantity,
    required this.harvestRate,
    required this.ageDays,
    required this.totalGrowDays,
    required this.growthPercent,
    required this.harvestTargetDate,
    required this.daysRemaining,
    required this.status,
    required this.label,
    required this.expectedWeightKg,
    required this.expectedTotalKg,
  });

  factory HarvestInfo.fromJson(Map<String, dynamic> json) {
    return HarvestInfo(
      harvestedAt: _parseDate(json['harvested_at']),
      breedId: json['breed_id']?.toString(),
      breedName: json['breed_name']?.toString(),
      initialQuantity: _parseInt(json['initial_quantity']),
      currentQuantity: _parseInt(json['current_quantity']),
      lostQuantity: _parseInt(json['lost_quantity']),
      harvestRate: (json['harvest_rate'] as num?)?.toDouble() ?? 0,
      ageDays: json['age_days'] == null ? null : _parseInt(json['age_days']),
      totalGrowDays: json['total_grow_days'] == null ? null : _parseInt(json['total_grow_days']),
      growthPercent: json['growth_percent'] == null ? null : _parseInt(json['growth_percent']),
      harvestTargetDate: _parseDate(json['harvest_target_date']),
      daysRemaining: json['days_remaining'] == null ? null : _parseInt(json['days_remaining']),
      status: _parseHarvestStatus(json['harvest_status']?.toString()),
      label: json['harvest_label']?.toString() ?? '',
      expectedWeightKg: (json['expected_weight_kg'] as num?)?.toDouble(),
      expectedTotalKg: json['expected_total_kg'] == null ? null : _parseInt(json['expected_total_kg']),
    );
  }

  /// Chuồng chưa gán giống thì không tính được lịch xuất chuồng.
  bool get hasSchedule => daysRemaining != null;

  /// Đã xuất chuồng rồi.
  bool get isHarvested => status == HarvestStatus.done;

  /// Đến lứa hoặc quá lứa - lúc này mới nên cho bấm nút xuất chuồng.
  bool get canHarvest =>
      status == HarvestStatus.ready ||
      status == HarvestStatus.overdue ||
      status == HarvestStatus.soon;
}

/// Một giống gà trong danh mục (dùng cho form thêm chuồng).
class Breed {
  final String idGiong;
  final String tenGiong;
  final String? mucDichNuoi;
  final int harvestDays;
  final double? trongLuongKg;
  final int soMuiVaccine;

  const Breed({
    required this.idGiong,
    required this.tenGiong,
    required this.mucDichNuoi,
    required this.harvestDays,
    required this.trongLuongKg,
    required this.soMuiVaccine,
  });

  factory Breed.fromJson(Map<String, dynamic> json) {
    return Breed(
      idGiong: json['id_giong']?.toString() ?? '',
      tenGiong: json['ten_giong']?.toString() ?? 'Không rõ',
      mucDichNuoi: json['muc_dich_nuoi']?.toString(),
      harvestDays: _parseInt(json['harvest_days']),
      trongLuongKg: (json['trong_luong_xuat_chuong_kg'] as num?)?.toDouble(),
      soMuiVaccine: _parseInt(json['so_mui_vaccine']),
    );
  }
}
