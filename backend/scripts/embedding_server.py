# Máy chủ sinh vector cho truy xuất ngữ nghĩa.
#
# Vì sao cần tiến trình riêng: mô hình embedding là mô hình PyTorch, Node.js không
# chạy được. Cách làm giống hệt llama.cpp - mô hình chạy thành một dịch vụ HTTP
# nhỏ, backend chỉ gọi qua mạng nội bộ. Đổi mô hình thì không phải sửa mã Node.
#
# BẮT BUỘC dùng đúng AITeamVN/Vietnamese_Embedding: toàn bộ vector đã lưu trong
# BenhGiaCam và TrieuChung đều sinh bằng mô hình này. Dùng mô hình khác thì vector
# nằm ở không gian khác, điểm tương đồng trở nên vô nghĩa dù vẫn đủ 1024 chiều.
#
# Máy chủ này phục vụ HAI việc: sinh vector (/embed) và xếp hạng lại (/rerank).
# Gộp chung một tiến trình vì cả hai đều là mô hình PyTorch, tách ra thành hai
# tiến trình chỉ tốn thêm bộ nhớ mà không được gì.
#
# Chạy:  python scripts/embedding_server.py            (cổng 8082)
#        EMBED_PORT=9000 python scripts/embedding_server.py
#
# Thử:   curl -s localhost:8082/health
#        curl -s localhost:8082/embed -H 'Content-Type: application/json' \
#             -d '{"texts":["Mào tím tái, sưng phù đầu"]}' | head -c 120

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from sentence_transformers import SentenceTransformer

MODEL_ID = os.environ.get("EMBED_MODEL", "AITeamVN/Vietnamese_Embedding")
PORT = int(os.environ.get("EMBED_PORT", "8082"))
DEVICE = os.environ.get("EMBED_DEVICE", "mps")

RERANK_MODEL_ID = os.environ.get("RERANK_MODEL", "BAAI/bge-reranker-v2-m3")

print(f"Đang nạp {MODEL_ID} trên {DEVICE} ...", flush=True)
model = SentenceTransformer(MODEL_ID, device=DEVICE)
DIM = model.get_sentence_embedding_dimension()
print(f"✅ Sẵn sàng tại http://127.0.0.1:{PORT}  ({DIM} chiều)", flush=True)

# Reranker nặng khoảng 2,3 GB nên chỉ nạp khi có yêu cầu /rerank đầu tiên.
# Máy 16 GB chạy cùng lúc cả llama.cpp lẫn máy chủ này, nạp sẵn là phí bộ nhớ
# cho những phiên chỉ dùng chẩn đoán mà không tra phác đồ.
_reranker = None


def get_reranker():
    global _reranker
    if _reranker is None:
        from sentence_transformers import CrossEncoder
        print(f"Đang nạp reranker {RERANK_MODEL_ID} ...", flush=True)
        _reranker = CrossEncoder(RERANK_MODEL_ID, device=DEVICE, max_length=512)
        print("✅ Reranker sẵn sàng", flush=True)
    return _reranker


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/") == "/health":
            self._send(200, {"status": "ok", "model": MODEL_ID, "dim": DIM,
                             "rerank_model": RERANK_MODEL_ID, "rerank_loaded": _reranker is not None})
        else:
            self._send(404, {"error": "Chỉ hỗ trợ GET /health và POST /embed"})

    def do_POST(self):
        duong_dan = self.path.rstrip("/")
        if duong_dan == "/rerank":
            return self._rerank()
        if duong_dan != "/embed":
            return self._send(404, {"error": "Chỉ hỗ trợ POST /embed và POST /rerank"})
        try:
            raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            texts = json.loads(raw or b"{}").get("texts")
            if not isinstance(texts, list) or not texts:
                return self._send(400, {"error": "Cần trường 'texts' là mảng chuỗi, không rỗng"})

            # normalize để backend chỉ việc nhân vô hướng, khớp với cách đã mã hoá
            # dữ liệu trong CSDL (similarity dotProduct trên Atlas).
            vectors = model.encode(
                [str(t) for t in texts], normalize_embeddings=True, convert_to_numpy=True
            )
            self._send(200, {"model": MODEL_ID, "dim": DIM, "vectors": vectors.tolist()})
        except Exception as err:  # noqa: BLE001 - trả lỗi cho client thay vì chết tiến trình
            self._send(500, {"error": str(err)})

    def _rerank(self):
        """Chấm lại độ liên quan của từng cặp (query, tài liệu) bằng CrossEncoder.
        Trả về điểm theo ĐÚNG thứ tự tài liệu gửi lên; phía gọi tự sắp xếp và cắt."""
        try:
            raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            payload = json.loads(raw or b"{}")
            query = payload.get("query")
            docs = payload.get("documents")
            if not query or not isinstance(docs, list) or not docs:
                return self._send(400, {"error": "Cần 'query' (chuỗi) và 'documents' (mảng chuỗi)"})

            scores = get_reranker().predict([(str(query), str(d)) for d in docs])
            self._send(200, {"model": RERANK_MODEL_ID, "scores": [float(x) for x in scores]})
        except Exception as err:  # noqa: BLE001
            self._send(500, {"error": str(err)})

    def log_message(self, fmt, *args):
        pass  # không in log mỗi request cho đỡ rối terminal


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
