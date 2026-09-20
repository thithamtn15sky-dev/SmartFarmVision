const mongoose = require('mongoose');
const axios = require('axios');

// Truy xuất ngữ nghĩa hai chặng bằng Atlas Vector Search.
//
// Chặng 1: tìm trong TrieuChung ra các triệu chứng gần với mô tả thực tế nhất,
//          rồi lấy HỢP các benh_ma trong metadata của chúng để thu hẹp phạm vi.
// Chặng 2: tìm trong BenhGiaCam nhưng CHỈ trong các bệnh vừa thu hẹp được.
//
// Vì sao lấy hợp chứ không lấy một bệnh thắng phiếu: 2/11 triệu chứng thuộc nhiều
// bệnh cùng lúc ("lông xù, rút cổ, ủ rũ" có ở cả Cầu trùng lẫn Newcastle). Chốt
// sớm một bệnh ở chặng này là loại nhầm bệnh đúng trước khi mô hình kịp nhìn.
//
// Toàn bộ vector trong CSDL sinh bằng AITeamVN/Vietnamese_Embedding. Máy chủ
// embedding (scripts/embedding_server.py) phải dùng đúng mô hình đó.

const lexical = require('./lexicalIndex');

const EMBED_URL = process.env.EMBED_SERVER_URL || 'http://127.0.0.1:8082';
// Số ứng viên đưa cho reranker chấm lại, giống cấu hình đã đánh giá ở chương 5.
const RERANK_CANDIDATE_K = Number(process.env.RERANK_CANDIDATE_K || 20);
const SYMPTOM_TOP_K = Number(process.env.SYMPTOM_TOP_K || 3);
// Ngưỡng tin cậy cho triệu chứng khớp nhất - MẶC ĐỊNH TẮT (0).
//
// Đã thử đặt ngưỡng tuyệt đối và đo trên 12 câu (6 câu tả triệu chứng thật, 6 câu
// không liên quan như "máy bơm nước bị hỏng"): điểm của nhóm có triệu chứng thấp
// nhất là 0,702 còn nhóm không liên quan cao nhất là 0,705 - hai nhóm CHỒNG NHAU,
// không có lằn ranh nào cắt được. Vì vậy không dùng điểm số để quyết định có tin
// hay không; việc khẳng định bệnh trong prompt dựa vào tra cứu tất định
// (labelFromSymptomText) thay cho điểm tương đồng.
// Giữ tham số để hiệu chỉnh lại nếu đợt đánh giá đầy đủ tìm được ngưỡng tốt hơn.
const SYMPTOM_MIN_SCORE = Number(process.env.SYMPTOM_MIN_SCORE || 0);
const KNOWLEDGE_TOP_K = Number(process.env.KNOWLEDGE_TOP_K || 5);

/// Mã hoá một câu truy vấn thành vector. Trả null nếu dịch vụ chưa bật, để phía
/// gọi tự lùi về đường cũ thay vì làm hỏng cả lượt chẩn đoán.
async function embedQuery(text, { timeout = 20000 } = {}) {
    if (!text || !String(text).trim()) return null;
    try {
        const res = await axios.post(`${EMBED_URL}/embed`, { texts: [String(text)] }, { timeout });
        const vector = res.data?.vectors?.[0];
        return Array.isArray(vector) ? vector : null;
    } catch (err) {
        console.error('Không gọi được máy chủ embedding:', err.message);
        return null;
    }
}

/// CHẶNG 1 - tìm triệu chứng gần nhất, suy ra tập bệnh cần xét.
async function retrieveSymptoms(queryText, topK = SYMPTOM_TOP_K, { vector: sanCo = null } = {}) {
    const vector = sanCo || await embedQuery(queryText);
    if (!vector) return null;

    const rows = await mongoose.connection.db.collection('TrieuChung').aggregate([
        {
            $vectorSearch: {
                index: 'trieuchung_vector_index',
                path: 'embedding',
                queryVector: vector,
                // numCandidates phải lớn hơn limit; kho chỉ 11 bản ghi nên quét hết.
                numCandidates: 50,
                limit: topK,
            },
        },
        {
            $project: {
                mo_ta: 1, vi_tri_quan_sat: 1, benh_ma: 1, benh_lien_quan: 1,
                score: { $meta: 'vectorSearchScore' },
            },
        },
    ]).toArray();

    if (rows.length === 0) return null;

    // codes giữ cả top-K để không loại nhầm bệnh đúng ngay từ chặng đầu,
    // còn dangTin chỉ true khi triệu chứng khớp nhất đủ mạnh.
    const codes = [...new Set(rows.flatMap((r) => r.benh_ma || []))];
    const dangTin = rows[0].score >= SYMPTOM_MIN_SCORE;
    return { rows, codes, dangTin, vector };
}

/// CHẶNG 2 - lấy tài liệu phác đồ, chỉ trong các bệnh đã thu hẹp.
/// loaiNoiDung mặc định là điều trị và phòng ngừa, đúng thứ người nuôi cần.
async function retrieveKnowledge(queryText, codes, {
    topK = KNOWLEDGE_TOP_K,
    loaiNoiDung = ['dieu_tri', 'phong_ngua'],
    vector: sanCo = null,
} = {}) {
    if (!codes || codes.length === 0) return null;
    // Hai chặng dùng CHUNG một query nên mã hoá lại là phí; chặng 1 truyền vector sang.
    const vector = sanCo || await embedQuery(queryText);
    if (!vector) return null;

    const rows = await mongoose.connection.db.collection('BenhGiaCam').aggregate([
        {
            $vectorSearch: {
                index: 'vector_index',
                path: 'embedding',
                queryVector: vector,
                numCandidates: 100,
                limit: topK,
                filter: { benh_ma: { $in: codes }, phan_loai: { $in: loaiNoiDung } },
            },
        },
        {
            $project: {
                noi_dung_goc: 1, phan_loai: 1, url_nguon: 1, benh_ma: 1, chunk_id: 1,
                score: { $meta: 'vectorSearchScore' },
            },
        },
    ]).toArray();

    return rows.length > 0 ? rows : null;
}

/// Dựng phác đồ theo ĐÚNG khuôn getDiseaseKnowledge trả về, để treatmentAdvisor
/// và controller không phải sửa gì khi đổi sang truy xuất vector.
async function knowledgeFromVector(queryText, code, opts = {}) {
    const rows = await retrieveKnowledge(queryText, [code], opts);
    if (!rows) return null;

    const format = (d) => `${String(d.noi_dung_goc).trim()} [Nguồn: ${d.url_nguon || 'Không rõ nguồn'}]`;
    const dieuTri = rows.filter((d) => d.phan_loai === 'dieu_tri').map(format);
    const phongNgua = rows.filter((d) => d.phan_loai === 'phong_ngua').map(format);
    if (dieuTri.length === 0 && phongNgua.length === 0) return null;

    return {
        ma: code,
        nguon_truy_xuat: 'vector',
        diem: rows.map((d) => Number(d.score.toFixed(4))),
        dieu_tri: dieuTri,
        phong_ngua: phongNgua,
        url_tham_khao: [...new Set(rows.map((d) => d.url_nguon).filter(Boolean))],
    };
}

/// Gọi reranker chấm lại độ liên quan. Trả null nếu dịch vụ không sẵn sàng.
async function rerank(query, documents, { timeout = 60000 } = {}) {
    if (!documents || documents.length === 0) return null;
    try {
        const res = await axios.post(`${EMBED_URL}/rerank`, { query, documents }, { timeout });
        const scores = res.data?.scores;
        return Array.isArray(scores) && scores.length === documents.length ? scores : null;
    } catch (err) {
        console.error('Không gọi được reranker:', err.message);
        return null;
    }
}

/// CHIẾN LƯỢC ĐÃ CHỌN SAU THỰC NGHIỆM: BM25 lấy ứng viên rồi CrossEncoder xếp hạng lại.
///
/// Cấu hình này đạt điểm tổng cao nhất trong 12 pipeline đã đánh giá (0,826 so với
/// 0,794 của truy xuất thuần vector), chênh lệch vượt xa sàn nhiễu 0,0005 đo được.
/// Chi tiết ở mục 5.4 của báo cáo.
///
/// Lưu ý về quy mô: mỗi bệnh hiện chỉ có 3 tài liệu điều trị/phòng ngừa nên sau khi
/// lọc theo bệnh, BM25 và reranker gần như không còn gì để xếp hạng - kết quả trùng
/// với cách lấy toàn bộ. Giá trị của bước này nằm ở chỗ hệ thống vẫn đúng khi kho
/// tri thức mở rộng, chứ không phải cải thiện đo được ngay hôm nay.
async function knowledgeBestStrategy(queryText, code, {
    topK = KNOWLEDGE_TOP_K,
    loaiNoiDung = ['dieu_tri', 'phong_ngua'],
} = {}) {
    if (!code) return null;

    const ungVien = await lexical.timKiem(queryText, {
        topK: RERANK_CANDIDATE_K, codes: [code], loaiNoiDung,
    });
    if (ungVien.length === 0) return null;

    // Không có reranker thì vẫn dùng được thứ hạng BM25, chỉ kém hơn một chút.
    const diem = await rerank(queryText, ungVien.map((d) => d.text));
    const daXep = diem
        ? ungVien.map((d, i) => ({ ...d, rerank_score: diem[i] }))
            .sort((a, b) => b.rerank_score - a.rerank_score)
        : ungVien;
    const chon = daXep.slice(0, topK);

    const format = (d) => `${d.text} [Nguồn: ${d.url_nguon || 'Không rõ nguồn'}]`;
    const dieuTri = chon.filter((d) => d.phan_loai === 'dieu_tri').map(format);
    const phongNgua = chon.filter((d) => d.phan_loai === 'phong_ngua').map(format);
    if (dieuTri.length === 0 && phongNgua.length === 0) return null;

    return {
        ma: code,
        nguon_truy_xuat: diem ? 'bm25+reranker' : 'bm25',
        diem: chon.map((d) => Number((d.rerank_score ?? d.score).toFixed(4))),
        dieu_tri: dieuTri,
        phong_ngua: phongNgua,
        url_tham_khao: [...new Set(chon.map((d) => d.url_nguon).filter(Boolean))],
    };
}

/// Kiểm tra máy chủ embedding có sống không, dùng cho endpoint chẩn đoán sự cố.
async function healthCheck() {
    try {
        const res = await axios.get(`${EMBED_URL}/health`, { timeout: 5000 });
        return { ok: true, ...res.data };
    } catch (err) {
        return { ok: false, error: err.message, url: EMBED_URL };
    }
}

module.exports = {
    embedQuery, retrieveSymptoms, retrieveKnowledge, knowledgeFromVector,
    rerank, knowledgeBestStrategy, healthCheck,
    SYMPTOM_TOP_K, KNOWLEDGE_TOP_K, SYMPTOM_MIN_SCORE, EMBED_URL,
};
