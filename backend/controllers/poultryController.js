const PoultryScan = require('../models/PoultryScan');
const axios = require('axios');
const fs = require('fs');
const { getDiseaseKnowledge, getSymptomCatalog, canonicalLabel, labelFromSymptomText } = require('../services/diseaseKnowledge');
const { generateAdvice } = require('../services/treatmentAdvisor');
const { describeImages } = require('../services/imageObserver');

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

        // 3a. LƯỢT QUAN SÁT (tách rời lượt chẩn đoán, xem services/imageObserver.js).
        // Model tả ảnh khi CHƯA biết danh sách bệnh và CHƯA nghe lời khai, nên không
        // có gì để chép - buộc phải mô tả đúng thứ nhìn thấy.
        let observation = null;
        try {
            observation = await describeImages({ vlmUrl: VLM_SERVER_URL, imageContents });
        } catch (observeError) {
            console.error('Không mô tả được ảnh:', observeError.message);
        }
        // 3a-bis. CỔNG CHẶN ẢNH KHÔNG CHẨN ĐOÁN ĐƯỢC.
        // Gà đã luộc/làm thịt thì da, lông, mào đã bị nấu chín hoặc vặt sạch - mọi
        // dấu hiệu bệnh đều mất. Trước đây hệ thống vẫn chẩn đoán bừa (ảnh gà luộc
        // trên đĩa vẫn ra "Cúm gia cầm 60%"), vừa sai vừa gây hiểu nhầm nguy hiểm.
        // Dừng ngay tại đây, không chạy tiếp lượt chẩn đoán.
        if (observation && !observation.chanDoanDuoc) {
            const lyDoTheoLoai = {
                ga_che_bien: 'Ảnh là gà đã làm thịt hoặc đã nấu chín. Khi đó lông, da và mào '
                    + 'đã bị vặt hoặc biến đổi nên không còn dấu hiệu bệnh để chẩn đoán.',
                khong_phai_ga: 'Ảnh không có gà.',
                khong_ro: 'Ảnh không đủ rõ để xác định đây có phải gà hay không.',
            };
            return res.status(422).json({
                success: false,
                code: 'ANH_KHONG_CHAN_DOAN_DUOC',
                doi_tuong: observation.doiTuong,
                message: (lyDoTheoLoai[observation.doiTuong] || 'Ảnh không phù hợp để chẩn đoán bệnh.')
                    + ' Hãy chụp lại gà còn sống hoặc gà nguyên con tại chuồng, thấy rõ đầu, mào, chân và phân.',
                quan_sat: observation.items.map((i) => ({ vung: i.vung, mo_ta: i.moTa })),
            });
        }

        // Mất lượt quan sát thì vẫn chẩn đoán được, nhưng phải nói thẳng cho model
        // biết là không có mô tả, tránh để nó tự bịa ra dấu hiệu.
        const observationText = observation
            ? observation.text
            : '(Không thực hiện được lượt quan sát ảnh. Hãy mô tả trực tiếp từ ảnh và HẠ độ tin cậy.)';

        // 3b. Danh mục triệu chứng đọc từ collection TrieuChung thay vì viết cứng,
        // để app và notebook luôn dùng chung một bản kiến thức. Chuyên gia cập nhật
        // DB là app đổi theo ngay, không phải sửa code.
        let symptomCatalog = null;
        try {
            symptomCatalog = await getSymptomCatalog();
        } catch (catalogError) {
            console.error('Không đọc được TrieuChung:', catalogError.message);
        }
        // Đường lùi khi DB chưa sẵn sàng: vẫn phải chẩn đoán được.
        const knowledgeBlock = symptomCatalog ? symptomCatalog.text : `- Cúm gia cầm (H5N1): Mào tích tím tái, sưng phù đầu, xuất huyết dưới da chân, chết đột ngột.
        - Sổ mũi truyền nhiễm (Coryza): Sưng phù một hoặc hai bên mặt, mắt nhắm nghiền, có dịch nhầy hôi, ho hen.
        - Đậu gà: Nổi mụn sần sùi màu nâu ở mào, yếm, quanh mắt.
        - Newcastle (Gà rù): Ngoẹo cổ, liệt chân, tiêu chảy phân xanh/trắng, thở khò khè.
        - Cầu trùng: Tiêu chảy phân lẫn máu tươi hoặc phân sáp nâu, lông xù, ủ rũ.`;

        // 3. Chuẩn bị Prompt
        // Lời khai của người nuôi (nhập ở màn Preview). Đây là bằng chứng đáng tin
        // hơn thị giác của model 2B, vốn không phân giải nổi chi tiết như màu phân.
        const rawObservation = (req.body.observation || '').trim();

        // Chip triệu chứng trong app lấy thẳng từ collection TrieuChung, nên backend
        // tra ngược ra bệnh được mà KHÔNG cần hỏi model. Đây là căn cứ tất định,
        // dùng để đối chứng với kết luận của model.
        // Gặp thật: ảnh chụp lại màn hình điện thoại bị ám tím, model mô tả "da đầu
        // bầm tím, chân chảy máu" rồi kết luận H5N1 98%, trong khi người nuôi đã khai
        // "sưng phù mặt một bên" - dấu hiệu đặc trưng của Coryza.
        let benhTuLoiKhai = null;
        if (rawObservation) {
            try {
                benhTuLoiKhai = await labelFromSymptomText(rawObservation);
            } catch (loiTra) {
                console.error('Không tra được bệnh từ lời khai:', loiTra.message);
            }
        }

        // Lời khai PHẢI đặt ở CUỐI prompt, ngay trước schema.
        // Đã đo thực nghiệm trên chính model này với cùng 1 ảnh gà rù:
        //   - lời khai đặt đầu prompt -> H5N1 85% (SAI, ảnh lấn át lời khai)
        //   - lời khai đặt cuối prompt -> Newcastle 95% (ĐÚNG)
        // Nguyên nhân là hiệu ứng recency: model coi trọng phần cuối prompt hơn.
        const observationBlock = rawObservation
            ? `*** QUAN TRỌNG NHẤT - NGƯỜI NUÔI TRỰC TIẾP QUAN SÁT ĐƯỢC: "${rawObservation}" ***${benhTuLoiKhai ? `
        ĐỐI CHIẾU CƠ SỞ DỮ LIỆU TRIỆU CHỨNG: các dấu hiệu người nuôi khai là dấu hiệu
        ĐẶC TRƯNG của bệnh "${benhTuLoiKhai}". Đây là kết quả tra cứu CSDL, không phải suy đoán.
        Bệnh này BẮT BUỘC phải xuất hiện trong "differential_diagnoses".
        Nếu bạn vẫn chọn bệnh khác làm kết luận chính, phải nêu rõ trong "luu_y"
        vì sao bằng chứng trên ảnh đủ mạnh để bác bỏ lời khai của người nuôi.` : ''}
        Lời khai này ĐÁNG TIN HƠN hình ảnh, vì ảnh chỉ ghi lại một khoảnh khắc và không thấy được
        hành vi, tiếng thở hay phân của gà. HÃY ƯU TIÊN LỜI KHAI khi chọn bệnh.`
            : `*** NGƯỜI NUÔI KHÔNG MÔ TẢ GÌ THÊM ***
        Chỉ có ảnh làm bằng chứng nên độ tin cậy tối đa là 60, và phải nhắc người nuôi bổ sung mô tả triệu chứng.`;

        const prompt = `Bạn là một chuyên gia y tế thú y gia cầm. Hãy chẩn đoán bằng cách KẾT HỢP lời khai của người nuôi với hình ảnh.

KIẾN THỨC BỆNH LÝ TỪ CSDL THÚ Y (chỉ dùng để ĐỐI CHIẾU, KHÔNG được chép lại):
${knowledgeBlock}

MÔ TẢ ẢNH (do chính bạn quan sát ở bước trước, CHƯA biết bệnh gì - đây là bằng chứng thị giác đáng tin nhất):
${observationText}

        QUY TẮC BẮT BUỘC:
        1. CHỐNG BỊA ĐẶT: "visible_findings" PHẢI lấy nguyên ý từ phần MÔ TẢ ẢNH ở trên,
           không được thêm dấu hiệu nào khác. NGHIÊM CẤM chép triệu chứng từ phần
           KIẾN THỨC BỆNH LÝ vào visible_findings để hợp thức hóa kết luận.
        2. Lời khai của người nuôi được ưu tiên hơn suy đoán từ ảnh. Nếu lời khai mâu thuẫn với ảnh, hãy nêu rõ trong "luu_y".
        3. Liệt kê ĐÚNG 2 bệnh khả dĩ nhất trong "differential_diagnoses", xếp theo độ tin cậy giảm dần.
        4. HẠ ĐỘ TIN CẬY khi bằng chứng yếu:
           - Chỉ có ảnh, không có lời khai: confidence tối đa 60.
           - Ảnh mờ/không thấy triệu chứng đặc trưng: confidence tối đa 50.
           - Chỉ được vượt 85 khi ảnh VÀ lời khai cùng chỉ về một bệnh.
        5. Nếu không đủ căn cứ, đặt "most_likely_label" = "Không đủ bằng chứng" và đề nghị mời thú y.
        5b. GÀ KHOẺ THÌ PHẢI NÓI LÀ KHOẺ. Nếu ảnh cho thấy gà bình thường - mào đỏ tươi,
           lông mượt không xù, đứng/đi lại bình thường, da sạch không mụn không vết loét -
           VÀ người nuôi không mô tả triệu chứng nào, thì đặt "co_dau_hieu_benh" = false,
           "most_likely_label" = "Không phát hiện dấu hiệu bệnh", và để
           "differential_diagnoses" là mảng rỗng []. TUYỆT ĐỐI KHÔNG gán bừa một bệnh
           cho con gà khoẻ mạnh.
           Ngược lại, nếu người nuôi CÓ mô tả triệu chứng thì luôn đặt
           "co_dau_hieu_benh" = true, vì ảnh không thấy được dáng đi, tiếng thở hay phân.
        6. Trả lời NGẮN GỌN để JSON không bị cắt giữa chừng.
        7. KHÔNG tự nghĩ ra phác đồ điều trị, tên thuốc hay liều lượng. Phác đồ chính thức
           được hệ thống lấy riêng từ cơ sở dữ liệu thú y kèm link nguồn.
           "recommended_next_steps" chỉ ghi các việc cần làm NGAY tại chuồng
           (ví dụ: cách ly con bệnh, thu gom xác, khử trùng, gọi thú y).

        ${observationBlock}

        NHÃN BỆNH ĐƯỢC PHÉP - trường "label" CHỈ được dùng đúng một trong 5 chuỗi sau,
        chép nguyên văn, KHÔNG được ghi tên triệu chứng thay cho tên bệnh:
          "Cúm gia cầm (H5N1)"
          "Newcastle (Gà rù)"
          "Đậu gà"
          "Cầu trùng"
          "Sổ mũi truyền nhiễm (Coryza)"

        Xuất kết quả BẮT BUỘC theo đúng cấu trúc JSON sau (tự điền nội dung thật, không copy ví dụ):
        {
        "is_chicken": true,
        "co_dau_hieu_benh": <true nếu thấy dấu hiệu bệnh, false nếu gà trông khoẻ mạnh>,
        "most_likely_label": "<tên bệnh khả dĩ nhất, hoặc 'Không phát hiện dấu hiệu bệnh', hoặc 'Không đủ bằng chứng'>",
        "urgency": "theo dõi|sớm|khẩn cấp",
        "luu_y": "<1 câu NGẮN, tối đa 25 từ, nêu giới hạn của chẩn đoán>",
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
        ]   // để [] nếu co_dau_hieu_benh = false
        }`;

        // 4. Gửi Request sang AI Server (llama.cpp)
        // temperature = 0 để cùng một ảnh + lời khai luôn cho ra cùng kết quả.
        // Đo thực nghiệm: ở 0.1 kết quả dao động (7/8 lần đúng), ở 0 thì ổn định 8/8.
        const askModel = (maxTokens) => axios.post(`${VLM_SERVER_URL}/v1/chat/completions`, {
            model: 'local-qwen3-vl',
            messages: [{ role: 'user', content: [{ type: 'text', text: prompt }, ...imageContents] }],
            temperature: 0,
            max_tokens: maxTokens,
            response_format: { type: 'json_object' },
            // Model 2B thỉnh thoảng kẹt vòng lặp, viết đi viết lại một câu tới khi
            // hết token khiến JSON bị cắt. Gặp nhiều nhất ở ca H5N1 vì phần ngữ
            // cảnh dài nhất. repeat_penalty là chốt chặn cho lỗi đó.
            repeat_penalty: 1.15
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

        // CHUẨN HOÁ NHÃN BỆNH.
        // Model 2B thỉnh thoảng trả về MÔ TẢ TRIỆU CHỨNG thay cho tên bệnh - gặp thật
        // trên máy người dùng: nhãn là "Sưng phù mặt một bên" và app hiển thị thẳng
        // chuỗi đó lên màn hình kết quả như thể đó là tên bệnh. Nó cũng hay trả tên
        // rút gọn ("Coryza", "H5N1"). Ở đây đưa hết về đúng 5 nhãn chuẩn, nhãn nào
        // không quy được thì bỏ để không hiển thị bậy.
        const chuanHoaNhan = async (raw) => canonicalLabel(raw) || await labelFromSymptomText(raw);

        const dsChuanHoa = [];
        for (const d of (aiJson.differential_diagnoses || [])) {
            const nhan = await chuanHoaNhan(d.label);
            if (nhan) dsChuanHoa.push({ ...d, label: nhan });
            else console.warn('Bỏ nhãn không hợp lệ từ model:', JSON.stringify(d.label));
        }
        // Trùng nhãn sau khi chuẩn hoá thì giữ cái tin cậy cao hơn.
        const theoNhan = new Map();
        for (const d of dsChuanHoa) {
            const cu = theoNhan.get(d.label);
            if (!cu || Number(d.confidence) > Number(cu.confidence)) theoNhan.set(d.label, d);
        }
        aiJson.differential_diagnoses = [...theoNhan.values()];

        // Bảo đảm bệnh suy từ lời khai luôn có mặt để người nuôi thấy được khả năng đó,
        // kể cả khi model bỏ qua. Không ép lên hạng nhất - model vẫn có quyền kết luận
        // khác nếu ảnh đủ thuyết phục - nhưng không được giấu đi.
        if (benhTuLoiKhai && !aiJson.differential_diagnoses.some(d => d.label === benhTuLoiKhai)) {
            aiJson.differential_diagnoses.push({
                label: benhTuLoiKhai,
                confidence: 50,
                theo_loi_khai: true,
            });
            console.warn(`Model bỏ sót bệnh suy từ lời khai (${benhTuLoiKhai}), đã bổ sung.`);
        }

        const nhanChinh = await chuanHoaNhan(aiJson.most_likely_label);
        if (nhanChinh) aiJson.most_likely_label = nhanChinh;

        // 4a-bis. GÀ KHOẺ: không gán bừa bệnh.
        // Trước đây ảnh gà khoẻ (mào đỏ tươi, lông mượt, đang đi ăn) vẫn bị chẩn đoán
        // "Cúm gia cầm 70%" chỉ vì schema luôn bắt liệt kê 2 bệnh. Báo bệnh cho đàn
        // khoẻ mạnh khiến người nuôi dùng thuốc oan và mất niềm tin vào hệ thống.
        // Chỉ kết luận "khoẻ" khi gà CÒN SỐNG. Gà đã chết thì luôn phải điều tra
        // nguyên nhân - đo được: ảnh gà rù đã chết từng bị model kết luận là khoẻ,
        // đó là âm tính giả, nguy hiểm hơn nhiều so với báo nhầm có bệnh.
        const gaConSong = !observation || observation.doiTuong === 'ga_song';
        const khongCoDauHieu = aiJson.co_dau_hieu_benh === false
            || (aiJson.differential_diagnoses || []).length === 0;
        if (khongCoDauHieu && !rawObservation && gaConSong) {
            return res.status(200).json({
                success: true,
                code: 'KHONG_PHAT_HIEN_BENH',
                message: 'Không phát hiện dấu hiệu bệnh trên ảnh. Gà trông bình thường. '
                    + 'Nếu bạn thấy gà có biểu hiện lạ (bỏ ăn, ngoẹo cổ, phân bất thường, thở khò khè), '
                    + 'hãy chụp lại và mô tả triệu chứng ở ô "Bạn quan sát thấy gì?" để chẩn đoán chính xác hơn.',
                quan_sat: observation
                    ? observation.items.map((i) => ({ vung: i.vung, mo_ta: i.moTa }))
                    : [],
            });
        }

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
        // Phải tách đuôi "[Nguồn: url]" ra trường nguon, không thì người dùng
        // nhìn thấy đoạn đánh dấu nội bộ đó lẫn giữa câu chữ.
        if (!advice && knowledge) {
            const splitSource = (text) => {
                const match = String(text).match(/^([\s\S]*?)\s*\[Nguồn:\s*(.*?)\]\s*$/);
                return match
                    ? { noiDung: match[1].trim(), nguon: [match[2].trim()] }
                    : { noiDung: String(text).trim(), nguon: [] };
            };
            advice = {
                dieuTri: knowledge.dieu_tri.map(splitSource),
                phongNgua: knowledge.phong_ngua.map(splitSource),
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
                // Ưu tiên kết quả lượt QUAN SÁT ẢNH: lượt đó model chưa thấy danh
                // sách bệnh nên không chép được triệu chứng vào. Chỉ khi lượt đó
                // hỏng mới lấy tạm từ lượt chẩn đoán.
                symptoms: observation
                    ? observation.items.map(it => ({
                        bodyPart: it.vung,
                        condition: it.moTa
                    }))
                    : (aiJson.observations_by_image || []).flatMap(obs =>
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