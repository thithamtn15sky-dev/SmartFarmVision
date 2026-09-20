const mongoose = require('mongoose');

// Truy xuất phác đồ điều trị / phòng ngừa từ collection BenhGiaCam.
//
// Đây chính là bước 2 trong pipeline RAG của notebook: sau khi đã xác định được
// bệnh, lọc cứng theo metadata benh_tag rồi lấy nội dung gốc kèm url_nguon.
// Nội dung và link đều đọc thẳng từ DB, KHÔNG để model tự sinh - model 2B được
// yêu cầu chép lại URL sẽ bịa ra link không tồn tại.

// Mọi cách gọi tên bệnh (nhãn app, benh_tag trong DB, tên tiếng Anh model hay
// trả về) đều quy về MÃ chuẩn trong constants/diseaseCodes.js. Trước đây bảng
// ánh xạ nằm rải trong file này còn notebook lại so trực tiếp benh_lien_quan với
// benh_tag - hai trường vốn viết khác nhau ở 3/5 bệnh, nên bộ lọc trượt.
const { DISEASE_CODES, toCode, labelOf, tagOf } = require('../constants/diseaseCodes');

const LABEL_TO_TAG = Object.fromEntries(DISEASE_CODES.map((d) => [d.label, d.tag]));
const TAG_TO_LABEL = Object.fromEntries(DISEASE_CODES.map((d) => [d.tag, d.label]));

/// Đưa nhãn bất kỳ về đúng benh_tag trong BenhGiaCam.
function resolveTag(label) {
    const ma = toCode(label);
    return ma ? tagOf(ma) : null;
}

/// Cứu trường hợp model trả về MÔ TẢ TRIỆU CHỨNG thay vì tên bệnh.
/// Ví dụ thật gặp phải: nhãn trả về là "Sưng phù mặt một bên" - đó là triệu chứng
/// của Coryza chứ không phải tên bệnh, và app hiển thị thẳng lên màn hình kết quả.
/// Hàm này dò ngược mô tả đó trong TrieuChung để tìm ra bệnh tương ứng.
async function labelFromSymptomText(raw) {
    if (!raw) return null;
    const text = String(raw).toLowerCase().trim();
    if (text.length < 8) return null;

    const rows = await mongoose.connection.db
        .collection('TrieuChung')
        .find({}, { projection: { mo_ta: 1, benh_lien_quan: 1, benh_ma: 1 } })
        .toArray();

    // So khớp theo TỪ chứ không theo chuỗi con: chữ trên chip của app
    // ("Sưng phù mặt một bên") diễn đạt khác mô tả trong CSDL
    // ("Sưng phù một hoặc hai bên mặt, mắt nhắm nghiền...") nên so chuỗi con trượt.
    const tuKhoa = (str) => new Set(
        str.toLowerCase()
            .replace(/[.,;:()]/g, ' ')
            .split(/\s+/)
            .filter((w) => w.length > 1)
    );
    const tuNhan = tuKhoa(text);
    if (tuNhan.size === 0) return null;

    let totNhat = null;
    let diemCaoNhat = 0;
    for (const row of rows) {
        const moTa = String(row.mo_ta || '');
        if (!moTa) continue;
        // Ưu tiên benh_ma (mã chuẩn) - benh_lien_quan chỉ là tên hiển thị.
        const raws = dsBenh(row);
        // Triệu chứng dùng chung nhiều bệnh thì không suy ra được bệnh nào.
        if (raws.length !== 1) continue;

        const tuMoTa = tuKhoa(moTa);
        let trung = 0;
        for (const w of tuNhan) if (tuMoTa.has(w)) trung++;
        const diem = trung / tuNhan.size;

        if (diem > diemCaoNhat) {
            diemCaoNhat = diem;
            totNhat = raws[0];
        }
    }

    // Phải trùng phần lớn số từ mới dám kết luận, tránh khớp bừa.
    if (diemCaoNhat >= 0.6 && totNhat) return canonicalLabel(totNhat);
    return null;
}

/// Đưa nhãn bất kỳ (dạng ngắn hay đầy đủ) về nhãn đầy đủ chuẩn.
function canonicalLabel(raw) {
    const ma = toCode(raw);
    return ma ? labelOf(ma) : null;
}

/// Lấy danh sách bệnh của một bản ghi TrieuChung.
/// Ưu tiên benh_ma do script normalize-disease-codes.js gắn; bản ghi cũ chưa có
/// mã thì lùi về benh_lien_quan để dữ liệu chưa migrate vẫn tra được.
function dsBenh(row) {
    const raw = (row.benh_ma && row.benh_ma.length) ? row.benh_ma : row.benh_lien_quan;
    return Array.isArray(raw) ? raw : [raw].filter(Boolean);
}

/// Danh mục triệu chứng đọc thẳng từ collection TrieuChung.
///
/// Trước đây phần kiến thức bệnh lý bị viết cứng 5 dòng trong poultryController.
/// Viết cứng nghĩa là mỗi lần chuyên gia cập nhật DB thì app vẫn nói theo bản cũ,
/// và app nói khác notebook. Đọc từ DB thì cả hai luôn khớp nhau.
///
/// viTri: nếu RAG hình ảnh chỉ ra được vùng cơ thể ('Phân' | 'Toàn thân' |
/// 'Đầu/Mào/Mắt' | 'Chân') thì các triệu chứng ở đúng vùng đó được đánh dấu ◀,
/// để model biết chỗ nào đáng soi kỹ trên ảnh.
async function getSymptomCatalog(viTri = null) {
    const rows = await mongoose.connection.db
        .collection('TrieuChung')
        .find({}, { projection: { mo_ta: 1, vi_tri_quan_sat: 1, benh_lien_quan: 1, benh_ma: 1 } })
        .toArray();
    if (rows.length === 0) return null;

    // Một triệu chứng có thể thuộc nhiều bệnh (vd "lông xù, rút cổ" thuộc cả
    // Cầu trùng lẫn Newcastle) nên phải trải ra, không lấy mỗi phần tử đầu.
    const byDisease = new Map();
    for (const row of rows) {
        const raws = dsBenh(row);
        for (const raw of raws) {
            const label = canonicalLabel(raw);
            if (!label) continue;
            if (!byDisease.has(label)) byDisease.set(label, []);
            byDisease.get(label).push({
                viTri: row.vi_tri_quan_sat || 'Không rõ',
                moTa: String(row.mo_ta || '').trim(),
            });
        }
    }
    if (byDisease.size === 0) return null;

    // Đếm mỗi mô tả xuất hiện ở bao nhiêu bệnh, để đưa triệu chứng ĐẶC TRƯNG lên trước.
    //
    // "Thở khò khè, rướn cổ há mỏ" nằm ở cả Newcastle, H5N1 lẫn Coryza; "lông xù,
    // rút cổ, ủ rũ" nằm ở cả Cầu trùng lẫn Newcastle. Gặp bằng chứng chồng chéo,
    // model 2B dồn hết về H5N1 (bệnh có nhiều triệu chứng nặng nhất).
    //
    // Định dạng ở đây đã đo thực nghiệm trên 5 ca bệnh, cùng ảnh và lời khai:
    //   - liệt kê nhiều dòng, mỗi triệu chứng 1 gạch đầu dòng kèm [vị trí]  -> 2/5
    //   - chỉ giữ triệu chứng đặc trưng, bỏ hẳn triệu chứng chung           -> 3/5
    //   - 1 DÒNG/BỆNH, đặc trưng trước rồi tới chung, không chú thích       -> 4/5  (chọn)
    // Thêm chú thích kiểu "(chung — ít giá trị phân biệt)" làm KÉM đi, vì khối
    // dài thêm và model 2B bị nhiễu. Giữ gọn quan trọng hơn giải thích nhiều.
    const soBenhTheoMoTa = new Map();
    for (const items of byDisease.values()) {
        for (const it of items) {
            soBenhTheoMoTa.set(it.moTa, (soBenhTheoMoTa.get(it.moTa) || 0) + 1);
        }
    }

    // Mô tả trong DB viết cho người đọc ("Triệu chứng thần kinh: Ngoẹo cổ...").
    // Bỏ tiền tố phân nhóm và dấu chấm cuối cho gọn khi nhồi vào prompt.
    const gonLai = (moTa) => moTa.replace(/^[^:]{0,30}:\s*/, '').replace(/\.\s*$/, '');

    const lines = [];
    for (const [label, items] of byDisease) {
        const rieng = items.filter((it) => (soBenhTheoMoTa.get(it.moTa) || 1) === 1);
        const chung = items.filter((it) => (soBenhTheoMoTa.get(it.moTa) || 1) > 1);
        const moTaList = [...rieng, ...chung].map((it) => gonLai(it.moTa));
        lines.push(`- ${label}: ${moTaList.join('; ')}.`);
    }

    // Gợi ý vùng cơ thể từ RAG hình ảnh: nêu riêng một dòng thay vì gắn thẻ vào
    // từng triệu chứng, để không phá format 1 dòng/bệnh vốn cho kết quả tốt nhất.
    if (viTri) {
        const coVungNay = [...byDisease.entries()]
            .filter(([, items]) => items.some((it) => it.viTri === viTri))
            .map(([label]) => label);
        if (coVungNay.length > 0) {
            lines.push('');
            lines.push(`RAG hình ảnh chỉ ra vùng "${viTri}" - hãy soi kỹ vùng này trên ảnh. `
                + `Các bệnh có dấu hiệu ở vùng đó: ${coVungNay.join(', ')}.`);
        }
    }

    return { labels: [...byDisease.keys()], text: lines.join('\n') };
}

/// Lấy phác đồ điều trị và phòng ngừa của một bệnh, kèm nguồn tham khảo.
/// Trả về null nếu không tra được để phía gọi tự xử lý.
async function getDiseaseKnowledge(label) {
    const ma = toCode(label);
    if (!ma) return null;
    const tag = tagOf(ma);

    // Lọc theo mã chuẩn; bản ghi chưa gắn mã vẫn bắt được qua benh_tag cũ.
    const docs = await mongoose.connection.db
        .collection('BenhGiaCam')
        .find(
            {
                $or: [{ benh_ma: ma }, { benh_ma: { $exists: false }, benh_tag: tag }],
                phan_loai: { $in: ['dieu_tri', 'phong_ngua'] },
            },
            { projection: { noi_dung_goc: 1, phan_loai: 1, url_nguon: 1 } }
        )
        .toArray();

    if (docs.length === 0) return null;

    // Định dạng "[Nguồn: url]" ở cuối mỗi mục, giống output của notebook.
    const format = (doc) => {
        const url = doc.url_nguon || 'Không rõ nguồn';
        return `${String(doc.noi_dung_goc).trim()} [Nguồn: ${url}]`;
    };

    const dieuTri = docs.filter((d) => d.phan_loai === 'dieu_tri').map(format);
    const phongNgua = docs.filter((d) => d.phan_loai === 'phong_ngua').map(format);
    const urls = [...new Set(docs.map((d) => d.url_nguon).filter(Boolean))];

    return { ma, tag, dieu_tri: dieuTri, phong_ngua: phongNgua, url_tham_khao: urls };
}

module.exports = {
    getDiseaseKnowledge, getSymptomCatalog, labelFromSymptomText,
    resolveTag, canonicalLabel, LABEL_TO_TAG, TAG_TO_LABEL,
};
