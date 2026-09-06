// Bảng tham chiếu phác đồ tiêm chuẩn.
//
// Dữ liệu demo trong collection "LichTiemPhong" chỉ mô tả thời điểm tiêm bằng
// chữ ("1 - 3 ngày tuổi") chứ không có 2 trường số mà logic tính lịch cần:
//   - inject_at_day: ngày tuổi chuẩn để sinh scheduled_date
//   - effectiveness_days: số ngày còn hiệu lực để cảnh báo hết tác dụng
// Thay vì ghi đè dữ liệu DB của trang trại, ta tra bảng này khi document thiếu
// trường. Nếu sau này DB có sẵn 2 trường đó thì giá trị trong DB được ưu tiên.

const VACCINE_DEFAULTS = {
  VX_MAREK: { inject_at_day: 1, effectiveness_days: 60 },
  VX_CAU_TRUNG: { inject_at_day: 3, effectiveness_days: 45 },
  VX_ND_IB_L1: { inject_at_day: 5, effectiveness_days: 14 },
  VX_DAU_GA: { inject_at_day: 7, effectiveness_days: 60 },
  VX_GUMBORO_L1: { inject_at_day: 10, effectiveness_days: 14 },
  VX_H5N1_L1: { inject_at_day: 14, effectiveness_days: 30 },
  VX_ND_IB_L2: { inject_at_day: 18, effectiveness_days: 45 },
  VX_THT: { inject_at_day: 25, effectiveness_days: 60 },
  VX_CORYZA: { inject_at_day: 35, effectiveness_days: 90 },
};

const FALLBACK = { inject_at_day: 0, effectiveness_days: 30 };

// Lấy ngày tuổi tiêm chuẩn của 1 vắc-xin (ưu tiên giá trị lưu trong DB).
function getInjectAtDay(vaccineId, vaccineDoc = null) {
  if (vaccineDoc && typeof vaccineDoc.inject_at_day === 'number') {
    return vaccineDoc.inject_at_day;
  }
  return (VACCINE_DEFAULTS[vaccineId] || FALLBACK).inject_at_day;
}

// Lấy số ngày hiệu lực của 1 vắc-xin (ưu tiên giá trị lưu trong DB).
function getEffectivenessDays(vaccineId, vaccineDoc = null) {
  if (vaccineDoc && typeof vaccineDoc.effectiveness_days === 'number') {
    return vaccineDoc.effectiveness_days;
  }
  return (VACCINE_DEFAULTS[vaccineId] || FALLBACK).effectiveness_days;
}

// Tính ngày dự kiến tiêm = ngày vào đàn + số ngày tuổi chuẩn.
function calcScheduledDate(flockStartDate, injectAtDay) {
  const scheduled = new Date(flockStartDate);
  scheduled.setDate(scheduled.getDate() + injectAtDay);
  return scheduled;
}

module.exports = {
  VACCINE_DEFAULTS,
  getInjectAtDay,
  getEffectivenessDays,
  calcScheduledDate,
};
