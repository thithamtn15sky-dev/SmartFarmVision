const PoultryScan = require('../models/PoultryScan');
const axios = require('axios');
const fs = require('fs');
const { getDiseaseKnowledge } = require('../services/diseaseKnowledge');
const { generateAdvice } = require('../services/treatmentAdvisor');

// Địa chỉ llama-server đang chạy model Qwen3-VL (notebook SmartFarmVLM).
// Đặt VLM_SERVER_URL trong .env nếu chạy model ở port khác.
// Lưu ý: model phải được khởi động KÈM --mmproj thì mới nhìn được ảnh.
const VLM_SERVER_URL = process.env.VLM_SERVER_URL || 'http://127.0.0.1:8081';

// Ảnh trước đây được lưu kèm host lúc quét (vd http://127.0.0.1:3000/uploads/x.jpg).
// Bản ghi đó máy khác không mở được, và chỉ cần đổi WiFi là toàn bộ ảnh cũ hỏng link.
// Vì vậy khi trả về luôn dựng lại URL theo host mà client đang gọi tới.
function toAbsoluteUrl(req, stored) {
    if (!stored) return null;
    let path = String(stored);
    if (/^https?:\/\//i.test(path)) {
        try { path = new URL(path).pathname; } catch { return stored; }
    }
    if (!path.startsWith('/')) path = `/${path}`;
    return `${req.protocol}://${req.get('host')}${path}`;
}
// Lấy danh sách kết quả chẩn đoán (lịch sử scan).
// Trả bản rút gọn: phần phác đồ điều trị rất dài, danh sách không cần tới,
// chỉ khi mở chi tiết mới lấy đầy đủ qua getScanById.
exports.getAllScans = async (req, res) => {
    try {
        const limit = Math.min(Number(req.query.limit) || 50, 200);
        const scans = await PoultryScan.find()
            .sort({ scannedAt: -1 })
            .limit(limit)
            .select('scannedAt basicInfo media.imageUrls clinicalFindings.generalDescription aiDiagnosis.predictions aiDiagnosis.requiresExpertReview humanVerification.isVerified')
            .lean();

        const data = scans.map(scan => {
            const predictions = scan.aiDiagnosis?.predictions || [];
            const top = predictions[0] || null;
            return {
                id: scan._id,
                scannedAt: scan.scannedAt,
                poultryType: scan.basicInfo?.poultryType || 'Gà',
                status: scan.basicInfo?.currentStatus || 'Chưa rõ',
                thumbnail: toAbsoluteUrl(req, (scan.media?.imageUrls || [])[0]),
                imageCount: (scan.media?.imageUrls || []).length,
                observation: scan.clinicalFindings?.generalDescription || null,
                diseaseName: top ? top.diseaseName : 'Chưa xác định',
                confidenceScore: top ? top.confidenceScore : 0,
                requiresExpertReview: scan.aiDiagnosis?.requiresExpertReview === true,
                isVerified: scan.humanVerification?.isVerified === true,
            };
        });

        res.status(200).json({ success: true, count: data.length, data });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Lỗi server', error: error.message });
    }
};

// Lấy chi tiết 1 kết quả chẩn đoán (để show lên màn hình kết quả Flutter)
exports.getScanById = async (req, res) => {
    try {
        const scan = await PoultryScan.findById(req.params.id).lean();
        if (!scan) return res.status(404).json({ success: false, message: 'Không tìm thấy dữ liệu' });

        // Dựng lại link ảnh theo host đang gọi để máy nào mở cũng thấy ảnh.
        if (scan.media?.imageUrls) {
            scan.media.imageUrls = scan.media.imageUrls.map(u => toAbsoluteUrl(req, u));
        }
        res.status(200).json({ success: true, data: scan });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Lỗi khi lấy dữ liệu', error: error.message });
    }
};
exports.analyzeImages = async (req, res) => {
    try {
        const files = req.files;
        if (!files || files.length === 0) {
            return res.status(400).json({ success: false, message: 'Vui lòng tải lên ít nhất 1 ảnh' });
        }

        // 1. Lưu đường dẫn TƯƠNG ĐỐI vào MongoDB, không gắn cứng IP.
        // Link tuyệt đối sẽ được dựng lại theo host của client khi đọc ra.
        const savedImageUrls = files.map(file => `/uploads/${file.filename}`);

        // 2. Đọc file từ ổ cứng thành Base64 để GỬI SANG AI SERVER
        const imageContents = files.map(file => {
            const base64Image = fs.readFileSync(file.path, { encoding: 'base64' });
            // Ép kiểu về image/jpeg nếu Flutter không gửi đúng định dạng ảnh
            const mimeType = file.mimetype.includes('image') ? file.mimetype : 'image/jpeg';
            return {
                type: 'image_url',
                image_url: {
                    url: `data:${mimeType};base64,${base64Image}`
                }
            };
        });

        // 3. Chuẩn bị Prompt
        // Lời khai của người nuôi (nhập ở màn Preview). Đây là bằng chứng đáng tin
        // hơn thị giác của model 2B, vốn không phân giải nổi chi tiết như màu phân.
        const rawObservation = (req.body.observation || '').trim();

        // Lời khai PHẢI đặt ở CUỐI prompt, ngay trước schema.
        // Đã đo thực nghiệm trên chính model này với cùng 1 ảnh gà rù:
        //   - lời khai đặt đầu prompt -> H5N1 85% (SAI, ảnh lấn át lời khai)
        //   - lời khai đặt cuối prompt -> Newcastle 95% (ĐÚNG)
        // Nguyên nhân là hiệu ứng recency: model coi trọng phần cuối prompt hơn.
        const observationBlock = rawObservation
            ? `*** QUAN TRỌNG NHẤT - NGƯỜI NUÔI TRỰC TIẾP QUAN SÁT ĐƯỢC: "${rawObservation}" ***
        Lời khai này ĐÁNG TIN HƠN hình ảnh, vì ảnh chỉ ghi lại một khoảnh khắc và không thấy được
        hành vi, tiếng thở hay phân của gà. HÃY ƯU TIÊN LỜI KHAI khi chọn bệnh.`
            : `*** NGƯỜI NUÔI KHÔNG MÔ TẢ GÌ THÊM ***
        Chỉ có ảnh làm bằng chứng nên độ tin cậy tối đa là 60, và phải nhắc người nuôi bổ sung mô tả triệu chứng.`;

        const prompt = `Bạn là một chuyên gia y tế thú y gia cầm. Hãy chẩn đoán bằng cách KẾT HỢP lời khai của người nuôi với hình ảnh.

        KIẾN THỨC BỆNH LÝ (chỉ dùng để ĐỐI CHIẾU, KHÔNG được chép lại):
        - Cúm gia cầm (H5N1): Mào tích tím tái, sưng phù đầu, xuất huyết dưới da chân, chết đột ngột.
        - Sổ mũi truyền nhiễm (Coryza): Sưng phù một hoặc hai bên mặt, mắt nhắm nghiền, có dịch nhầy hôi, ho hen.
        - Đậu gà: Nổi mụn sần sùi màu nâu ở mào, yếm, quanh mắt.
        - Newcastle (Gà rù): Ngoẹo cổ, liệt chân, tiêu chảy phân xanh/trắng, thở khò khè.
        - Cầu trùng: Tiêu chảy phân lẫn máu tươi hoặc phân sáp nâu, lông xù, ủ rũ.

        QUY TẮC BẮT BUỘC:
        1. CHỐNG BỊA ĐẶT: "visible_findings" CHỈ được ghi những gì bạn THẬT SỰ nhìn thấy trong ảnh.
           Nếu ảnh không nhìn rõ mào/mặt/chân/phân thì ghi thẳng "không quan sát được".
           NGHIÊM CẤM chép triệu chứng từ phần KIẾN THỨC BỆNH LÝ vào visible_findings để hợp thức hóa kết luận.
        2. Lời khai của người nuôi được ưu tiên hơn suy đoán từ ảnh. Nếu lời khai mâu thuẫn với ảnh, hãy nêu rõ trong "luu_y".
        3. Liệt kê ĐÚNG 2 bệnh khả dĩ nhất trong "differential_diagnoses", xếp theo độ tin cậy giảm dần.
        4. HẠ ĐỘ TIN CẬY khi bằng chứng yếu:
           - Chỉ có ảnh, không có lời khai: confidence tối đa 60.
           - Ảnh mờ/không thấy triệu chứng đặc trưng: confidence tối đa 50.
           - Chỉ được vượt 85 khi ảnh VÀ lời khai cùng chỉ về một bệnh.
        5. Nếu không đủ căn cứ, đặt "most_likely_label" = "Không đủ bằng chứng" và đề nghị mời thú y.
        6. Trả lời NGẮN GỌN để JSON không bị cắt giữa chừng.
        7. KHÔNG tự nghĩ ra phác đồ điều trị, tên thuốc hay liều lượng. Phác đồ chính thức
           được hệ thống lấy riêng từ cơ sở dữ liệu thú y kèm link nguồn.
           "recommended_next_steps" chỉ ghi các việc cần làm NGAY tại chuồng
           (ví dụ: cách ly con bệnh, thu gom xác, khử trùng, gọi thú y).

        ${observationBlock}

        Xuất kết quả BẮT BUỘC theo đúng cấu trúc JSON sau (tự điền nội dung thật, không copy ví dụ):
        {
        "is_chicken": true,
        "most_likely_label": "<tên bệnh khả dĩ nhất hoặc 'Không đủ bằng chứng'>",
        "urgency": "theo dõi|sớm|khẩn cấp",
        "luu_y": "<1 câu nêu giới hạn của chẩn đoán này>",
        "recommended_next_steps": ["<bước xử lý 1>", "<bước xử lý 2>"],
        "observations_by_image": [
            {
            "image_index": 1,
            "body_region": "<vị trí quan sát>",
            "visible_findings": ["<điều THẬT SỰ thấy trong ảnh>"]
            }
        ],
        "differential_diagnoses": [
            {"label": "<tên bệnh từ danh sách trên>", "confidence": <số 10.0-99.0>},
            {"label": "<bệnh khả dĩ thứ hai>", "confidence": <số 10.0-99.0>}
        ]
        }`;

        // 4. Gửi Request sang AI Server (llama.cpp)
        // temperature = 0 để cùng một ảnh + lời khai luôn cho ra cùng kết quả.
        // Đo thực nghiệm: ở 0.1 kết quả dao động (7/8 lần đúng), ở 0 thì ổn định 8/8.
        const askModel = (maxTokens) => axios.post(`${VLM_SERVER_URL}/v1/chat/completions`, {
            model: 'local-qwen3-vl',
            messages: [{ role: 'user', content: [{ type: 'text', text: prompt }, ...imageContents] }],
            temperature: 0,
            max_tokens: maxTokens,
            response_format: { type: 'json_object' }
        }, { timeout: 300000 });

        const parseAi = (response) => {
            const choice = response.data.choices[0];
            const cleaned = choice.message.content
                .replace(/```json\n?/ig, '').replace(/```\n?/ig, '').trim();
            try {
                return { ok: true, json: JSON.parse(cleaned) };
            } catch (parseError) {
                return { ok: false, truncated: choice.finish_reason === 'length', error: parseError };
            }
        };

        // Model 2B thỉnh thoảng viết lan man vượt giới hạn token, trả JSON cụt
        // ("Unterminated string") làm hỏng cả lần quét. Thử lại 1 lần với hạn mức cao hơn.
        let attempt = parseAi(await askModel(3072));
        if (!attempt.ok && attempt.truncated) {
            attempt = parseAi(await askModel(4096));
        }
        if (!attempt.ok) {
            return res.status(502).json({
                success: false,
                message: attempt.truncated
                    ? 'AI trả lời dài quá giới hạn nên dữ liệu bị cắt. Hãy thử lại hoặc gửi ít ảnh hơn.'
                    : 'AI trả về dữ liệu không đúng định dạng JSON. Hãy thử phân tích lại.',
                error: attempt.error.message
            });
        }
        const aiJson = attempt.json;

        // 4b. RAG: tra phác đồ điều trị/phòng ngừa THẬT từ collection BenhGiaCam
        // theo bệnh vừa chẩn đoán, thay vì để model tự nghĩ ra lời khuyên chung chung.
        // Nội dung và link nguồn lấy nguyên văn từ DB nên không có nguy cơ bịa nguồn.
        const topLabel = (aiJson.differential_diagnoses || [])[0]?.label
            || aiJson.most_likely_label;
        let knowledge = null;
        try {
            knowledge = await getDiseaseKnowledge(topLabel);
        } catch (ragError) {
            console.error('Không tra được BenhGiaCam:', ragError.message);
        }

        const aiNextSteps = Array.isArray(aiJson.recommended_next_steps)
            ? aiJson.recommended_next_steps.join('. ')
            : (aiJson.recommended_next_steps || '');

        // 4c. Augmented Generation: đưa tài liệu vừa truy xuất vào prompt để model
        // ĐỌC rồi tự viết lời khuyên cho đúng ca bệnh này, thay vì trả nguyên văn.
        // Trích dẫn bằng số rồi ánh xạ về URL thật nên model không bịa được nguồn.
        const aiFindings = (aiJson.observations_by_image || [])
            .flatMap((obs) => obs.visible_findings || [])
            .join('; ');

        let advice = null;
        if (knowledge) {
            try {
                advice = await generateAdvice({
                    vlmUrl: VLM_SERVER_URL,
                    label: topLabel,
                    observation: rawObservation,
                    aiFindings,
                    knowledge,
                });
            } catch (adviceError) {
                console.error('Không sinh được lời khuyên:', adviceError.message);
            }
        }

        // Đường lùi khi model không sinh được: dùng thẳng tài liệu gốc còn hơn không có gì.
        if (!advice && knowledge) {
            advice = {
                dieuTri: knowledge.dieu_tri.map((t) => ({ noiDung: t, nguon: [] })),
                phongNgua: knowledge.phong_ngua.map((t) => ({ noiDung: t, nguon: [] })),
                referenceUrls: knowledge.url_tham_khao,
            };
        }

        const suggestedTreatment = advice
            ? [
                `🎯 XỬ LÝ/ĐIỀU TRỊ: ${advice.dieuTri.map((x) => x.noiDung).join(' ')}`,
                `🛡️ PHÒNG NGỪA: ${advice.phongNgua.map((x) => x.noiDung).join(' ')}`,
            ].join('\n\n')
            : (aiNextSteps || 'Chưa có phác đồ tham chiếu, hãy liên hệ thú y.');

        // 5. Lưu kết quả vào MongoDB
        const newScan = new PoultryScan({
            basicInfo: {
                poultryType: req.body.poultryType || "Gà",
                currentStatus: aiJson.urgency === 'khẩn cấp' ? 'Nguy hiểm' : (aiJson.urgency === 'sớm' ? 'Cảnh báo' : 'Bình thường')
            },
            media: {
                imageUrls: savedImageUrls 
            },
            clinicalFindings: {
                // Lưu lại lời khai để sau này đối chiếu với kết luận của thú y.
                generalDescription: rawObservation
                    ? `Người nuôi mô tả: ${rawObservation}`
                    : 'AI phân tích tự động từ hình ảnh (người nuôi không mô tả thêm).',
                // Model 2B đôi khi bỏ sót field, nên phải phòng thủ tránh crash cả request.
                symptoms: (aiJson.observations_by_image || []).flatMap(obs =>
                    (obs.visible_findings || []).map(finding => ({
                        bodyPart: obs.body_region || 'Không xác định',
                        condition: finding
                    }))
                )
            },
            aiDiagnosis: {
                predictions: (aiJson.differential_diagnoses || []).map(d => ({
                    diseaseName: d.label || 'Chưa rõ',
                    confidenceScore: Number(d.confidence) || 0
                })),
                suggestedTreatment,
                requiresExpertReview: aiJson.urgency === 'khẩn cấp',
                dieuTri: advice ? advice.dieuTri : [],
                phongNgua: advice ? advice.phongNgua : [],
                referenceUrls: advice ? advice.referenceUrls : []
            },
            humanVerification: { isVerified: false },
            syncStatus: "SYNCED"
        });

        const savedScan = await newScan.save();

        return res.status(200).json({ success: true, data: savedScan });

    } catch (error) {
        console.error('Lỗi khi gọi AI:', error.message);

        // Lỗi hay gặp nhất khi demo: quên bật llama-server của notebook SmartFarmVLM.
        if (error.code === 'ECONNREFUSED' || error.code === 'ECONNRESET') {
            return res.status(503).json({
                success: false,
                message: `Chưa kết nối được model AI tại ${VLM_SERVER_URL}. Hãy bật llama-server (Qwen3-VL) trước khi phân tích ảnh.`,
                error: error.message
            });
        }

        return res.status(500).json({ success: false, message: 'Lỗi phân tích AI', error: error.message });
    }
};