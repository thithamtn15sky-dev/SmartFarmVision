#!/bin/bash
# Chạy ứng dụng Flutter và trỏ nó về backend đang chạy trên máy này.
#
# Vì sao cần script: địa chỉ backend không nằm trong mã nguồn nữa (xem
# lib/api_config.dart), phải truyền vào lúc chạy. Script tự dò IP LAN để khỏi
# gõ tay mỗi lần đổi mạng WiFi.
#
# Dùng:
#   ./run.sh                          tự dò IP LAN, chạy trên thiết bị mặc định
#   ./run.sh -d chrome                chạy trên Chrome (dùng localhost)
#   API_BASE_URL=http://10.0.2.2:3000 ./run.sh -d emulator-5554
#
# Mọi tham số truyền vào script được chuyển thẳng cho flutter run.

set -euo pipefail
cd "$(dirname "$0")"

PORT="${BACKEND_PORT:-3000}"

# Chrome và macOS chạy ngay trên máy tính nên localhost là đúng; thiết bị Android
# thì localhost trỏ về chính nó, phải dùng IP LAN của máy tính.
if [ -z "${API_BASE_URL:-}" ]; then
  case " $* " in
    *" chrome "*|*" macos "*|*" web-server "*)
      API_BASE_URL="http://localhost:$PORT" ;;
    *)
      # en0 là Wi-Fi trên đa số máy Mac, en1 dự phòng cho máy cắm dây.
      IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
      if [ -z "$IP" ]; then
        echo "❌ Không dò được IP LAN. Truyền tay:"
        echo "   API_BASE_URL=http://<ip-của-bạn>:$PORT ./run.sh"
        exit 1
      fi
      API_BASE_URL="http://$IP:$PORT" ;;
  esac
fi

echo "▶️  Backend: $API_BASE_URL"

# Cảnh báo sớm còn hơn để ứng dụng mở lên rồi mới báo lỗi mạng khó hiểu.
if ! curl -s --max-time 3 "$API_BASE_URL/" >/dev/null 2>&1; then
  echo "⚠️  Không gọi được $API_BASE_URL - backend đã chạy chưa?"
  echo "    Bật bằng:  cd ../backend && node server.js"
  echo "    (vẫn tiếp tục mở ứng dụng)"
fi

exec flutter run --dart-define=API_BASE_URL="$API_BASE_URL" "$@"
