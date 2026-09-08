const axios = require('axios');

// Sinh lời khuyên điều trị/phòng ngừa cho TỪNG CA BỆNH cụ thể.
//
// Đây là bước "Augmented Generation" của RAG: tài liệu lấy từ BenhGiaCam được
// đưa vào prompt làm ngữ cảnh, model đọc rồi tự viết lời khuyên bám theo tình
// trạng người nuôi mô tả - không chép nguyên văn tài liệu ra.
//
// Chống bịa nguồn: tài liệu được ĐÁNH SỐ [1], [2]... và model chỉ được trích dẫn
// bằng số. Sau đó số được ánh xạ ngược về url_nguon thật trong DB, số nào không
// tồn tại thì loại bỏ. Nhờ vậy model không thể tạo ra một đường link không có thật.

/// Bỏ đuôi "[Nguồn: ...]" khỏi nội dung gốc khi đưa vào ngữ cảnh,
/// vì nguồn đã được thể hiện bằng số thứ tự.
function stripSourceTag(text) {
    return String(text).replace(/\s*\[Nguồn:\s*.*?\]\s*$/, '').trim();
}

/// Ghép các chunk thành danh sách tài liệu có đánh số.
function buildNumberedSources(knowledge) {
    const sources = [];
    knowledge.dieu_tri.forEach((text) => sources.push({ loai: 'điều trị', text }));
    knowledge.phong_ngua.forEach((text) => sources.push({ loai: 'phòng ngừa', text }));
    return sources.map((s, index) => ({
        index: index + 1,
        loai: s.loai,
        noiDung: stripSourceTag(s.text),
        // Link thật, lấy lại từ đuôi [Nguồn: ...] của chunk gốc.
        url: (String(s.text).match(/\[Nguồn:\s*(.*?)\]\s*$/) || [])[1] || null,
    }));
}

/// Chỉ giữ những số trích dẫn thật sự tồn tại, đổi thành URL.
function resolveCitations(rawCitations, sources) {
    if (!Array.isArray(rawCitations)) return [];
    const urls = rawCitations
        .map((n) => sources.find((s) => s.index === Number(n)))
        .filter(Boolean)
        .map((s) => s.url)
        .filter(Boolean);
    return [...new Set(urls)];
}

/// Gọi model để viết lời khuyên dựa trên tài liệu đã truy xuất.
/// Trả về null nếu không sinh được, phía gọi sẽ tự có đường lùi.
async function generateAdvice({ vlmUrl, label, observation, aiFindings, knowledge }) {
    const sources = buildNumberedSources(knowledge);
    if (sources.length === 0) return null;

    const sourceBlock = sources
        .map((s) => `[${s.index}] (${s.loai}) ${s.noiDung}`)
        .join('\n\n');

    const prompt = `Bạn là bác sĩ thú y gia cầm đang tư vấn cho một hộ chăn nuôi.

CA BỆNH CỤ THỂ:
- Chẩn đoán: ${label}
- Người nuôi mô tả: "${observation || 'không mô tả thêm'}"
- Dấu hiệu ghi nhận trên ảnh: ${aiFindings || 'không có'}

TÀI LIỆU THÚ Y THAM CHIẾU:
${sourceBlock}

NHIỆM VỤ: Viết lời khuyên cho ĐÚNG ca bệnh trên, dựa hoàn toàn vào tài liệu tham chiếu.

QUY TẮC BẮT BUỘC:
1. DIỄN ĐẠT LẠI BẰNG LỜI CỦA BẠN, ngắn gọn, dễ làm theo. TUYỆT ĐỐI KHÔNG chép nguyên văn tài liệu.
2. Chỉ được dùng thông tin có trong tài liệu. KHÔNG thêm tên thuốc, liều lượng hay vắc-xin nào
   mà tài liệu không nhắc tới.
3. Mỗi ý PHẢI ghi số tài liệu đã dựa vào, trong trường "nguon" (ví dụ [1] thì ghi 1).
   Chỉ dùng các số từ 1 đến ${sources.length}.
4. Sắp xếp theo thứ tự ưu tiên: việc cần làm ngay trước, việc lâu dài sau.
5. Bám vào triệu chứng người nuôi mô tả để nói rõ nên làm gì trước.
6. Mỗi ý tối đa 2 câu. Tổng cộng 2-3 ý điều trị và 2-3 ý phòng ngừa.

Trả về JSON đúng cấu trúc:
{
  "dieu_tri": [{"noi_dung": "<lời khuyên bạn tự viết>", "nguon": [1]}],
  "phong_ngua": [{"noi_dung": "<lời khuyên bạn tự viết>", "nguon": [2]}]
}`;

    const response = await axios.post(
        `${vlmUrl}/v1/chat/completions`,
        {
            model: 'local-qwen3-vl',
            messages: [{ role: 'user', content: prompt }],
            temperature: 0,
            max_tokens: 1600,
            response_format: { type: 'json_object' },
            repeat_penalty: 1.15,
        },
        { timeout: 180000 }
    );

    const cleaned = response.data.choices[0].message.content
        .replace(/```json\n?/gi, '')
        .replace(/```\n?/gi, '')
        .trim();

    let parsed;
    try {
        parsed = JSON.parse(cleaned);
    } catch {
        return null;
    }

    const mapItems = (items) =>
        (Array.isArray(items) ? items : [])
            .map((item) => ({
                noiDung: String(item.noi_dung || '').trim(),
                nguon: resolveCitations(item.nguon, sources),
            }))
            .filter((item) => item.noiDung.length > 0);

    const dieuTri = mapItems(parsed.dieu_tri);
    const phongNgua = mapItems(parsed.phong_ngua);
    if (dieuTri.length === 0 && phongNgua.length === 0) return null;

    return {
        dieuTri,
        phongNgua,
        // Nguồn tham khảo luôn là toàn bộ tài liệu đã dùng làm ngữ cảnh.
        referenceUrls: [...new Set(sources.map((s) => s.url).filter(Boolean))],
    };
}

module.exports = { generateAdvice, buildNumberedSources, resolveCitations };
