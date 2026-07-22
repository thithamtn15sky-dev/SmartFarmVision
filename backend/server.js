// Ép Node.js sử dụng trực tiếp DNS Google để giải mã chuỗi mongodb+srv của bạn
const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
// 1. Thêm dòng này để import file route
const poultryRoutes = require('./routes/poultry-routes');

require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// 2. Thêm dòng này để kết nối route vào ứng dụng
app.use('/api/poultry', poultryRoutes);

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
app.listen(PORT, () => {
    console.log(`🚀 Server đang chạy tại http://localhost:${PORT}`);
});