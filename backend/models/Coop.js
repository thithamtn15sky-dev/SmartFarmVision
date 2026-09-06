const mongoose = require('mongoose');

const vaccinationRecordSchema = new mongoose.Schema({
    vaccine_id: { type: String, required: true }, // Trỏ tới id_vacxin (VD: "VX_MAREK")
    // Ngày dự kiến tiêm (flock_start_date + inject_at_day).
    // KHÔNG để required: dữ liệu demo trong "ChuongTrai" không có trường này,
    // nếu bắt buộc thì mọi lệnh coop.save() (xác nhận đã tiêm) đều fail validation.
    // Controller sẽ tự bù ngày dự kiến khi đọc/ghi.
    scheduled_date: { type: Date, default: null },
    status: {
        type: String,
        enum: ['PENDING', 'COMPLETED', 'OVERDUE', 'SKIPPED'],
        default: 'PENDING'
    },
    completed_at: { type: Date, default: null },
    administered_by: { type: String, default: null }
}, { _id: false });

const vaccinationSummarySchema = new mongoose.Schema({
    total_required: { type: Number, default: 9 },
    total_completed: { type: Number, default: 0 },
    last_vaccine_completed: { type: String, default: null },
    last_injected_at: { type: Date, default: null },
    next_due_vaccine: { type: String, default: null },
    next_due_date: { type: Date, default: null }
}, { _id: false });

const coopSchema = new mongoose.Schema({
    _id: { type: String, required: true }, // Tùy chỉnh ID: "FLOCK-001", "FLOCK-002"...
    farmId: { type: String, default: 'FARM-01' },
    name: { type: String, required: true },
    species: { type: String, default: 'Gà' },
    // Giống gà, trỏ tới id_giong trong DanhMucGiong (VD: "G_TAM_HOANG").
    // Quyết định phác đồ vắc-xin và số ngày nuôi tới lúc xuất chuồng.
    breed_id: { type: String, default: null },
    quantity: { type: Number, required: true },
    // initial_quantity: số con lúc vào đàn, current_quantity: số con còn sống.
    // Hai số này dùng để tính tỷ lệ xuất chuồng (tỷ lệ sống).
    // Chuồng cũ chưa có 2 trường này thì lấy tạm theo quantity.
    initial_quantity: { type: Number, default: null },
    current_quantity: { type: Number, default: null },
    flock_start_date: { type: Date, required: true },
    // Ngày dự kiến xuất chuồng = flock_start_date + harvest_days của giống.
    harvest_target_date: { type: Date, default: null },
    // Thời điểm bấm nút xuất chuồng. Có giá trị nghĩa là đàn đã rời chuồng.
    harvested_at: { type: Date, default: null },
    status: { type: String, enum: ['ACTIVE', 'ISOLATED', 'SOLD', 'HARVESTED'], default: 'ACTIVE' },
    safety_score: { type: Number, default: 100 }, // BR-03
    vaccination_summary: { type: vaccinationSummarySchema, default: () => ({}) },
    vaccination_records: [vaccinationRecordSchema],
    createdAt: { type: Date, default: Date.now }
}, {
    _id: false,
    timestamps: true,
    // Dữ liệu chuồng thật của trang trại nằm ở collection "ChuongTrai",
    // không phải collection mặc định "coops" (đang rỗng).
    collection: 'ChuongTrai'
});

module.exports = mongoose.model('Coop', coopSchema);
