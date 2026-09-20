require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { MongoClient } = require('mongodb');

// Dựng lại toàn bộ kho tri thức trên MongoDB Atlas từ đầu.
//
// Vì sao cần script này: mã nguồn trên Git chỉ có phần chữ của kho tri thức
// (data/seed/*.json). Vector nhúng và hai chỉ mục vector của Atlas không nằm
// trong kho mã, nên người mới tải dự án về sẽ có cơ sở dữ liệu rỗng và mọi truy
// xuất RAG trả về rỗng mà không báo lỗi gì.
//
// Script làm ba việc, theo đúng thứ tự:
//   1. Nạp 5 collection tri thức từ data/seed/ (ghi đè theo khoá, chạy lại được
//      nhiều lần mà không sinh bản ghi trùng).
//   2. Sinh vector cho BenhGiaCam và TrieuChung bằng máy chủ embedding.
//   3. Tạo hai chỉ mục vector trên Atlas và chờ tới khi chúng sẵn sàng.
//
// Nó KHÔNG đụng tới dữ liệu người dùng (ChuongTrai, KetQuaScan, poultryscans...).
//
// Dùng:
//   node scripts/setup_database.js              nạp dữ liệu + sinh vector + tạo chỉ mục
//   node scripts/setup_database.js --dry-run    chỉ in ra dự định làm gì
//   node scripts/setup_database.js --skip-index bỏ qua bước tạo chỉ mục
//   node scripts/setup_database.js --force      sinh lại vector kể cả khi đã có

const THU_MUC_SEED = path.join(__dirname, '..', 'data', 'seed');
const EMBED_URL = process.env.EMBED_SERVER_URL || 'http://127.0.0.1:8082';
const MO_HINH_NHUNG = 'AITeamVN/Vietnamese_Embedding';
const SO_CHIEU = 1024;

const co = {
    dryRun: process.argv.includes('--dry-run'),
    skipIndex: process.argv.includes('--skip-index'),
    force: process.argv.includes('--force'),
};

// Mỗi collection: khoá nhận dạng bản ghi, và cách lấy đoạn văn bản đem đi nhúng.
// layVanBan = null nghĩa là collection này không cần vector.
const CAU_HINH = [
    { ten: 'DanhMucGiong', khoa: ['id_giong'], layVanBan: null },
    { ten: 'SinhTruong', khoa: ['id_giong', 'tuoi_ngay_tu'], layVanBan: null },
    { ten: 'LichTiemPhong', khoa: ['id_vacxin'], layVanBan: null },
    {
        ten: 'BenhGiaCam', khoa: ['chunk_id'],
        // Vector của BenhGiaCam được sinh từ nguyên văn đoạn tri thức.
        layVanBan: (d) => d.noi_dung_goc,
    },
    {
        ten: 'TrieuChung', khoa: ['id_trieu_chung'],
        // Triệu chứng ghép thêm vị trí quan sát vào trước mô tả, vì "xuất huyết"
        // ở chân và ở mào là hai dấu hiệu khác nhau. Trường embedding_input trong
        // file seed đã lưu sẵn chuỗi này để tái tạo đúng vector cũ.
        layVanBan: (d) => d.embedding_input || `${d.vi_tri_quan_sat}: ${d.mo_ta}`,
    },
];

const CHI_MUC = [
    {
        collection: 'BenhGiaCam',
        name: 'vector_index',
        definition: {
            fields: [
                { type: 'vector', path: 'embedding', numDimensions: SO_CHIEU, similarity: 'dotProduct' },
                { type: 'filter', path: 'benh_ma' },
                { type: 'filter', path: 'benh_tag' },
                { type: 'filter', path: 'phan_loai' },
            ],
        },
    },
    {
        collection: 'TrieuChung',
        name: 'trieuchung_vector_index',
        definition: {
            fields: [
                { type: 'vector', path: 'embedding', numDimensions: SO_CHIEU, similarity: 'dotProduct' },
                { type: 'filter', path: 'benh_ma' },
                { type: 'filter', path: 'vi_tri_quan_sat' },
            ],
        },
    },
];

/// Ghép các trường khoá thành một chuỗi để đối chiếu hai bên.
function khoaCua(doc, truong) {
    return truong.map((k) => String(doc[k])).join(' | ');
}

/// Gọi máy chủ embedding. Chia lô nhỏ cho đỡ chiếm bộ nhớ trên máy 16 GB.
async function sinhVector(danhSachVanBan, kichThuocLo = 16) {
    const ketQua = [];
    for (let i = 0; i < danhSachVanBan.length; i += kichThuocLo) {
        const lo = danhSachVanBan.slice(i, i + kichThuocLo);
        const res = await axios.post(`${EMBED_URL}/embed`, { texts: lo }, { timeout: 120000 });
        const vectors = res.data?.vectors;
        if (!Array.isArray(vectors) || vectors.length !== lo.length) {
            throw new Error(`Máy chủ embedding trả về ${vectors?.length} vector cho ${lo.length} đoạn`);
        }
        if (vectors[0].length !== SO_CHIEU) {
            throw new Error(
                `Vector ${vectors[0].length} chiều nhưng chỉ mục khai báo ${SO_CHIEU} chiều. `
                + 'Máy chủ embedding đang chạy sai mô hình?'
            );
        }
        ketQua.push(...vectors);
        console.log(`   ... ${ketQua.length}/${danhSachVanBan.length}`);
    }
    return ketQua;
}

/// Kiểm tra máy chủ embedding trước khi làm gì, để không nạp nửa chừng rồi hỏng.
async function kiemTraMayChuEmbedding() {
    try {
        const res = await axios.get(`${EMBED_URL}/health`, { timeout: 5000 });
        console.log(`✅ Máy chủ embedding: ${res.data.model} (${res.data.dim} chiều) tại ${EMBED_URL}`);
        if (res.data.model !== MO_HINH_NHUNG) {
            console.log(`⚠️  Mô hình khác với ${MO_HINH_NHUNG}. Vector sẽ nằm ở không gian khác,`);
            console.log('   điểm tương đồng trở nên vô nghĩa dù vẫn đủ số chiều.');
        }
        return res.data;
    } catch (err) {
        console.error(`❌ Không gọi được máy chủ embedding tại ${EMBED_URL}: ${err.message}`);
        console.error('   Bật nó trước:');
        console.error('     cd backend && source .venv/bin/activate && python scripts/embedding_server.py');
        process.exit(1);
    }
}

async function napCollection(db, cauHinh) {
    const duongDan = path.join(THU_MUC_SEED, `${cauHinh.ten}.json`);
    if (!fs.existsSync(duongDan)) {
        console.log(`⚠️  Bỏ qua ${cauHinh.ten}: không thấy ${duongDan}`);
        return;
    }
    const banGhi = JSON.parse(fs.readFileSync(duongDan, 'utf8'));
    const col = db.collection(cauHinh.ten);
    const daCo = await col.countDocuments();

    console.log(`\n▶️  ${cauHinh.ten}: ${banGhi.length} bản ghi trong seed, ${daCo} bản ghi đang có trong CSDL`);

    // Sinh vector TRƯỚC khi ghi, để nếu máy chủ embedding hỏng thì cơ sở dữ liệu
    // không bị bỏ lại ở trạng thái có tài liệu mà thiếu vector.
    let vectors = null;
    if (cauHinh.layVanBan) {
        const duVector = !co.force
            && daCo === banGhi.length
            && (await col.countDocuments({ embedding: { $exists: false } })) === 0;

        if (duVector) {
            console.log('   Đã đủ vector, bỏ qua bước nhúng (dùng --force để sinh lại).');
        } else {
            const vanBan = banGhi.map(cauHinh.layVanBan).map((t) => String(t || '').trim());
            const rong = vanBan.findIndex((t) => t.length === 0);
            if (rong >= 0) throw new Error(`${cauHinh.ten}: bản ghi thứ ${rong + 1} không có văn bản để nhúng`);
            console.log(`   Đang sinh ${vanBan.length} vector ...`);
            if (!co.dryRun) vectors = await sinhVector(vanBan);
        }
    }

    if (co.dryRun) {
        console.log(`   [thử] sẽ ghi đè ${banGhi.length} bản ghi theo khoá ${cauHinh.khoa.join(' + ')}`);
        return;
    }

    // replaceOne + upsert: chạy lại lần hai cho ra đúng kết quả lần đầu.
    // Nhưng replaceOne XOÁ những trường không có trong seed, mà seed cố tình
    // không chứa vector (nặng và tái tạo được). Nên khi bỏ qua bước nhúng, phải
    // đọc vector đang có trong CSDL rồi ghi lại cùng tài liệu.
    let vectorCu = null;
    if (!vectors && cauHinh.layVanBan) {
        const chieu = Object.fromEntries(cauHinh.khoa.map((k) => [k, 1]));
        const rows = await col.find({}, { projection: { embedding: 1, ...chieu } }).toArray();
        vectorCu = new Map(rows.map((r) => [khoaCua(r, cauHinh.khoa), r.embedding]));
    }

    const thaoTac = banGhi.map((d, i) => {
        const tailieu = { ...d };
        const v = vectors ? vectors[i] : vectorCu && vectorCu.get(khoaCua(d, cauHinh.khoa));
        if (v) {
            tailieu.embedding = v;
            tailieu.embedding_dim = SO_CHIEU;
            tailieu.embedding_model = MO_HINH_NHUNG;
        }
        return {
            replaceOne: {
                filter: Object.fromEntries(cauHinh.khoa.map((k) => [k, d[k]])),
                replacement: tailieu,
                upsert: true,
            },
        };
    });

    const kq = await col.bulkWrite(thaoTac, { ordered: false });
    const giuNguyen = banGhi.length - kq.upsertedCount - kq.modifiedCount;
    console.log(`   ✅ thêm mới ${kq.upsertedCount}, cập nhật ${kq.modifiedCount}, giữ nguyên ${giuNguyen}`);
}

async function taoChiMuc(db) {
    for (const ct of CHI_MUC) {
        const col = db.collection(ct.collection);
        let daCo = [];
        try {
            daCo = await col.listSearchIndexes(ct.name).toArray();
        } catch (err) {
            console.error(`❌ Không đọc được chỉ mục của ${ct.collection}: ${err.message}`);
            console.error('   Chỉ mục vector chỉ có trên MongoDB Atlas, không có trên MongoDB cài tại máy.');
            return false;
        }

        if (daCo.length > 0) {
            console.log(`   Đã có "${ct.name}" trên ${ct.collection} (trạng thái ${daCo[0].status}), cập nhật định nghĩa.`);
            if (!co.dryRun) await col.updateSearchIndex(ct.name, ct.definition);
        } else {
            console.log(`   Tạo mới "${ct.name}" trên ${ct.collection}.`);
            if (!co.dryRun) {
                await col.createSearchIndex({ name: ct.name, type: 'vectorSearch', definition: ct.definition });
            }
        }
    }

    if (co.dryRun) return true;

    // Atlas dựng chỉ mục bất đồng bộ; truy vấn trước khi READY sẽ trả về rỗng
    // mà không báo lỗi, nên phải chờ cho chắc.
    console.log('\n⏳ Chờ chỉ mục sẵn sàng (Atlas dựng nền, thường 1-2 phút) ...');
    const hanChot = Date.now() + 5 * 60 * 1000;
    while (Date.now() < hanChot) {
        const trangThai = [];
        for (const ct of CHI_MUC) {
            const [idx] = await db.collection(ct.collection).listSearchIndexes(ct.name).toArray();
            trangThai.push(`${ct.name}=${idx ? idx.status : 'KHÔNG THẤY'}`);
        }
        if (trangThai.every((s) => s.endsWith('=READY'))) {
            console.log(`   ✅ ${trangThai.join('   ')}`);
            return true;
        }
        console.log(`   ${trangThai.join('   ')}`);
        await new Promise((r) => setTimeout(r, 5000));
    }
    console.log('   ⚠️  Quá 5 phút chỉ mục vẫn chưa READY. Kiểm tra trên Atlas > Atlas Search.');
    return false;
}

/// Thử một truy vấn thật để chắc chắn cả ba bước đã ăn khớp với nhau.
async function kiemChung(db) {
    const cau = 'Gà ủ rũ, xù lông, phân có máu';
    const res = await axios.post(`${EMBED_URL}/embed`, { texts: [cau] }, { timeout: 30000 });
    const rows = await db.collection('TrieuChung').aggregate([
        {
            $vectorSearch: {
                index: 'trieuchung_vector_index',
                path: 'embedding',
                queryVector: res.data.vectors[0],
                numCandidates: 50,
                limit: 3,
            },
        },
        { $project: { mo_ta: 1, benh_ma: 1, score: { $meta: 'vectorSearchScore' } } },
    ]).toArray();

    console.log(`\n🔎 Thử truy vấn: "${cau}"`);
    if (rows.length === 0) {
        console.log('   ❌ Không có kết quả. Chỉ mục có thể chưa dựng xong, chờ thêm rồi chạy lại.');
        return false;
    }
    rows.forEach((r) => {
        console.log(`   ${r.score.toFixed(3)}  [${(r.benh_ma || []).join(', ')}]  ${r.mo_ta}`);
    });
    return true;
}

(async () => {
    if (!process.env.MONGODB_URI) {
        console.error('❌ Thiếu MONGODB_URI. Chép backend/.env.example thành backend/.env rồi điền chuỗi kết nối.');
        process.exit(1);
    }
    if (co.dryRun) console.log('=== CHẾ ĐỘ THỬ: không ghi gì vào cơ sở dữ liệu ===\n');

    await kiemTraMayChuEmbedding();

    const client = new MongoClient(process.env.MONGODB_URI);
    await client.connect();
    const db = client.db();
    console.log(`✅ Kết nối cơ sở dữ liệu "${db.databaseName}"`);

    try {
        for (const cauHinh of CAU_HINH) await napCollection(db, cauHinh);

        if (co.skipIndex) {
            console.log('\n⏭️  Bỏ qua bước tạo chỉ mục (--skip-index).');
        } else {
            console.log('\n▶️  Chỉ mục vector trên Atlas');
            const san = await taoChiMuc(db);
            if (san && !co.dryRun) await kiemChung(db);
        }
        console.log('\n✅ Xong. Giờ có thể chạy: node server.js');
    } finally {
        await client.close();
    }
})().catch((err) => {
    console.error('\n❌ Lỗi:', err.message);
    process.exit(1);
});
