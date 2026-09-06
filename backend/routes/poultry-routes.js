const express = require('express');
const router = express.Router();
const multer = require('multer');
const poultryController = require('../controllers/poultryController');
const path = require('path');

// 1. Cấu hình nơi lưu trữ và tên file cho multer
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/');
    },
    filename: function (req, file, cb) {
        // Tạo tên file duy nhất tránh trùng lặp
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'scan-' + uniqueSuffix + path.extname(file.originalname));
    }
});

// 2. Khởi tạo biến upload TẠI ĐÂY
const upload = multer({ storage: storage });

// 3. Khai báo các routes (BẮT BUỘC PHẢI NẰM DƯỚI biến upload)
router.get('/', poultryController.getAllScans);
router.get('/:id', poultryController.getScanById);

// Lúc này biến upload đã tồn tại nên sẽ không bị lỗi "before initialization" nữa
router.post('/analyze', upload.array('images', 8), poultryController.analyzeImages);

module.exports = router;