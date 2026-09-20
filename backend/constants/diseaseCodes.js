// Mã bệnh chuẩn - một nguồn sự thật duy nhất cho cả backend, notebook và CSDL.
//
// Vì sao cần: cùng một bệnh nhưng mỗi nơi ghi một kiểu.
//   TrieuChung.benh_lien_quan : "Cúm gia cầm (H5N1)"
//   BenhGiaCam.benh_tag       : "Cúm gia cầm"
//   Model trả về              : "H5N1", "Avian Influenza", "cum gia cam"...
// Ba trong năm bệnh có tên lệch nhau như vậy, nên bộ lọc "lấy benh_lien_quan đem
// so với benh_tag" của notebook không khớp được. Đo trên tập đánh giá: 13/20 câu
// lấy về tài liệu lẫn của nhiều bệnh khác nhau, tức bước thu hẹp phạm vi không chạy.
//
// Cách sửa: mỗi bệnh có một MÃ không dấu, không ngoặc. CSDL lưu thêm trường
// benh_ma, mọi phép lọc so theo mã này. Tên hiển thị vẫn giữ nguyên để không
// phải sửa giao diện và không làm hỏng dữ liệu cũ.

const DISEASE_CODES = [
    {
        ma: 'cum_gia_cam',
        label: 'Cúm gia cầm (H5N1)',   // nhãn đầy đủ dùng trong app
        tag: 'Cúm gia cầm',            // benh_tag đang lưu trong BenhGiaCam
        aliases: ['h5n1', 'cúm a', 'avian influenza', 'bird flu', 'hpai'],
    },
    {
        ma: 'newcastle',
        label: 'Newcastle (Gà rù)',
        tag: 'Newcastle',
        aliases: ['gà rù', 'ga ru', 'ndv', 'newcastle disease'],
    },
    {
        ma: 'dau_ga',
        label: 'Đậu gà',
        tag: 'Đậu gà',
        aliases: ['fowl pox', 'fowlpox', 'avipox'],
    },
    {
        ma: 'cau_trung',
        label: 'Cầu trùng',
        tag: 'Cầu trùng',
        aliases: ['coccidiosis', 'eimeria'],
    },
    {
        ma: 'so_mui_truyen_nhiem',
        label: 'Sổ mũi truyền nhiễm (Coryza)',
        tag: 'Sổ mũi truyền nhiễm',
        aliases: ['coryza', 'infectious coryza', 'avibacterium'],
    },
];

const BY_CODE = new Map(DISEASE_CODES.map((d) => [d.ma, d]));

/// Bỏ dấu tiếng Việt, bỏ ngoặc đơn, gom khoảng trắng. Dùng để so khớp lỏng.
function normalize(text) {
    return String(text)
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
        .replace(/đ/gi, 'd')
        .replace(/\(.*?\)/g, ' ')
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

// Bảng tra dựng sẵn: mọi cách viết của một bệnh đều trỏ về mã của nó.
const LOOKUP = new Map();
for (const d of DISEASE_CODES) {
    for (const key of [d.ma, d.label, d.tag, ...d.aliases]) {
        LOOKUP.set(normalize(key), d.ma);
    }
}

/// Đưa một cách gọi bất kỳ về mã chuẩn. Trả null nếu không nhận ra.
function toCode(raw) {
    if (!raw) return null;
    const text = normalize(raw);
    if (!text) return null;

    if (LOOKUP.has(text)) return LOOKUP.get(text);

    // Model hay trả nhãn dài hơn hoặc ngắn hơn tên chuẩn ("nghi cúm gia cầm thể
    // độc lực cao"). So khớp chứa nhau, ưu tiên khoá dài nhất để "cúm gia cầm"
    // không bị một khoá ngắn hơn cướp mất.
    const keys = [...LOOKUP.keys()].sort((a, b) => b.length - a.length);
    for (const key of keys) {
        if (key.length >= 4 && (text.includes(key) || key.includes(text))) {
            return LOOKUP.get(key);
        }
    }
    return null;
}

/// Mã -> nhãn đầy đủ hiển thị cho người dùng.
function labelOf(code) {
    return BY_CODE.get(code)?.label || null;
}

/// Mã -> benh_tag cũ. Còn cần cho các bản ghi chưa gắn benh_ma.
function tagOf(code) {
    return BY_CODE.get(code)?.tag || null;
}

module.exports = {
    DISEASE_CODES,
    ALL_CODES: DISEASE_CODES.map((d) => d.ma),
    toCode,
    labelOf,
    tagOf,
    normalize,
};
