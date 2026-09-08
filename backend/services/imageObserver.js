const axios = require('axios');

// Lượt QUAN SÁT ẢNH, tách rời khỏi lượt chẩn đoán.
//
// Vì sao phải tách: đo thực nghiệm cho thấy khi prompt vừa có danh sách bệnh vừa
// có lời khai người nuôi, model 2B CHÉP thẳng triệu chứng từ danh sách vào
// "visible_findings" để hợp thức hoá kết luận. Cùng tấm ảnh gà rù, hỏi trực tiếp
// "đầu có sưng phù, chân có xuất huyết không?" thì model trả lời "không, không có",
// nhưng trong bài chẩn đoán nó lại ghi "sưng phù đầu, xuất huyết dưới da chân".
// Thêm luật cấm trong prompt không chặn được triệt để.
//
// Ở lượt này model KHÔNG thấy tên bệnh, không thấy lời khai, nên không có gì
// để chép - buộc phải mô tả đúng thứ nhìn thấy.

const VUNG_QUAN_SAT = ['Đầu/Mào/Mắt', 'Thân/Lông', 'Chân', 'Phân/Nền chuồng'];

/// Mô tả thuần thị giác từng vùng cơ thể. Trả null nếu không mô tả được,
/// phía gọi sẽ tự có đường lùi.
async function describeImages({ vlmUrl, imageContents, timeout = 180000 }) {
    if (!imageContents || imageContents.length === 0) return null;

    const prompt = `Bạn là người quan sát ảnh, KHÔNG phải bác sĩ.

CẢNH BÁO: KHÔNG được mặc định trong ảnh có gà. Rất nhiều ảnh gửi lên KHÔNG phải gà,
hoặc là gà đã làm thịt. Hãy nhìn kỹ rồi mới kết luận. Nếu không thấy con gà nào,
phải nói thẳng là không có - TUYỆT ĐỐI KHÔNG tưởng tượng ra con gà.

NHIỆM VỤ 1 - PHÂN LOẠI ẢNH: nhìn ảnh và xác định trong ảnh THỰC SỰ có gì,
chọn ĐÚNG MỘT giá trị:
  - "ga_song"        : gà còn sống (đứng, nằm, đi lại) - còn nguyên lông, ở chuồng/sân/nền đất
  - "ga_chet"        : gà đã chết nhưng CÒN NGUYÊN LÔNG, nằm ở chuồng/nền đất
  - "ga_che_bien"    : gà đã làm thịt - đã vặt lông, đã luộc/nướng/quay, thịt sống đã mổ,
                       gà đặt trên đĩa/mâm/thớt/bàn ăn, hoặc đã chặt miếng
  - "khong_phai_ga"  : ảnh không có gà (người, vật khác, phong cảnh, ảnh mờ hẳn)
  - "khong_ro"       : không đủ căn cứ để kết luận

  QUY TẮC QUYẾT ĐỊNH cho "ga_che_bien" - phải thoả CẢ HAI:
    (a) TOÀN THÂN KHÔNG CÒN MỘT CỌNG LÔNG NÀO (đã vặt sạch), VÀ
    (b) da trơn màu vàng bóng hoặc nâu do nấu.
  Nếu còn NHÌN THẤY LÔNG ở bất kỳ đâu trên thân, cổ, cánh hay đuôi thì
  CHẮC CHẮN KHÔNG PHẢI "ga_che_bien" - dù nền có là đĩa, bàn hay tay người cầm.
  Bàn tay người đang giữ gà KHÔNG phải dấu hiệu gà đã làm thịt.
  Nếu phân vân giữa gà sống và gà đã chế biến, hãy chọn "khong_ro".

NHIỆM VỤ 2 - MÔ TẢ: Nếu có gà, mô tả khách quan những gì NHÌN THẤY theo từng vùng cơ thể.
Nếu KHÔNG có gà (khong_phai_ga), mọi vùng đều ghi "không quan sát được" và mô tả
thứ thực sự có trong ảnh vào trường "ly_do".

QUY TẮC BẮT BUỘC:
1. CHỈ mô tả thứ thực sự nhìn thấy: màu sắc, hình dạng, tư thế, vết bất thường trên da/lông.
2. Vùng nào ảnh không chụp tới hoặc quá mờ, PHẢI ghi đúng "không quan sát được".
   Thà ghi không thấy còn hơn đoán.
3. TUYỆT ĐỐI KHÔNG đoán tên bệnh, không dùng thuật ngữ chẩn đoán
   (không viết "xuất huyết", "phù nề", "viêm"...). Hãy tả bằng lời thường:
   ví dụ "da chân có vệt đỏ sẫm", "mào màu nhợt", "lông dựng lên".
4. Mỗi vùng tối đa 2 câu ngắn.

BẮT BUỘC trả về ĐỦ ${VUNG_QUAN_SAT.length} vùng sau, không được bỏ sót vùng nào.
Vùng nào không nhìn thấy thì vẫn phải có dòng riêng, ghi "không quan sát được":
${VUNG_QUAN_SAT.map((v, i) => `${i + 1}. ${v}`).join('\n')}

Trả về JSON đúng cấu trúc:
{
  "doi_tuong": "<ga_song | ga_chet | ga_che_bien | khong_phai_ga | khong_ro>",
  "ly_do": "<1 câu ngắn giải thích vì sao phân loại như vậy>",
  "quan_sat": [
    {"anh_so": 1, "vung": "${VUNG_QUAN_SAT[0]}", "mo_ta": "<điều nhìn thấy hoặc 'không quan sát được'>"}
  ]
}`;

    const response = await axios.post(
        `${vlmUrl}/v1/chat/completions`,
        {
            model: 'local-qwen3-vl',
            messages: [{ role: 'user', content: [{ type: 'text', text: prompt }, ...imageContents] }],
            temperature: 0,
            max_tokens: 1200,
            response_format: { type: 'json_object' },
            repeat_penalty: 1.15,
        },
        { timeout }
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

    const items = (Array.isArray(parsed.quan_sat) ? parsed.quan_sat : [])
        .map((row) => ({
            anhSo: Number(row.anh_so) || 1,
            vung: String(row.vung || 'Không xác định').trim(),
            moTa: String(row.mo_ta || '').trim(),
        }))
        .filter((row) => row.moTa.length > 0);

    const DOI_TUONG_HOP_LE = ['ga_song', 'ga_chet', 'ga_che_bien', 'khong_phai_ga', 'khong_ro'];
    const doiTuongRaw = String(parsed.doi_tuong || '').trim();
    const doiTuong = DOI_TUONG_HOP_LE.includes(doiTuongRaw) ? doiTuongRaw : 'khong_ro';

    if (items.length === 0) return null;

    // Vùng không quan sát được vẫn giữ lại: nói rõ "không thấy" cũng là thông tin,
    // và giúp người dùng biết nên chụp bổ sung góc nào.
    return {
        doiTuong,
        lyDo: String(parsed.ly_do || '').trim(),
        // Chỉ CHẶN khi chắc chắn không chẩn đoán được: gà đã làm thịt, hoặc không có gà.
        // "khong_ro" thì VẪN CHO QUA - chặn nhầm một con gà đang bệnh khiến người nuôi
        // không được giúp, tệ hơn nhiều so với việc lỡ chẩn đoán một ảnh khó.
        // (Đo được: ảnh gà sổ mũi có bàn tay người giữ từng bị nhận nhầm là gà đã
        // chế biến và bị chặn oan.)
        chanDoanDuoc: doiTuong !== 'ga_che_bien' && doiTuong !== 'khong_phai_ga',
        items,
        text: items.map((i) => `- [${i.vung}] ${i.moTa}`).join('\n'),
    };
}

module.exports = { describeImages, VUNG_QUAN_SAT };
