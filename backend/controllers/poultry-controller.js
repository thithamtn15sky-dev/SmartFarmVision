const Poultry = require('../models/poultry-model');

// Hàm thêm hồ sơ gà mới vào hệ thống
exports.createPoultryProfile = async (req, res) => {
    try {
        const newPoultry = new Poultry(req.body);
        await newPoultry.save();
        res.status(201).json({
            success: true,
            message: "Đã tạo hồ sơ gia cầm thành công",
            data: newPoultry
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};