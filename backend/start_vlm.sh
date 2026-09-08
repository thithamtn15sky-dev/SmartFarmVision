#!/bin/bash
# Khởi động model Qwen3-VL (llama.cpp + Metal) để backend phân tích ảnh gà bệnh.
#
# Dùng: ./start_vlm.sh          -> chạy nền, ghi log ra /tmp/vlm_smartfarm.log
#       ./start_vlm.sh -f       -> chạy hiện log ngay trên terminal (Ctrl+C để dừng)
#
# Lưu ý: port 8080 đang bị dự án ToxicModerationLLM chiếm, nên dùng 8081.

set -e

VLM_HOME="$HOME/Downloads/SmartFarmVLM"
BIN="$VLM_HOME/llama_backend_metal/b10092/llama-b10092/llama-server"
MODEL="$VLM_HOME/models/Qwen3VL-2B-Instruct-Q4_K_M.gguf"
MMPROJ="$VLM_HOME/models/mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf"
PORT="${VLM_PORT:-8081}"
LOG="/tmp/vlm_smartfarm.log"

# --mmproj là bắt buộc: thiếu nó model sẽ KHÔNG nhìn được ảnh, chỉ đọc chữ.
for f in "$BIN" "$MODEL" "$MMPROJ"; do
  [ -f "$f" ] || { echo "❌ Không tìm thấy: $f"; exit 1; }
done

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "⚠️  Port $PORT đang có tiến trình chạy:"
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN | tail -n +2
  echo "    Dừng nó bằng: kill \$(lsof -ti tcp:$PORT)   hoặc đổi port: VLM_PORT=8090 ./start_vlm.sh"
  exit 1
fi

ARGS=(-m "$MODEL" --mmproj "$MMPROJ" --host 127.0.0.1 --port "$PORT"
      -c 8192 -ngl 99 --jinja --no-warmup --image-max-tokens 512)

if [ "$1" = "-f" ]; then
  echo "▶️  Chạy Qwen3-VL ở cổng $PORT (Ctrl+C để dừng)..."
  exec "$BIN" "${ARGS[@]}"
fi

echo "▶️  Đang khởi động Qwen3-VL ở cổng $PORT..."
nohup "$BIN" "${ARGS[@]}" > "$LOG" 2>&1 &
PID=$!

for i in $(seq 1 60); do
  if curl -s "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q '"ok"'; then
    echo "✅ Model sẵn sàng tại http://127.0.0.1:$PORT (PID $PID)"
    grep -q "loaded multimodal model" "$LOG" \
      && echo "✅ Đã nạp mmproj - model NHÌN được ảnh." \
      || echo "⚠️  Chưa thấy log nạp mmproj, kiểm tra $LOG"
    echo "   Log: $LOG    Dừng model: kill $PID"
    exit 0
  fi
  kill -0 $PID 2>/dev/null || { echo "❌ Model chết khi khởi động. Log cuối:"; tail -20 "$LOG"; exit 1; }
  sleep 2
done

echo "❌ Quá 120s model chưa sẵn sàng. Log cuối:"; tail -20 "$LOG"; exit 1
