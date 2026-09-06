const mongoose = require('mongoose');

// Danh mục giống gà - đọc từ collection có sẵn "DanhMucGiong".
// phac_do_vaccine quyết định chuồng của giống này cần tiêm những mũi nào,
// harvest_days quyết định ngày dự kiến xuất chuồng.
const breedSchema = new mongoose.Schema(
    {
        _id: { type: String },
        id_giong: { type: String, required: true },
        ten_giong: { type: String, required: true },
        muc_dich_nuoi: { type: String, default: null },
        dac_diem_nhan_dien: { type: String, default: null },
        harvest_days: { type: Number, required: true },
        trong_luong_xuat_chuong_kg: { type: Number, default: null },
        phac_do_vaccine: [String],
    },
    { collection: 'DanhMucGiong', versionKey: false }
);

module.exports = mongoose.model('Breed', breedSchema);
