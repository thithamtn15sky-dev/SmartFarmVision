# SmartFarm Vision

Ứng dụng chẩn đoán bệnh gia cầm qua ảnh, dành cho hộ chăn nuôi quy mô nhỏ. Người
dùng chụp ảnh con gà nghi bệnh bằng điện thoại, hệ thống mô tả dấu hiệu nhìn thấy
được, đối chiếu với kho tri thức thú y rồi trả về chẩn đoán kèm phác đồ điều trị
có trích dẫn nguồn.

Ngoài chẩn đoán, ứng dụng còn quản lý chuồng trại: theo dõi đàn, nhắc lịch tiêm
vaccine, ước tính ngày xuất chuồng và xem thời tiết.

## Kiến trúc

Hệ thống chạy bằng **ba tiến trình** trên cùng một máy:

| Tiến trình | Cổng | Vai trò |
|---|---|---|
| `node server.js` | 3000 | API cho ứng dụng Flutter, điều phối toàn bộ luồng chẩn đoán |
| `llama-server` (Qwen3-VL-2B) | 8081 | Nhìn ảnh, mô tả triệu chứng, sinh câu trả lời cuối |
| `embedding_server.py` | 8082 | Sinh vector truy xuất và xếp hạng lại tài liệu |

Dữ liệu nằm trên MongoDB Atlas: kho tri thức bệnh (`BenhGiaCam`, `TrieuChung`)
cùng hai chỉ mục vector, và dữ liệu vận hành của người dùng (`ChuongTrai`,
`KetQuaScan`).

### Luồng chẩn đoán

```
Ảnh  ──►  Qwen3-VL mô tả dấu hiệu nhìn thấy
             │
             ├──►  ghép với mô tả của người nuôi  ──►  câu truy vấn
             │
   Chặng 1   └──►  Vector Search trên TrieuChung (Top-K 3)
                      └──►  hợp các benh_ma  ──►  thu hẹp còn vài bệnh
   Chặng 2         BM25 lấy 20 ứng viên trong BenhGiaCam
                      └──►  CrossEncoder xếp hạng lại  ──►  Top-K 5
                              └──►  ngữ cảnh  ──►  Qwen3-VL sinh phác đồ
```

Chiến lược truy xuất ở chặng 2 (BM25 + reranker) là cấu hình đạt điểm cao nhất
trong 12 pipeline đã đo, chi tiết ở mục 5.4 của báo cáo. Đổi cấu hình bằng các
biến trong `.env` mà không phải sửa mã.

## Yêu cầu

- macOS trên chip Apple Silicon (M1 trở lên), RAM tối thiểu 16 GB
- Node.js 20 trở lên
- Python 3.11 trở lên
- Flutter 3.x (chỉ cần nếu muốn chạy ứng dụng di động)
- Một cụm MongoDB Atlas — chỉ mục vector **không có** trên MongoDB cài tại máy
- Khoảng **5,6 GB** dung lượng trống cho các mô hình

> Trọng số mô hình không nằm trong kho mã nguồn: hai file GGUF nặng 1,48 GB,
> vượt giới hạn 100 MB cho mỗi file của GitHub. Bước 1 dưới đây tải chúng về.

## Cài đặt

### Bước 1 — Tải mô hình thị giác

```bash
cd backend && ./scripts/download_models.sh
```

Tải Qwen3-VL-2B-Instruct (1,03 GB), phần thị giác mmproj (424 MB) và bản
llama.cpp `b10092` biên dịch sẵn, mặc định vào `~/Downloads/SmartFarmVLM`. Đổi
chỗ bằng `VLM_HOME=/đường/dẫn/khác ./scripts/download_models.sh`. Script chạy
lại được: file nào đã đủ dung lượng thì bỏ qua.

### Bước 2 — Dựng môi trường Python cho máy chủ embedding

```bash
cd backend && python3 -m venv .venv && source .venv/bin/activate && pip install -r scripts/requirements.txt
```

Lần chạy đầu tiên của máy chủ sẽ tự tải thêm khoảng 4,2 GB từ Hugging Face về
`~/.cache/huggingface`: `AITeamVN/Vietnamese_Embedding` để sinh vector và
`BAAI/bge-reranker-v2-m3` để xếp hạng lại.

### Bước 3 — Cấu hình backend

```bash
cd backend && npm install && cp .env.example .env
```

Mở `.env` và điền `MONGODB_URI`. Các biến còn lại đã có giá trị mặc định dùng
được ngay; chú thích trong `.env.example` giải thích từng biến.

### Bước 4 — Nạp kho tri thức và tạo chỉ mục vector

Bật máy chủ embedding trước, vì bước này cần nó để sinh vector:

```bash
cd backend && source .venv/bin/activate && python scripts/embedding_server.py
```

Mở một cửa sổ terminal khác rồi chạy:

```bash
cd backend && node scripts/setup_database.js
```

Script nạp 82 tài liệu tri thức từ `data/seed/`, sinh 46 vector, tạo hai chỉ mục
vector trên Atlas rồi chờ chúng sẵn sàng và thử một truy vấn để kiểm chứng. Nó
chạy lại được nhiều lần và **không** đụng tới dữ liệu người dùng. Xem trước bằng
`node scripts/setup_database.js --dry-run`.

## Chạy hằng ngày

Ba cửa sổ terminal, hoặc hai nếu để mô hình chạy nền:

```bash
cd backend && ./start_vlm.sh
```

```bash
cd backend && source .venv/bin/activate && python scripts/embedding_server.py
```

```bash
cd backend && node server.js
```

Kiểm tra cả ba đã sống:

```bash
curl -s localhost:8081/health && curl -s localhost:8082/health && curl -s localhost:3000/
```

### Ứng dụng Flutter

```bash
cd frontend && ./run.sh
```

Script tự dò IP LAN của máy và truyền vào ứng dụng, nên **không phải sửa mã
nguồn mỗi lần đổi mạng WiFi**. Điện thoại và máy chạy backend phải cùng một mạng.

Muốn chỉ định tay thì truyền thẳng:

```bash
cd frontend && flutter run --dart-define=API_BASE_URL=http://192.168.1.74:3000
```

Chọn địa chỉ theo nơi chạy ứng dụng:

| Chạy trên | Địa chỉ backend |
|---|---|
| Máy thật, BlueStacks | IP LAN của máy tính, ví dụ `http://192.168.1.74:3000` |
| Emulator Android (AVD) | `http://10.0.2.2:3000` |
| Chrome, macOS desktop | `http://localhost:3000` (mặc định khi không truyền gì) |

## Cấu trúc thư mục

```
backend/
  server.js                    điểm vào, đăng ký route
  controllers/                 xử lý yêu cầu, gồm luồng chẩn đoán ba lượt
  services/
    vectorRetrieval.js         truy xuất hai chặng, gọi embedding và reranker
    lexicalIndex.js            BM25 dựng trong bộ nhớ trên BenhGiaCam
    diseaseKnowledge.js        tra cứu tất định theo mã bệnh
  constants/diseaseCodes.js    nguồn chân lý duy nhất cho mã bệnh
  scripts/
    download_models.sh         tải trọng số Qwen3-VL và llama.cpp
    embedding_server.py        máy chủ /embed và /rerank
    setup_database.js          nạp tri thức, sinh vector, tạo chỉ mục
    normalize-disease-codes.js chuẩn hoá benh_tag cũ về benh_ma
  data/seed/                   82 tài liệu tri thức dạng chữ
frontend/
  run.sh                       chạy app, tự dò IP backend
  lib/api_config.dart          địa chỉ backend, nhận từ --dart-define
docs/mermaid/                  15 sơ đồ nghiệp vụ dạng Mermaid
```

## Xử lý sự cố

**Chẩn đoán trả về lỗi "Chưa kết nối được model AI"** — `llama-server` chưa chạy.
Bật `./start_vlm.sh` và xem log ở `/tmp/vlm_smartfarm.log`.

**Chẩn đoán chỉ dựa trên chữ, bỏ qua ảnh** — thiếu `--mmproj`. Log khởi động phải
có dòng `loaded multimodal model`; nếu không, tải lại file mmproj.

**Truy xuất luôn trả về rỗng** — hoặc chỉ mục vector chưa READY, xem trên Atlas ở
mục Atlas Search; hoặc máy chủ embedding đang chạy sai mô hình. Toàn bộ vector
trong cơ sở dữ liệu sinh bằng `AITeamVN/Vietnamese_Embedding`; dùng mô hình khác
thì vector nằm ở không gian khác và điểm tương đồng trở nên vô nghĩa dù vẫn đủ
1024 chiều. Đặt `USE_VECTOR_RAG=false` để tạm chạy đường tra cứu tất định.

**Ứng dụng báo lỗi mạng, backend vẫn chạy bình thường** — địa chỉ backend sai.
Chạy `./run.sh` để nó tự dò IP, hoặc đối chiếu bảng ở mục Ứng dụng Flutter. Điện
thoại và máy tính phải cùng mạng WiFi, và mạng đó không được bật chế độ cô lập
thiết bị (AP isolation).

**Cổng 8081 đã bị chiếm** — `VLM_PORT=8090 ./start_vlm.sh`, rồi sửa
`VLM_SERVER_URL` trong `.env` cho khớp.

**Máy đơ khi vừa chẩn đoán vừa xếp hạng** — trên máy 16 GB, reranker chỉ được nạp
khi có yêu cầu `/rerank` đầu tiên và chiếm thêm khoảng 2,3 GB. Nếu chật bộ nhớ,
đặt `USE_VECTOR_RAG=false` hoặc chạy máy chủ embedding trên máy khác rồi trỏ
`EMBED_SERVER_URL` sang đó.
