const express = require('express');
const router = express.Router();
const weatherController = require('../controllers/weatherController');

// Thời tiết hiện tại + đánh giá mức độ phù hợp cho chuồng gia cầm.
// Dùng ?city=Cần Thơ hoặc ?lat=10.03&lon=105.78
router.get('/current', weatherController.getCurrentWeather);

module.exports = router;
