const express = require('express');
const router = express.Router();
const vaccinationController = require('../controllers/vaccinationController');

// 1. Khởi tạo danh mục vắc-xin mẫu (chỉ chạy khi danh mục còn rỗng)
router.post('/vaccines/seed', vaccinationController.seedVaccines);

// 2. Danh mục vắc-xin chuẩn (kèm ngày tuổi tiêm & số ngày hiệu lực)
router.get('/vaccines', vaccinationController.getVaccineCatalog);

// 3. Danh sách toàn bộ chuồng (màn hình Coops)
router.get('/coops', vaccinationController.getAllCoops);

// 4. Tạo chuồng (tự động sinh lịch tiêm nhúng kèm)
router.post('/coops', vaccinationController.createCoop);

// 5. Quét trễ hẹn & phạt điểm an toàn
//    (đặt trên route động :coopId để không bị "check-overdue" nuốt mất)
router.post('/coops/check-overdue', vaccinationController.checkOverdueTasks);

// 6. Dashboard chi tiết chuồng & cảnh báo hiệu lực
router.get('/coops/:coopId/dashboard', vaccinationController.getCoopDashboard);

// 7. Xác nhận hoàn thành mũi tiêm
router.patch('/coops/:coopId/vaccines/:vaccineId/complete', vaccinationController.markVaccineCompleted);

module.exports = router;
