const Coop = require('../models/Coop');
const Vaccine = require('../models/Vaccine');
const Breed = require('../models/Breed');
const { computeHarvestInfo } = require('../utils/harvest');
const {
    getInjectAtDay,
    getEffectivenessDays,
    calcScheduledDate,
} = require('../constants/vaccineSchedule');

const MS_PER_DAY = 1000 * 60 * 60 * 24;
const DONE_STATUSES = ['COMPLETED', 'SKIPPED'];

// ==========================================
// HÀM DÙNG CHUNG
// ==========================================

// Nạp danh mục vắc-xin về dạng Map để tra cứu nhanh theo id_vacxin.
async function loadVaccineMap() {
    const vaccines = await Vaccine.find().lean();
    return new Map(vaccines.map(v => [v.id_vacxin, v]));
}

function diffInDays(target, from = new Date()) {
    return Math.ceil((new Date(target) - from) / MS_PER_DAY);
}

// Số ngày tuổi hiện tại của đàn.
function calcFlockAgeDays(flockStartDate) {
    return Math.max(0, Math.floor((Date.now() - new Date(flockStartDate)) / MS_PER_DAY));
}

// Gộp 1 bản ghi tiêm với thông tin vắc-xin + các mốc thời gian đã tính sẵn,
// để frontend chỉ việc hiển thị chứ không phải tính lại.
function buildRecordView(record, coop, vaccineMap) {
    const vaccine = vaccineMap.get(record.vaccine_id) || null;
    const injectAtDay = getInjectAtDay(record.vaccine_id, vaccine);
    const effectivenessDays = getEffectivenessDays(record.vaccine_id, vaccine);

    // Dữ liệu demo không lưu scheduled_date -> tự suy ra từ ngày vào đàn.
    const scheduledDate = record.scheduled_date
        ? new Date(record.scheduled_date)
        : calcScheduledDate(coop.flock_start_date, injectAtDay);

    const isDone = DONE_STATUSES.includes(record.status);
    const daysUntilDue = diffInDays(scheduledDate);

    // Quá hạn theo thực tế: chưa tiêm và đã trễ ngày dự kiến.
    // Tính động nên UI vẫn đúng kể cả khi cron check-overdue chưa chạy.
    const isOverdue = !isDone && daysUntilDue < 0;

    let effectiveUntil = null;
    let daysOfEffectRemaining = null;
    let isExpired = false;
    if (record.status === 'COMPLETED' && record.completed_at) {
        effectiveUntil = new Date(record.completed_at);
        effectiveUntil.setDate(effectiveUntil.getDate() + effectivenessDays);
        daysOfEffectRemaining = diffInDays(effectiveUntil);
        isExpired = daysOfEffectRemaining <= 0;
    }

    return {
        vaccine_id: record.vaccine_id,
        vaccine_name: vaccine ? vaccine.ten_vacxin : record.vaccine_id,
        disease_prevented: vaccine ? vaccine.benh_phong_ngua : null,
        standard_timing: vaccine ? vaccine.thoi_diem_tiem_chuan : null,
        method: vaccine ? vaccine.phuong_phap_cap : null,
        note: vaccine ? vaccine.luu_y : null,
        inject_at_day: injectAtDay,
        effectiveness_days: effectivenessDays,
        scheduled_date: scheduledDate,
        // Trạng thái hiển thị: nâng PENDING đã trễ hạn lên OVERDUE.
        status: isOverdue && record.status === 'PENDING' ? 'OVERDUE' : record.status,
        raw_status: record.status,
        completed_at: record.completed_at || null,
        administered_by: record.administered_by || null,
        days_until_due: daysUntilDue,
        is_overdue: isOverdue,
        effective_until: effectiveUntil,
        days_of_effect_remaining: daysOfEffectRemaining,
        is_expired: isExpired,
    };
}

// Danh sách mũi còn phải tiêm (gồm cả OVERDUE - lỗi cũ chỉ lọc mỗi PENDING
// nên chuồng trễ lịch bị nhảy cóc sang mũi sau), sắp xếp theo ngày dự kiến.
function getDueRecords(recordViews) {
    return recordViews
        .filter(r => !DONE_STATUSES.includes(r.raw_status))
        .sort((a, b) => new Date(a.scheduled_date) - new Date(b.scheduled_date));
}

// Tính lại vaccination_summary từ dữ liệu thực tế của các bản ghi.
function recalcSummary(coop, recordViews) {
    const completed = recordViews
        .filter(r => r.raw_status === 'COMPLETED')
        .sort((a, b) => new Date(b.completed_at) - new Date(a.completed_at));
    const due = getDueRecords(recordViews);

    coop.vaccination_summary.total_required = recordViews.length;
    coop.vaccination_summary.total_completed = completed.length;
    coop.vaccination_summary.last_vaccine_completed = completed.length ? completed[0].vaccine_id : null;
    coop.vaccination_summary.last_injected_at = completed.length ? completed[0].completed_at : null;
    coop.vaccination_summary.next_due_vaccine = due.length ? due[0].vaccine_id : null;
    coop.vaccination_summary.next_due_date = due.length ? due[0].scheduled_date : null;

    return coop.vaccination_summary;
}

// Ghi lại scheduled_date đã suy ra vào document để lần sau không phải tính lại
// (và để cron check-overdue truy vấn được theo ngày).
function backfillScheduledDates(coop, recordViews) {
    coop.vaccination_records.forEach((record, index) => {
        if (!record.scheduled_date && recordViews[index]) {
            record.scheduled_date = recordViews[index].scheduled_date;
        }
    });
}

// ==========================================
// 1. SEED DANH MỤC VACCINE CHUẨN
// ==========================================
exports.seedVaccines = async (req, res) => {
    try {
        const count = await Vaccine.countDocuments();
        if (count > 0) return res.status(400).json({ success: false, message: 'Dữ liệu Vaccine đã tồn tại.' });

        const data = [
            { id_vacxin: "VX_MAREK", ten_vacxin: "Vắc-xin Marek's Disease", benh_phong_ngua: "Bệnh Marek", thoi_diem_tiem_chuan: "1 ngày tuổi", inject_at_day: 1, effectiveness_days: 60, phuong_phap_cap: "Tiêm dưới da cổ" },
            { id_vacxin: "VX_CAU_TRUNG", ten_vacxin: "Vắc-xin Cầu trùng", benh_phong_ngua: "Bệnh Cầu trùng", thoi_diem_tiem_chuan: "1 - 3 ngày tuổi", inject_at_day: 3, effectiveness_days: 45, phuong_phap_cap: "Nhỏ miệng" },
            { id_vacxin: "VX_ND_IB_L1", ten_vacxin: "Vắc-xin Newcastle & IB (Lần 1)", benh_phong_ngua: "Bệnh Newcastle & IB", thoi_diem_tiem_chuan: "3 - 5 ngày tuổi", inject_at_day: 5, effectiveness_days: 14, phuong_phap_cap: "Nhỏ mắt" },
            { id_vacxin: "VX_DAU_GA", ten_vacxin: "Vắc-xin Đậu gà", benh_phong_ngua: "Bệnh Đậu gà", thoi_diem_tiem_chuan: "7 - 10 ngày tuổi", inject_at_day: 7, effectiveness_days: 60, phuong_phap_cap: "Chủng màng cánh" },
            { id_vacxin: "VX_GUMBORO_L1", ten_vacxin: "Vắc-xin Gumboro (Lần 1)", benh_phong_ngua: "Bệnh Gumboro", thoi_diem_tiem_chuan: "10 - 14 ngày tuổi", inject_at_day: 10, effectiveness_days: 14, phuong_phap_cap: "Uống/Nhỏ mắt" },
            { id_vacxin: "VX_H5N1_L1", ten_vacxin: "Vắc-xin Cúm gia cầm (H5N1)", benh_phong_ngua: "Cúm gia cầm", thoi_diem_tiem_chuan: "14 - 21 ngày tuổi", inject_at_day: 14, effectiveness_days: 30, phuong_phap_cap: "Tiêm dưới da cổ" },
            { id_vacxin: "VX_ND_IB_L2", ten_vacxin: "Vắc-xin Newcastle & IB (Lần 2)", benh_phong_ngua: "Bệnh Newcastle", thoi_diem_tiem_chuan: "18 - 21 ngày tuổi", inject_at_day: 18, effectiveness_days: 45, phuong_phap_cap: "Pha nước uống" },
            { id_vacxin: "VX_THT", ten_vacxin: "Vắc-xin Tụ huyết trùng", benh_phong_ngua: "Tụ huyết trùng", thoi_diem_tiem_chuan: "25 - 30 ngày tuổi", inject_at_day: 25, effectiveness_days: 60, phuong_phap_cap: "Tiêm dưới da" },
            { id_vacxin: "VX_CORYZA", ten_vacxin: "Vắc-xin Sổ mũi truyền nhiễm", benh_phong_ngua: "Bệnh Sổ mũi", thoi_diem_tiem_chuan: "4 - 6 tuần tuổi", inject_at_day: 35, effectiveness_days: 90, phuong_phap_cap: "Tiêm bắp" }
        ];
        const saved = await Vaccine.insertMany(data);
        res.status(201).json({ success: true, count: saved.length, message: 'Đã nạp danh mục Vaccine chuẩn.' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// ==========================================
// 2. DANH MỤC VẮC-XIN (kèm ngày tuổi/hiệu lực đã bù)
// ==========================================
exports.getVaccineCatalog = async (req, res) => {
    try {
        const vaccines = await Vaccine.find().lean();
        const data = vaccines
            .map(v => ({
                id_vacxin: v.id_vacxin,
                ten_vacxin: v.ten_vacxin,
                benh_phong_ngua: v.benh_phong_ngua,
                thoi_diem_tiem_chuan: v.thoi_diem_tiem_chuan,
                phuong_phap_cap: v.phuong_phap_cap || null,
                luu_y: v.luu_y || null,
                inject_at_day: getInjectAtDay(v.id_vacxin, v),
                effectiveness_days: getEffectivenessDays(v.id_vacxin, v),
            }))
            .sort((a, b) => a.inject_at_day - b.inject_at_day);

        res.status(200).json({ success: true, count: data.length, data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// ==========================================
// 3. DANH SÁCH CHUỒNG (cho màn hình Coops)
// ==========================================
exports.getAllCoops = async (req, res) => {
    try {
        const { farmId, status } = req.query;
        const filter = {};
        if (farmId) filter.farmId = farmId;
        if (status) filter.status = status;

        const coops = await Coop.find(filter).lean();
        const vaccineMap = await loadVaccineMap();
        // Nạp danh mục giống 1 lần để tính lịch xuất chuồng cho từng chuồng.
        const breeds = await Breed.find().lean();
        const breedMap = new Map(breeds.map(b => [b.id_giong, b]));

        const data = coops.map(coop => {
            const recordViews = (coop.vaccination_records || []).map(r => buildRecordView(r, coop, vaccineMap));
            const dueRecords = getDueRecords(recordViews);
            const completedCount = recordViews.filter(r => r.raw_status === 'COMPLETED').length;
            const overdueCount = recordViews.filter(r => r.is_overdue).length;
            const nextRecord = dueRecords.length ? dueRecords[0] : null;

            return {
                id: coop._id,
                farmId: coop.farmId,
                name: coop.name,
                species: coop.species,
                quantity: coop.quantity,
                status: coop.status,
                safety_score: coop.safety_score,
                flock_start_date: coop.flock_start_date,
                age_days: calcFlockAgeDays(coop.flock_start_date),
                total_required: recordViews.length,
                total_completed: completedCount,
                overdue_count: overdueCount,
                progress_percent: recordViews.length
                    ? Math.round((completedCount / recordViews.length) * 100)
                    : 0,
                next_due_vaccine: nextRecord ? nextRecord.vaccine_id : null,
                next_due_vaccine_name: nextRecord ? nextRecord.vaccine_name : null,
                next_due_date: nextRecord ? nextRecord.scheduled_date : null,
                days_until_due: nextRecord ? nextRecord.days_until_due : null,
                is_fully_vaccinated: dueRecords.length === 0,
                // Thông tin xuất chuồng: tỷ lệ sống và số ngày còn lại tới lứa.
                harvest: computeHarvestInfo(coop, breedMap.get(coop.breed_id) || null),
            };
        });

        res.status(200).json({ success: true, count: data.length, data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// ==========================================
// 4. TẠO CHUỒNG MỚI VÀ TỰ ĐỘNG SINH TOÀN BỘ LỊCH TIÊM NHÚNG
// ==========================================
exports.createCoop = async (req, res) => {
    try {
        const { id, name, quantity, flock_start_date, farmId, species } = req.body;

        if (!id || !name || !quantity || !flock_start_date) {
            return res.status(400).json({
                success: false,
                message: 'Thiếu thông tin bắt buộc: id, name, quantity, flock_start_date.'
            });
        }

        const existed = await Coop.findById(id);
        if (existed) {
            return res.status(409).json({ success: false, message: `Mã chuồng "${id}" đã tồn tại.` });
        }

        const startDate = new Date(flock_start_date);
        if (isNaN(startDate.getTime())) {
            return res.status(400).json({ success: false, message: 'flock_start_date không hợp lệ.' });
        }

        const vaccines = await Vaccine.find().lean();
        if (vaccines.length === 0) {
            return res.status(400).json({ success: false, message: 'Chưa khởi tạo danh mục Vaccine.' });
        }

        // Sắp xếp theo ngày tuổi tiêm (bù từ bảng chuẩn nếu DB chưa có trường này).
        const records = vaccines
            .map(vac => ({
                vaccine_id: vac.id_vacxin,
                injectAtDay: getInjectAtDay(vac.id_vacxin, vac),
            }))
            .sort((a, b) => a.injectAtDay - b.injectAtDay)
            .map(item => ({
                vaccine_id: item.vaccine_id,
                scheduled_date: calcScheduledDate(startDate, item.injectAtDay),
                status: 'PENDING',
                completed_at: null,
                administered_by: null
            }));

        const newCoop = new Coop({
            _id: id,
            farmId: farmId || 'FARM-01',
            name,
            species: species || 'Gà',
            quantity,
            flock_start_date: startDate,
            vaccination_records: records,
            vaccination_summary: {
                total_required: records.length,
                total_completed: 0,
                last_vaccine_completed: null,
                last_injected_at: null,
                next_due_vaccine: records[0].vaccine_id,
                next_due_date: records[0].scheduled_date
            }
        });

        const saved = await newCoop.save();
        res.status(201).json({ success: true, data: saved, message: 'Tạo chuồng và thiết lập lộ trình tiêm thành công.' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// ==========================================
// 5. XÁC NHẬN ĐÃ TIÊM (Atomic Update & Recalculate Summary)
// ==========================================
exports.markVaccineCompleted = async (req, res) => {
    try {
        const { coopId, vaccineId } = req.params;
        const { administered_by } = req.body;
        const completedAt = new Date();

        const coop = await Coop.findById(coopId);
        if (!coop) return res.status(404).json({ success: false, message: 'Không tìm thấy chuồng.' });

        const record = coop.vaccination_records.find(r => r.vaccine_id === vaccineId);
        if (!record) return res.status(404).json({ success: false, message: 'Không tìm thấy mã vắc-xin trong chuồng.' });

        // Chặn xác nhận trùng để không cộng dồn sai total_completed / safety_score.
        if (record.status === 'COMPLETED') {
            return res.status(409).json({
                success: false,
                message: `Mũi ${vaccineId} đã được xác nhận tiêm trước đó.`
            });
        }

        record.status = 'COMPLETED';
        record.completed_at = completedAt;
        record.administered_by = administered_by || 'Nhân viên trang trại';

        const vaccineMap = await loadVaccineMap();
        const recordViews = coop.vaccination_records.map(r => buildRecordView(r, coop, vaccineMap));

        backfillScheduledDates(coop, recordViews);
        recalcSummary(coop, recordViews);

        // Tăng chỉ số an toàn khi hoàn thành nhiệm vụ (BR-03)
        if (coop.safety_score < 100) {
            coop.safety_score = Math.min(100, coop.safety_score + 5);
        }

        await coop.save();

        res.status(200).json({
            success: true,
            data: {
                id: coop._id,
                name: coop.name,
                safety_score: coop.safety_score,
                summary: coop.vaccination_summary,
                completed_record: recordViews.find(r => r.vaccine_id === vaccineId),
            },
            message: 'Cập nhật trạng thái tiêm thành công.'
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// ==========================================
// 6. LẤY CHI TIẾT DASHBOARD (Giám sát chuồng & Cảnh báo hiệu lực)
// ==========================================
exports.getCoopDashboard = async (req, res) => {
    try {
        const { coopId } = req.params;
        const coop = await Coop.findById(coopId).lean();
        if (!coop) return res.status(404).json({ success: false, message: 'Không tìm thấy chuồng.' });

        const vaccineMap = await loadVaccineMap();
        const recordViews = (coop.vaccination_records || []).map(r => buildRecordView(r, coop, vaccineMap));

        const completedRecords = recordViews
            .filter(r => r.raw_status === 'COMPLETED')
            .sort((a, b) => new Date(b.completed_at) - new Date(a.completed_at));
        const dueRecords = getDueRecords(recordViews);
        const overdueRecords = recordViews.filter(r => r.is_overdue);

        // Câu 1: Chuồng này đã tiêm chưa?
        const isVaccinated = completedRecords.length > 0;
        const statusMsg = isVaccinated
            ? `Đã tiêm ${completedRecords.length}/${recordViews.length} mũi.`
            : 'Chuồng chưa tiêm mũi nào.';

        // Câu 2: Hiệu lực của mũi tiêm gần nhất
        let effectivenessMsg = 'Chưa có dữ liệu mũi tiêm trước.';
        const lastRecord = isVaccinated ? completedRecords[0] : null;
        if (lastRecord) {
            effectivenessMsg = lastRecord.days_of_effect_remaining > 0
                ? `Mũi ${lastRecord.vaccine_name} còn hiệu lực trong ${lastRecord.days_of_effect_remaining} ngày nữa.`
                : `CẢNH BÁO: Mũi ${lastRecord.vaccine_name} đã HẾT TÁC DỤNG từ ${Math.abs(lastRecord.days_of_effect_remaining)} ngày trước!`;
        }

        // Câu 3: Mũi tiếp theo cần tiêm gì (ưu tiên mũi quá hạn trước)
        let nextActionMsg = 'Đã hoàn thành toàn bộ phác đồ.';
        const nextRecord = dueRecords.length ? dueRecords[0] : null;
        if (nextRecord) {
            const dateStr = new Date(nextRecord.scheduled_date).toLocaleDateString('vi-VN');
            nextActionMsg = nextRecord.is_overdue
                ? `QUÁ HẠN: ${nextRecord.vaccine_name} đáng lẽ phải tiêm ngày ${dateStr} (trễ ${Math.abs(nextRecord.days_until_due)} ngày).`
                : `Tiếp theo: ${nextRecord.vaccine_name} vào ngày ${dateStr}.`;
        }

        res.status(200).json({
            success: true,
            data: {
                coop_info: {
                    id: coop._id,
                    farmId: coop.farmId,
                    name: coop.name,
                    species: coop.species,
                    quantity: coop.quantity,
                    status: coop.status,
                    flock_start_date: coop.flock_start_date,
                    age_days: calcFlockAgeDays(coop.flock_start_date),
                },
                // Summary tính lại từ dữ liệu thật, không phụ thuộc giá trị cũ đã lưu.
                coop_summary: {
                    total_required: recordViews.length,
                    total_completed: completedRecords.length,
                    overdue_count: overdueRecords.length,
                    progress_percent: recordViews.length
                        ? Math.round((completedRecords.length / recordViews.length) * 100)
                        : 0,
                    last_vaccine_completed: lastRecord ? lastRecord.vaccine_id : null,
                    last_injected_at: lastRecord ? lastRecord.completed_at : null,
                    next_due_vaccine: nextRecord ? nextRecord.vaccine_id : null,
                    next_due_date: nextRecord ? nextRecord.scheduled_date : null,
                },
                safety_score: coop.safety_score,
                q1_status_msg: statusMsg,
                q2_effectiveness_msg: effectivenessMsg,
                q3_next_action_msg: nextActionMsg,
                next_vaccine: nextRecord,
                last_completed_vaccine: lastRecord,
                action_required_tasks: dueRecords.filter(r => r.days_until_due <= 0),
                all_records: recordViews,
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// ==========================================
// 7. CRON JOB KIỂM TRA QUÁ HẠN & HẠ ĐIỂM (BR-03)
// ==========================================
exports.checkOverdueTasks = async (req, res) => {
    try {
        const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

        // Quét toàn bộ chuồng còn nuôi: dữ liệu demo chưa có scheduled_date nên
        // không thể lọc bằng query, phải suy ra ngày dự kiến rồi mới so sánh.
        const activeCoops = await Coop.find({ status: 'ACTIVE' });
        const vaccineMap = await loadVaccineMap();
        const updatedCoops = [];

        for (const coop of activeCoops) {
            const recordViews = coop.vaccination_records.map(r => buildRecordView(r, coop, vaccineMap));
            backfillScheduledDates(coop, recordViews);

            let hasNewOverdue = false;
            coop.vaccination_records.forEach((record, index) => {
                const view = recordViews[index];
                if (!view) return;
                if (record.status === 'PENDING' && new Date(view.scheduled_date) < twentyFourHoursAgo) {
                    record.status = 'OVERDUE';
                    hasNewOverdue = true;
                }
            });

            if (hasNewOverdue) {
                // Giảm 10 điểm an toàn đàn (không thấp hơn 0)
                coop.safety_score = Math.max(0, coop.safety_score - 10);
            }

            if (hasNewOverdue || coop.isModified()) {
                recalcSummary(coop, coop.vaccination_records.map(r => buildRecordView(r, coop, vaccineMap)));
                await coop.save();
                if (hasNewOverdue) updatedCoops.push(coop._id);
            }
        }

        res.status(200).json({
            success: true,
            updated_coops: updatedCoops,
            message: `Đã cập nhật trạng thái OVERDUE và hạ điểm an toàn của ${updatedCoops.length} chuồng trễ lịch.`
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
