const express = require('express');
const router = express.Router();
const coopController = require('../controllers/coopController');

// Danh mục giống gà (đổ vào form thêm chuồng)
router.get('/breeds', coopController.getBreeds);

// Tạo chuồng mới - tự lọc vắc-xin theo phác đồ của giống
router.post('/', coopController.createCoop);

// Thông tin xuất chuồng: tỷ lệ sống, số ngày còn lại
router.get('/:coopId/harvest', coopController.getHarvestInfo);

// Xuất chuồng (đóng lứa nuôi)
router.post('/:coopId/harvest', coopController.harvestCoop);

// Ghi nhận hao hụt đàn
router.patch('/:coopId/quantity', coopController.updateQuantity);

module.exports = router;
