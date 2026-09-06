// Ép Node.js sử dụng trực tiếp DNS Google để giải mã chuỗi mongodb+srv của bạn
const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
// 1. Thêm dòng này để import file route
const poultryRoutes = require('./routes/poultry-routes');
const vaccinationRoutes = require('./routes/vaccinationRoutes');
const weatherRoutes = require('./routes/weatherRoutes');
const coopRoutes = require('./routes/coopRoutes');
const path = require('path');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// 2. Thêm dòng này để kết nối route vào ứng dụng
app.use('/api/poultry', poultryRoutes);
// Flow tiêm phòng cho chuồng trại (trước đây thiếu dòng này nên toàn bộ API tiêm phòng trả về 404)
app.use('/api/vaccination', vaccinationRoutes);
// Thời tiết + đánh giá môi trường chuồng (Open-Meteo, miễn phí, không cần API key)
app.use('/api/weather', weatherRoutes);
// Quản lý chuồng: thêm chuồng theo giống, tỷ lệ & lịch xuất chuồng
app.use('/api/coops', coopRoutes);
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
// Kết nối DB
mongoose.connect(process.env.MONGODB_URI, {})
    .then(() => {
        console.log('✅ Đã kết nối Database thành công!');
    })
    .catch((err) => {
        console.log('❌ Lỗi kết nối DB:', err);
    });

// Test route
app.get('/', (req, res) => {
    res.send('SmartFarm Vision API đang hoạt động!');
});

const PORT = process.env.PORT || 3000;
// Thêm '0.0.0.0' vào hàm listen
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server đang chạy tại mạng LAN: http://0.0.0.0:${PORT}`);
});