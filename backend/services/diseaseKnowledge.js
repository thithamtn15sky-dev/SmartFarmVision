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

// Tên gọi khác của từng bệnh. Model hay trả về tên rút gọn hoặc tên tiếng Anh
// ("Coryza", "H5N1", "Newcastle"), trước đây đều bị coi là không hợp lệ.
const ALIAS_TO_TAG = {
    'cúm gia cầm': 'Cúm gia cầm', 'cum gia cam': 'Cúm gia cầm',
    'h5n1': 'Cúm gia cầm', 'cúm a': 'Cúm gia cầm',
    'avian influenza': 'Cúm gia cầm', 'bird flu': 'Cúm gia cầm', 'hpai': 'Cúm gia cầm',
    'newcastle': 'Newcastle', 'gà rù': 'Newcastle', 'ga ru': 'Newcastle', 'ndv': 'Newcastle',
    'đậu gà': 'Đậu gà', 'dau ga': 'Đậu gà', 'fowl pox': 'Đậu gà', 'fowlpox': 'Đậu gà',
    'cầu trùng': 'Cầu trùng', 'cau trung': 'Cầu trùng',
    'coccidiosis': 'Cầu trùng', 'eimeria': 'Cầu trùng',
    'sổ mũi truyền nhiễm': 'Sổ mũi truyền nhiễm', 'so mui truyen nhiem': 'Sổ mũi truyền nhiễm',
    'coryza': 'Sổ mũi truyền nhiễm', 'avibacterium': 'Sổ mũi truyền nhiễm',
};

/// Đưa nhãn bất kỳ về đúng benh_tag trong BenhGiaCam.
function resolveTag(label) {
    if (!label) return null;
    const trimmed = String(label).trim();
    if (LABEL_TO_TAG[trimmed]) return LABEL_TO_TAG[trimmed];

    const normalized = trimmed.toLowerCase();

    // Khớp theo tên gọi khác, ưu tiên alias dài nhất để "cúm gia cầm" không bị
    // alias ngắn hơn cướp mất.
    const aliases = Object.keys(ALIAS_TO_TAG).sort((a, b) => b.length - a.length);
    for (const alias of aliases) {
        if (normalized.includes(alias)) return ALIAS_TO_TAG[alias];
    }

    // Model đôi khi trả nhãn hơi lệch (thiếu/thừa phần trong ngoặc),
    // nên đối chiếu thêm bằng cách so khớp lỏng.
    for (const [appLabel, tag] of Object.entries(LABEL_TO_TAG)) {
        const shortLabel = appLabel.replace(/\s*\(.*?\)\s*/g, '').toLowerCase();
        if (normalized.includes(shortLabel) || shortLabel.includes(normalized)) {
            return tag;
        }
    }
    return null;
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
        .find({}, { projection: { mo_ta: 1, benh_lien_quan: 1 } })
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
        const raws = Array.isArray(row.benh_lien_quan) ? row.benh_lien_quan : [row.benh_lien_quan];
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
    if (diemCaoNhat >= 0.6 && totNhat) {
        const tag = resolveTag(totNhat);
        if (tag) return TAG_TO_LABEL[tag] || tag;
    }
    return null;
}

// Ánh xạ ngược: benh_tag trong DB -> nhãn đầy đủ dùng trong app/notebook.
const TAG_TO_LABEL = {
    'Cúm gia cầm': 'Cúm gia cầm (H5N1)',
    'Newcastle': 'Newcastle (Gà rù)',
    'Đậu gà': 'Đậu gà',
    'Cầu trùng': 'Cầu trùng',
    'Sổ mũi truyền nhiễm': 'Sổ mũi truyền nhiễm (Coryza)',
};

/// Đưa nhãn bất kỳ (dạng ngắn hay đầy đủ) về nhãn đầy đủ chuẩn.
function canonicalLabel(raw) {
    const tag = resolveTag(raw);
    return tag ? TAG_TO_LABEL[tag] || tag : null;
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
        .find({}, { projection: { mo_ta: 1, vi_tri_quan_sat: 1, benh_lien_quan: 1 } })
        .toArray();
    if (rows.length === 0) return null;

    // Một triệu chứng có thể thuộc nhiều bệnh (vd "lông xù, rút cổ" thuộc cả
    // Cầu trùng lẫn Newcastle) nên phải trải ra, không lấy mỗi phần tử đầu.
    const byDisease = new Map();
    for (const row of rows) {
        const raws = Array.isArray(row.benh_lien_quan) ? row.benh_lien_quan : [row.benh_lien_quan];
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

module.exports = {
    getDiseaseKnowledge, getSymptomCatalog, labelFromSymptomText,
    resolveTag, canonicalLabel, LABEL_TO_TAG, TAG_TO_LABEL,
};
