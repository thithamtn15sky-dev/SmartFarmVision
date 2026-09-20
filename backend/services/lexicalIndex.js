const mongoose = require('mongoose');

// BM25 cho collection BenhGiaCam, chạy ngay trong tiến trình Node.
//
// Vì sao tự cài thay vì dùng Atlas Search: kho chỉ 35 tài liệu, mỗi tài liệu chưa
// tới 530 ký tự. Dựng chỉ mục trong bộ nhớ mất vài mili-giây và không phải khai
// báo thêm search index trên Atlas. Khi kho lớn lên hàng nghìn tài liệu thì nên
// chuyển sang Atlas Search, chỉ cần thay phần thân hàm timKiem.
//
// Tham số theo bản BM25Okapi mà thực nghiệm đã dùng (k1 = 1.5, b = 0.75), để kết
// quả trên máy chủ khớp với bảng đánh giá ở chương 5 của báo cáo.

const K1 = 1.5;
const B = 0.75;
const CACHE_TTL_MS = 10 * 60 * 1000;

let cache = null;   // { at, docs, df, avgLen }

/// Tách từ theo ký tự chữ-số Unicode, giống hệt regex \w+ bên Python
/// để hai bên cùng chia từ như nhau.
function tachTu(text) {
    return String(text).toLowerCase().match(/[\p{L}\p{N}_]+/gu) || [];
}

/// Nạp toàn bộ tài liệu và dựng chỉ mục. Kho nhỏ nên đọc hết một lần rồi đệm lại.
async function buildIndex() {
    const rows = await mongoose.connection.db.collection('BenhGiaCam')
        .find({}, { projection: { noi_dung_goc: 1, phan_loai: 1, url_nguon: 1, benh_ma: 1, chunk_id: 1 } })
        .toArray();

    const docs = rows
        .filter((r) => String(r.noi_dung_goc || '').trim().length > 20)
        .map((r) => {
            const tokens = tachTu(r.noi_dung_goc);
            const tf = new Map();
            tokens.forEach((t) => tf.set(t, (tf.get(t) || 0) + 1));
            return {
                id: r.chunk_id || String(r._id),
                text: String(r.noi_dung_goc).trim(),
                phan_loai: r.phan_loai,
                url_nguon: r.url_nguon,
                benh_ma: r.benh_ma,
                tf,
                len: tokens.length,
            };
        });

    // df: mỗi từ xuất hiện trong bao nhiêu tài liệu.
    const df = new Map();
    docs.forEach((d) => {
        for (const t of d.tf.keys()) df.set(t, (df.get(t) || 0) + 1);
    });

    const avgLen = docs.reduce((s, d) => s + d.len, 0) / (docs.length || 1);
    cache = { at: Date.now(), docs, df, avgLen };
    return cache;
}

async function getIndex() {
    if (!cache || Date.now() - cache.at > CACHE_TTL_MS) await buildIndex();
    return cache;
}

/// Tìm theo BM25, có thể giới hạn theo mã bệnh và loại nội dung.
/// Trả về mảng { ...doc, score } đã sắp giảm dần.
async function timKiem(query, { topK = 20, codes = null, loaiNoiDung = null } = {}) {
    const { docs, df, avgLen } = await getIndex();
    const N = docs.length;
    if (N === 0) return [];

    const tuTruyVan = tachTu(query);
    if (tuTruyVan.length === 0) return [];

    const ketQua = [];
    for (const d of docs) {
        if (codes && !codes.includes(d.benh_ma)) continue;
        if (loaiNoiDung && !loaiNoiDung.includes(d.phan_loai)) continue;

        let score = 0;
        for (const t of tuTruyVan) {
            const f = d.tf.get(t);
            if (!f) continue;
            const n = df.get(t) || 0;
            // IDF theo công thức BM25 chuẩn, cộng 1 để không âm khi từ quá phổ biến.
            const idf = Math.log(1 + (N - n + 0.5) / (n + 0.5));
            score += idf * (f * (K1 + 1)) / (f + K1 * (1 - B + B * (d.len / avgLen)));
        }
        if (score > 0) ketQua.push({ ...d, score });
    }

    ketQua.sort((a, b) => b.score - a.score);
    return ketQua.slice(0, topK);
}

/// Xoá đệm, dùng sau khi cập nhật tri thức trong CSDL.
function xoaDem() {
    cache = null;
}

module.exports = { timKiem, xoaDem, tachTu };
