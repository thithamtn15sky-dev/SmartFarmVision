const Coop = require('../models/Coop');
const Breed = require('../models/Breed');
const Vaccine = require('../models/Vaccine');
const { computeHarvestInfo } = require('../utils/harvest');
const { getInjectAtDay, calcScheduledDate } = require('../constants/vaccineSchedule');

// ==========================================
// 1. DANH MỤC GIỐNG (để app đổ vào form thêm chuồng)
// ==========================================
exports.getBreeds = async (req, res) => {
    try {
        const breeds = await Breed.find().sort({ ten_giong: 1 }).lean();
        res.status(200).json({
            success: true,
            count: breeds.length,
            data: breeds.map(b => ({
                id_giong: b.id_giong,
                ten_giong: b.ten_giong,
                muc_dich_nuoi: b.muc_dich_nuoi,
                harvest_days: b.harvest_days,
                trong_luong_xuat_chuong_kg: b.trong_luong_xuat_chuong_kg,
                // Số mũi phải tiêm của riêng giống này.
                so_mui_vaccine: (b.phac_do_vaccine || []).length,
                phac_do_vaccine: b.phac_do_vaccine || [],
            })),
        });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Lỗi lấy danh mục giống', error: error.message });
    }
};

// ==========================================
// 2. TẠO CHUỒNG MỚI THEO GIỐNG
// ==========================================
// Khác với createCoop cũ (lấy TẤT CẢ vắc-xin trong danh mục), hàm này chỉ sinh
// đúng các mũi nằm trong phac_do_vaccine của giống. Gà Tam Hoàng chỉ cần 7 mũi
// nên không tạo thừa VX_THT và VX_CORYZA vốn dành cho gà đẻ/gà giống nuôi dài ngày.
exports.createCoop = async (req, res) => {
    try {
        const { id, name, breed_id, quantity, flock_start_date, farmId } = req.body;

        if (!name || !breed_id || !quantity || !flock_start_date) {
            return res.status(400).json({
                success: false,
                message: 'Thiếu thông tin bắt buộc: name, breed_id, quantity, flock_start_date.',
            });
        }

        const soLuong = Number(quantity);
        if (!Number.isFinite(soLuong) || soLuong <= 0) {
            return res.status(400).json({ success: false, message: 'Số lượng phải là số dương.' });
        }

        const startDate = new Date(flock_start_date);
        if (isNaN(startDate.getTime())) {
            return res.status(400).json({ success: false, message: 'Ngày vào đàn không hợp lệ.' });
        }

        const breed = await Breed.findOne({ id_giong: breed_id }).lean();
        if (!breed) {
            return res.status(404).json({ success: false, message: `Không tìm thấy giống "${breed_id}".` });
        }

        // Mã chuồng: tự sinh nếu người dùng không nhập, và phải là duy nhất.
        const coopId = (id && String(id).trim()) || `FLOCK-${Date.now().toString(36).toUpperCase()}`;
        if (await Coop.findById(coopId).lean()) {
            return res.status(409).json({ success: false, message: `Mã chuồng "${coopId}" đã tồn tại.` });
        }

        // Chỉ lấy các mũi thuộc phác đồ của giống này.
        const phacDo = breed.phac_do_vaccine || [];
        if (phacDo.length === 0) {
            return res.status(400).json({
                success: false,
                message: `Giống "${breed.ten_giong}" chưa khai báo phác đồ vắc-xin.`,
            });
        }

        const vaccines = await Vaccine.find({ id_vacxin: { $in: phacDo } }).lean();
        const vaccineById = new Map(vaccines.map(v => [v.id_vacxin, v]));

        // Giữ đúng thứ tự ngày tiêm; danh mục vắc-xin trong DB thiếu inject_at_day
        // nên lấy bổ sung từ bảng chuẩn.
        const records = phacDo
            .map(vaccineId => {
                const injectAtDay = getInjectAtDay(vaccineId, vaccineById.get(vaccineId));
                if (injectAtDay === undefined || injectAtDay === null) return null;
                const scheduled = calcScheduledDate(startDate, injectAtDay);
                return {
                    vaccine_id: vaccineId,
                    scheduled_date: scheduled,
                    status: 'PENDING',
                    completed_at: null,
                    administered_by: null,
                    _injectAtDay: injectAtDay,
                };
            })
            .filter(Boolean)
            .sort((a, b) => a._injectAtDay - b._injectAtDay)
            .map(({ _injectAtDay, ...record }) => record);

        if (records.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Không dựng được lịch tiêm: phác đồ của giống không khớp danh mục vắc-xin.',
            });
        }

        // Ngày dự kiến xuất chuồng tính theo số ngày nuôi của giống.
        const harvestTargetDate = new Date(startDate.getTime());
        harvestTargetDate.setDate(harvestTargetDate.getDate() + breed.harvest_days);

        const newCoop = new Coop({
            _id: coopId,
            farmId: farmId || 'FARM-01',
            name,
            breed_id: breed.id_giong,
            quantity: soLuong,
            initial_quantity: soLuong,
            current_quantity: soLuong,
            flock_start_date: startDate,
            harvest_target_date: harvestTargetDate,
            vaccination_records: records,
            vaccination_summary: {
                total_required: records.length,
                total_completed: 0,
                last_vaccine_completed: null,
                last_injected_at: null,
                next_due_vaccine: records[0].vaccine_id,
                next_due_date: records[0].scheduled_date,
            },
        });

        const saved = await newCoop.save();
        res.status(201).json({
            success: true,
            message: `Đã tạo chuồng "${name}" với ${records.length} mũi tiêm theo phác đồ ${breed.ten_giong}.`,
            data: {
                ...saved.toObject(),
                harvest: computeHarvestInfo(saved.toObject(), breed),
            },
        });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Lỗi tạo chuồng', error: error.message });
    }
};

// ==========================================
// 3. THÔNG TIN XUẤT CHUỒNG CỦA 1 CHUỒNG
// ==========================================
exports.getHarvestInfo = async (req, res) => {
    try {
        const coop = await Coop.findById(req.params.coopId).lean();
        if (!coop) return res.status(404).json({ success: false, message: 'Không tìm thấy chuồng.' });

        const breed = coop.breed_id ? await Breed.findOne({ id_giong: coop.breed_id }).lean() : null;
        res.status(200).json({
            success: true,
            data: {
                id: coop._id,
                name: coop.name,
                breed_name: breed ? breed.ten_giong : null,
                ...computeHarvestInfo(coop, breed),
            },
        });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Lỗi lấy thông tin xuất chuồng', error: error.message });
    }
};

// ==========================================
// 4. CẬP NHẬT SỐ CON CÒN SỐNG (ghi nhận hao hụt)
// ==========================================
exports.updateQuantity = async (req, res) => {
    try {
        const { current_quantity } = req.body;
        const soCon = Number(current_quantity);

        const coop = await Coop.findById(req.params.coopId);
        if (!coop) return res.status(404).json({ success: false, message: 'Không tìm thấy chuồng.' });

        const banDau = coop.initial_quantity ?? coop.quantity;
        if (!Number.isFinite(soCon) || soCon < 0 || soCon > banDau) {
            return res.status(400).json({
                success: false,
                message: `Số con còn sống phải nằm trong khoảng 0 - ${banDau}.`,
            });
        }

        coop.current_quantity = soCon;
        await coop.save();

        const breed = coop.breed_id ? await Breed.findOne({ id_giong: coop.breed_id }).lean() : null;
        res.status(200).json({
            success: true,
            message: 'Đã cập nhật số lượng đàn.',
            data: computeHarvestInfo(coop.toObject(), breed),
        });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Lỗi cập nhật số lượng', error: error.message });
    }
};

// ==========================================
// 5. XUẤT CHUỒNG
// ==========================================
// Đóng lứa nuôi: ghi lại ngày xuất và số con thực xuất, rồi chuyển chuồng sang
// trạng thái HARVESTED để màn danh sách tách sang tab "Đã xuất chuồng".
exports.harvestCoop = async (req, res) => {
    try {
        const coop = await Coop.findById(req.params.coopId);
        if (!coop) return res.status(404).json({ success: false, message: 'Không tìm thấy chuồng.' });

        if (coop.status === 'HARVESTED' || coop.status === 'SOLD') {
            return res.status(409).json({
                success: false,
                message: `Chuồng "${coop.name}" đã xuất chuồng trước đó rồi.`,
            });
        }

        const banDau = coop.initial_quantity ?? coop.quantity;
        // Cho phép sửa lại số con thực xuất, vì lúc bắt bán mới đếm chính xác được.
        const soThucXuat = req.body.final_quantity === undefined
            ? (coop.current_quantity ?? coop.quantity)
            : Number(req.body.final_quantity);

        if (!Number.isFinite(soThucXuat) || soThucXuat < 0 || soThucXuat > banDau) {
            return res.status(400).json({
                success: false,
                message: `Số con xuất chuồng phải nằm trong khoảng 0 - ${banDau}.`,
            });
        }

        coop.current_quantity = soThucXuat;
        coop.status = 'HARVESTED';
        coop.harvested_at = new Date();
        await coop.save();

        const breed = coop.breed_id ? await Breed.findOne({ id_giong: coop.breed_id }).lean() : null;
        const harvest = computeHarvestInfo(coop.toObject(), breed);

        res.status(200).json({
            success: true,
            message: `Đã xuất chuồng "${coop.name}": ${soThucXuat}/${banDau} con, tỷ lệ sống ${harvest.harvest_rate}%.`,
            data: { id: coop._id, name: coop.name, harvested_at: coop.harvested_at, ...harvest },
        });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Lỗi xuất chuồng', error: error.message });
    }
};
