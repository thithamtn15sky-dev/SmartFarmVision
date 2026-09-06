const mongoose = require('mongoose');

const vaccineSchema = new mongoose.Schema({
    // Dữ liệu demo lưu _id dạng chuỗi hex nên khai báo String để Mongoose khỏi ép kiểu ObjectId.
    _id: { type: String },
    id_vacxin: { type: String, required: true, unique: true }, // VD: "VX_MAREK", "VX_ND_IB_L1"
    ten_vacxin: { type: String, required: true },
    benh_phong_ngua: { type: String, required: true },
    thoi_diem_tiem_chuan: { type: String, required: true },
    // 2 trường số dưới đây không có trong dữ liệu demo "LichTiemPhong".
    // Khi thiếu, controller tra bảng constants/vaccineSchedule.js để bù,
    // nên không đặt required để tránh chặn việc đọc/ghi danh mục.
    inject_at_day: { type: Number, default: null }, // Ngày tuổi chuẩn để tự động tính lịch
    effectiveness_days: { type: Number, default: null }, // Số ngày hiệu lực
    phuong_phap_cap: { type: String, default: null },
    luu_y: { type: String, default: null }
}, {
    // Danh mục vắc-xin thật nằm ở collection "LichTiemPhong",
    // không phải collection mặc định "vaccines" (đang rỗng).
    collection: 'LichTiemPhong'
});

module.exports = mongoose.model('Vaccine', vaccineSchema);
