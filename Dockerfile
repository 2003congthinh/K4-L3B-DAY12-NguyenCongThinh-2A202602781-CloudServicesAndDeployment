# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   [x] Multi-stage build: `builder` cài dependency, `runtime` chỉ copy kết quả
#   [x] Base image slim
#   [x] COPY requirements.txt + pip install TRƯỚC khi COPY source code
#   [x] Chạy bằng user thường (appuser), không phải root
#   [x] HEALTHCHECK gọi /health
#   [x] Đọc cổng từ biến môi trường PORT
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài thư viện vào /install, stage này bị vứt đi ──
FROM python:3.11-slim AS builder

WORKDIR /build

# Chỉ copy requirements trước: sửa code không làm mất cache của layer pip install
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime — chỉ mang theo thư viện đã cài và source code ──
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

COPY --from=builder /install /usr/local

# Source code copy SAU cùng — layer hay thay đổi nhất đặt ở cuối
COPY app ./app
COPY utils ./utils

# User thường: thoát được khỏi app cũng không có quyền root trong container
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# Image slim không có curl → dùng chính Python để gọi /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8000') + '/health', timeout=4).read()" || exit 1

# Dạng shell để ${PORT} được nội suy; bind 0.0.0.0 để bên ngoài container gọi vào được.
# `exec` để uvicorn THAY THẾ sh và trở thành PID 1 — nếu không, sh nhận SIGTERM
# mà không chuyển tiếp, uvicorn không bao giờ tắt êm và bị SIGKILL (exit 137).
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
