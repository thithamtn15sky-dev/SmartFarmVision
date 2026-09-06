const mongoose = require('mongoose');

// Truy xuất phác đồ điều trị / phòng ngừa từ collection BenhGiaCam.
//
// Đây chính là bước 2 trong pipeline RAG của notebook: sau khi đã xác định được
// bệnh, lọc cứng theo metadata benh_tag rồi lấy nội dung gốc kèm url_nguon.
// Nội dung và link đều đọc thẳng từ DB, KHÔNG để model tự sinh - model 2B được
// yêu cầu chép lại URL sẽ bịa ra link không tồn tại.

// Nhãn bệnh dùng trong app khác với benh_tag lưu trong DB nên phải ánh xạ.
const LABEL_TO_TAG = {
    'Cúm gia cầm (H5N1)': 'Cúm gia cầm',
    'Newcastle (Gà rù)': 'Newcastle',
    'Newcastle': 'Newcastle',
    'Đậu gà': 'Đậu gà',
    'Cầu trùng': 'Cầu trùng',
    'Sổ mũi truyền nhiễm (Coryza)': 'Sổ mũi truyền nhiễm',
};

/// Đưa nhãn bất kỳ về đúng benh_tag trong BenhGiaCam.
function resolveTag(label) {
    if (!label) return null;
    const trimmed = String(label).trim();
    if (LABEL_TO_TAG[trimmed]) return LABEL_TO_TAG[trimmed];

    // Model đôi khi trả nhãn hơi lệch (thiếu/thừa phần trong ngoặc),
    // nên đối chiếu thêm bằng cách so khớp lỏng.
    const normalized = trimmed.toLowerCase();
    for (const [appLabel, tag] of Object.entries(LABEL_TO_TAG)) {
        const shortLabel = appLabel.replace(/\s*\(.*?\)\s*/g, '').toLowerCase();
        if (normalized.includes(shortLabel) || shortLabel.includes(normalized)) {
            return tag;
        }
    }
    return null;
}

/// Lấy phác đồ điều trị và phòng ngừa của một bệnh, kèm nguồn tham khảo.
/// Trả về null nếu không tra được để phía gọi tự xử lý.
async function getDiseaseKnowledge(label) {
    const tag = resolveTag(label);
    if (!tag) return null;

    const docs = await mongoose.connection.db
        .collection('BenhGiaCam')
        .find(
            { benh_tag: tag, phan_loai: { $in: ['dieu_tri', 'phong_ngua'] } },
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

    return { tag, dieu_tri: dieuTri, phong_ngua: phongNgua, url_tham_khao: urls };
}

module.exports = { getDiseaseKnowledge, resolveTag, LABEL_TO_TAG };
