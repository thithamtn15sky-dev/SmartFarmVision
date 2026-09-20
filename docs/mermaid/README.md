# Sơ đồ Mermaid — SmartFarm Vision

Toàn bộ sơ đồ của báo cáo, viết bằng Mermaid. Mỗi file `.mmd` là một hình,
nội dung bám sát mã nguồn đang chạy chứ không vẽ theo ý tưởng chung chung.

## Danh sách sơ đồ

| File | Loại sơ đồ | Nghiệp vụ mô tả | Gợi ý vị trí trong báo cáo |
|---|---|---|---|
| `01-usecase-tong-quan.mmd` | Use case | Toàn bộ chức năng người nuôi dùng được, chia 4 nhóm | Chương 3 — Khảo sát |
| `02-kien-truc-he-thong.mmd` | Kiến trúc triển khai | Flutter ↔ Node.js ↔ llama.cpp ↔ MongoDB Atlas ↔ Open-Meteo | Chương 4 — Thiết kế hệ thống |
| `03-erd-du-lieu.mmd` | ERD | 6 collection thật trong `SmartFarmData` + bản ghi tiêm nhúng | Chương 4 — Thiết kế CSDL |
| `04-luong-man-hinh.mmd` | Luồng màn hình | 10 màn hình và đường đi giữa chúng | Chương 4 — Thiết kế giao diện |
| `05-tuan-tu-chan-doan-benh.mmd` | Tuần tự | **Nghiệp vụ chính**: 3 lượt gọi mô hình, 2 cổng kiểm soát | Chương 4 — Hình 4.3 |
| `06-hoat-dong-chan-doan.mmd` | Hoạt động | Riêng phần rẽ nhánh: khi nào hệ thống từ chối chẩn đoán | Chương 4 — bổ trợ Hình 4.3 |
| `07-tuan-tu-them-chuong.mmd` | Tuần tự | Thêm chuồng → tự sinh lịch tiêm theo phác đồ của giống | Chương 4 — Quản lý chuồng |
| `08-tuan-tu-danh-dau-tiem.mmd` | Tuần tự | Đánh dấu đã tiêm một mũi, chặn xác nhận trùng, +5 điểm an toàn | Chương 4 — Tiêm phòng |
| `09-tuan-tu-xuat-chuong.mmd` | Tuần tự | Xuất chuồng, tính tỷ lệ sống, chuyển sang tab Đã xuất | Chương 4 — Xuất chuồng |
| `10-tuan-tu-ghi-nhan-hao-hut.mmd` | Tuần tự | Cập nhật số con còn sống, tính lại chỉ số đàn | Chương 4 — Xuất chuồng |
| `11-tuan-tu-quet-tre-han.mmd` | Tuần tự | Tác vụ định kỳ quét mũi trễ, −10 điểm an toàn (BR-03) | Chương 4 — Nghiệp vụ tự động |
| `12-tuan-tu-lich-su-scan.mmd` | Tuần tự | Lịch sử scan và chi tiết một lần chẩn đoán | Chương 4 — Lịch sử |
| `13-tuan-tu-thoi-tiet.mmd` | Tuần tự | Thời tiết Open-Meteo, bỏ dấu tiếng Việt, tính THI | Chương 4 — Môi trường nuôi |
| `14-trang-thai-chuong.mmd` | Trạng thái | ACTIVE / ISOLATED / HARVESTED / SOLD và các mốc tới lứa | Chương 4 — Mô hình nghiệp vụ |
| `15-trang-thai-mui-tiem.mmd` | Trạng thái | PENDING / OVERDUE / COMPLETED / SKIPPED + vòng đời hiệu lực | Chương 4 — Mô hình nghiệp vụ |

Cả 15 file đã được kiểm tra bằng `mermaid.parse()` và `mermaid.render()` phiên bản 11.4.1 — không file nào lỗi cú pháp.

## Cách xuất ảnh để dán vào báo cáo

**Cách 1 — nhanh nhất, không cài gì:** mở <https://mermaid.live>, dán nội dung file vào,
bấm *Actions → PNG* (hoặc SVG nếu muốn in nét).

**Cách 2 — draw.io:** `Arrange → Insert → Advanced → Mermaid`, dán vào rồi chỉnh màu
cho khớp các hình khác trong báo cáo.

**Cách 3 — xuất hàng loạt bằng dòng lệnh** (cần Node.js, lần đầu tải khoảng 300MB):

```bash
cd /Users/mabu/Downloads/SmartFarmVision/docs/mermaid && for f in *.mmd; do npx --yes @mermaid-js/mermaid-cli -i "$f" -o "${f%.mmd}.png" -b white -s 3; done
```

**Cách 4 — xem trước tất cả trong trình duyệt:**

```bash
cd /Users/mabu/Downloads/SmartFarmVision/docs/mermaid && python3 -m http.server 8080
```

rồi mở <http://localhost:8080/xem-truoc.html>.

## Lưu ý khi đưa vào báo cáo

- **Hình 4.3** (`05`) là hình quan trọng nhất — nếu in ra thấy quá cao vì hai nhánh
  `alt` lồng nhau, tách làm hai: 4.3a gồm lượt 1 và cổng chặn ảnh, 4.3b gồm lượt 2,
  lượt 3 và phần lưu kết quả.
- Sơ đồ ERD dùng tên collection thật (`ChuongTrai`, `DanhMucGiong`, `LichTiemPhong`,
  `TrieuChung`, `BenhGiaCam`, `poultryscans`) chứ không phải tên model trong mã Node.js
  — hai tên này khác nhau, nếu thầy hỏi thì đây chính là chỗ dùng tuỳ chọn `collection:`
  trong Mongoose.
- `BanGhiTiem` trong ERD không phải một collection riêng: nó là mảng nhúng
  `vaccination_records` bên trong mỗi document `ChuongTrai`. Nên nói rõ điều này khi
  thuyết trình, vì đó là một quyết định thiết kế của MongoDB (nhúng thay vì tham chiếu).
- Nếu sau này sửa thứ tự các bước trong mã nguồn, nhớ cập nhật lại `.mmd` tương ứng
  trước khi nộp.
