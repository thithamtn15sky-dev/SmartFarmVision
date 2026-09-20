// Gắn mã bệnh chuẩn (benh_ma) vào BenhGiaCam và TrieuChung.
//
// Chạy thử, không ghi gì:   node scripts/normalize-disease-codes.js
// Ghi thật vào CSDL:        node scripts/normalize-disease-codes.js --apply
//
// Script chạy lại được nhiều lần: bản ghi nào đã đúng mã thì bỏ qua. Tên hiển thị
// (benh_tag, benh_lien_quan) GIỮ NGUYÊN - chỉ thêm trường mới, không sửa dữ liệu cũ,
// nên nếu có sai sót thì phần còn lại của hệ thống vẫn chạy bình thường.

require('dotenv').config();
const mongoose = require('mongoose');
const { toCode } = require('../constants/diseaseCodes');

const APPLY = process.argv.includes('--apply');

async function main() {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;

    const ops = { BenhGiaCam: [], TrieuChung: [] };
    const khongNhanDien = [];

    // 1. BenhGiaCam: mỗi tài liệu thuộc đúng một bệnh -> benh_ma là chuỗi.
    const benhDocs = await db.collection('BenhGiaCam')
        .find({}, { projection: { benh_tag: 1, benh_ma: 1 } }).toArray();
    for (const doc of benhDocs) {
        const ma = toCode(doc.benh_tag);
        if (!ma) {
            khongNhanDien.push(`BenhGiaCam/${doc._id}: benh_tag = ${JSON.stringify(doc.benh_tag)}`);
            continue;
        }
        if (doc.benh_ma !== ma) ops.BenhGiaCam.push({ _id: doc._id, benh_ma: ma });
    }

    // 2. TrieuChung: một triệu chứng có thể thuộc nhiều bệnh -> benh_ma là mảng.
    const tcDocs = await db.collection('TrieuChung')
        .find({}, { projection: { benh_lien_quan: 1, benh_ma: 1, id_trieu_chung: 1 } }).toArray();
    for (const doc of tcDocs) {
        const raws = Array.isArray(doc.benh_lien_quan) ? doc.benh_lien_quan : [doc.benh_lien_quan];
        const codes = [...new Set(raws.map(toCode).filter(Boolean))].sort();
        const thieu = raws.filter((r) => r && !toCode(r));
        if (thieu.length > 0) {
            khongNhanDien.push(`TrieuChung/${doc.id_trieu_chung || doc._id}: ${JSON.stringify(thieu)}`);
        }
        if (codes.length === 0) continue;

        const hienTai = Array.isArray(doc.benh_ma) ? [...doc.benh_ma].sort() : null;
        const giongNhau = hienTai && hienTai.length === codes.length
            && hienTai.every((v, i) => v === codes[i]);
        if (!giongNhau) ops.TrieuChung.push({ _id: doc._id, benh_ma: codes });
    }

    console.log(`BenhGiaCam : ${benhDocs.length} bản ghi, cần cập nhật ${ops.BenhGiaCam.length}`);
    console.log(`TrieuChung : ${tcDocs.length} bản ghi, cần cập nhật ${ops.TrieuChung.length}`);
    if (khongNhanDien.length > 0) {
        console.log(`\n⚠️  Không nhận diện được ${khongNhanDien.length} giá trị (bỏ qua, không ghi):`);
        khongNhanDien.forEach((x) => console.log('   -', x));
    }

    if (!APPLY) {
        console.log('\n🔍 Chạy thử, chưa ghi gì. Thêm --apply để ghi thật.');
        const mau = [...ops.BenhGiaCam.slice(0, 3), ...ops.TrieuChung.slice(0, 3)];
        mau.forEach((x) => console.log('   sẽ đặt benh_ma =', JSON.stringify(x.benh_ma), 'cho', String(x._id)));
        return;
    }

    for (const [col, list] of Object.entries(ops)) {
        if (list.length === 0) continue;
        const res = await db.collection(col).bulkWrite(
            list.map((x) => ({
                updateOne: { filter: { _id: x._id }, update: { $set: { benh_ma: x.benh_ma } } },
            }))
        );
        console.log(`✅ ${col}: đã cập nhật ${res.modifiedCount} bản ghi`);
    }

    // 3. Kiểm chứng: sau khi gắn mã, mỗi mã phải nối được cả hai collection.
    console.log('\nĐối chiếu sau khi cập nhật:');
    const codes = await db.collection('BenhGiaCam').distinct('benh_ma');
    for (const ma of codes.sort()) {
        const soTaiLieu = await db.collection('BenhGiaCam').countDocuments({ benh_ma: ma });
        const soTrieuChung = await db.collection('TrieuChung').countDocuments({ benh_ma: ma });
        console.log(`   ${ma.padEnd(22)} ${String(soTaiLieu).padStart(2)} tài liệu · ${soTrieuChung} triệu chứng`);
    }
}

main()
    .catch((err) => { console.error('❌', err.message); process.exitCode = 1; })
    .finally(() => mongoose.disconnect());
