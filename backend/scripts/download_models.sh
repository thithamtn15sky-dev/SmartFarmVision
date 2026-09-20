#!/bin/bash
# Tải trọng số Qwen3-VL và bản llama.cpp biên dịch sẵn cho macOS Apple Silicon.
#
# Vì sao không để trong kho mã nguồn: hai file GGUF nặng 1,48 GB, vượt xa giới hạn
# 100 MB cho mỗi file của GitHub. Script này tải lại đúng phiên bản đã dùng.
#
# Dùng:  ./download_models.sh
#        VLM_HOME=/duong/dan/khac ./download_models.sh
#
# Sau khi chạy xong, bật model bằng:  cd backend && ./start_vlm.sh

set -euo pipefail

VLM_HOME="${VLM_HOME:-$HOME/Downloads/SmartFarmVLM}"
LLAMA_TAG="b10092"
HF_REPO="Qwen/Qwen3-VL-2B-Instruct-GGUF"

MODEL_DIR="$VLM_HOME/models"
LLAMA_DIR="$VLM_HOME/llama_backend_metal"

# Tên file, dung lượng byte mong đợi, đường dẫn trên Hugging Face.
MODEL_FILE="Qwen3VL-2B-Instruct-Q4_K_M.gguf"
MODEL_SIZE=1107409952
MMPROJ_FILE="mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf"
MMPROJ_SIZE=445053216

# mmproj là phần thị giác. Thiếu nó llama-server vẫn chạy nhưng model chỉ đọc chữ,
# không nhìn được ảnh gà - lỗi này rất khó nhận ra nên kiểm tra ngay từ đầu.

echo "Thư mục đích: $VLM_HOME"
mkdir -p "$MODEL_DIR" "$LLAMA_DIR"

# Trả về kích thước file theo byte, 0 nếu chưa có (cú pháp stat của macOS và Linux khác nhau).
kich_thuoc() {
  [ -f "$1" ] || { echo 0; return; }
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

tai_file() {
  local ten="$1" can_co="$2" dich="$MODEL_DIR/$1"
  local dang_co; dang_co=$(kich_thuoc "$dich")

  if [ "$dang_co" -eq "$can_co" ]; then
    echo "✅ Đã có sẵn $ten ($((can_co / 1024 / 1024)) MB), bỏ qua."
    return
  fi
  [ "$dang_co" -gt 0 ] && echo "⚠️  $ten có nhưng sai dung lượng ($dang_co byte), tải lại."

  echo "⬇️  Đang tải $ten ..."
  # -L theo chuyển hướng của Hugging Face sang CDN, -C - tiếp tục nếu đứt giữa chừng.
  curl -L -C - --fail --progress-bar \
    -o "$dich" "https://huggingface.co/$HF_REPO/resolve/main/$ten"

  dang_co=$(kich_thuoc "$dich")
  if [ "$dang_co" -ne "$can_co" ]; then
    echo "❌ $ten tải xong nhưng dung lượng là $dang_co, đáng lẽ phải là $can_co."
    echo "   Xoá file rồi chạy lại: rm '$dich'"
    exit 1
  fi
  echo "✅ Xong $ten."
}

tai_file "$MODEL_FILE" "$MODEL_SIZE"
tai_file "$MMPROJ_FILE" "$MMPROJ_SIZE"

# --- llama.cpp ---
BIN="$LLAMA_DIR/$LLAMA_TAG/llama-$LLAMA_TAG/llama-server"
if [ -x "$BIN" ]; then
  echo "✅ Đã có llama-server $LLAMA_TAG, bỏ qua."
else
  TAR="$LLAMA_DIR/llama-$LLAMA_TAG-bin-macos-arm64.tar.gz"
  echo "⬇️  Đang tải llama.cpp $LLAMA_TAG ..."
  curl -L -C - --fail --progress-bar -o "$TAR" \
    "https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_TAG/llama-$LLAMA_TAG-bin-macos-arm64.tar.gz"
  mkdir -p "$LLAMA_DIR/$LLAMA_TAG"
  tar -xzf "$TAR" -C "$LLAMA_DIR/$LLAMA_TAG"
  [ -x "$BIN" ] || { echo "❌ Giải nén xong nhưng không thấy $BIN"; exit 1; }
  # macOS gắn cờ cách ly cho file tải từ mạng, gỡ đi thì mới chạy được.
  xattr -dr com.apple.quarantine "$LLAMA_DIR/$LLAMA_TAG" 2>/dev/null || true
  echo "✅ Xong llama.cpp $LLAMA_TAG."
fi

echo
echo "Hoàn tất. Dung lượng đã tải:"
du -sh "$MODEL_DIR" "$LLAMA_DIR"
echo
echo "Bước tiếp theo:  cd backend && ./start_vlm.sh"
