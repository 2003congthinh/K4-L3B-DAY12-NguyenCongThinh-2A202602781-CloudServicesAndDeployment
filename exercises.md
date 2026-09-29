# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Công Thịnh  Mã học viên: 2A202602781

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống: khi deploy lên Railway tôi quên set `AGENT_API_KEY` cho service
> `agent` (chuyện này đã xảy ra thật ở CP5). Nếu `Settings` có mặc định
> `"changeme"`, app vẫn chạy bình thường với khóa `"changeme"` — một giá trị nằm
> công khai trong source trên GitHub. Bất kỳ ai đọc repo đều gọi được `/ask` và
> tiêu ngân sách LLM của tôi, còn tôi chỉ phát hiện khi nhìn hóa đơn.
>
> Không có mặc định thì `Settings()` ném `ValidationError: agent_api_key Field
> required` → lỗi lộ ra ngay lúc deploy, khi tôi còn đang nhìn màn hình. Thực tế
> ở lần deploy của tôi, `/ask` trả 500 thay vì mở cửa cho người lạ, và
> `railway logs` chỉ thẳng ra biến bị thiếu.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Một dòng log thật lấy từ `docker compose logs agent`:
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T04:58:56.100671+00:00", "user_id": "sv-cp4", "tokens_in": 138, "tokens_out": 44, "cost_usd": 4.71e-05}
> ```
>
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
>
> 1. **Lọc và tổng hợp theo trường**: ví dụ lọc `event == "ask_completed"` rồi
>    cộng `cost_usd` theo `user_id` để biết user nào tốn tiền nhất hôm nay. Chuỗi
>    tự do không có `user_id` hay `cost_usd` để máy tách ra.
> 2. **Cảnh báo tự động theo `level`/`timestamp`**: đếm số dòng `level == "error"`
>    trong 5 phút qua và bắn cảnh báo khi vượt ngưỡng. Mỗi event nằm gọn trên một
>    dòng JSON nên công cụ log của cloud parse được ngay, không bị vỡ thành nhiều
>    mảnh.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1730 MB (1.73GB) |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Số đo thật (`docker images`, ngày 29/9/2026): `agent:single` **1.73GB**,
> `agent:multi` **271MB** — nhỏ hơn khoảng 6,4 lần, chênh ~1.46GB.
>
> Xem `docker history` thì phần chênh lệch gồm:
>
> - **Base image đầy đủ `python:3.11`** (dựa trên `buildpack-deps`): riêng hai
>   layer `apt-get` của nó đã là 694MB + 202MB — trình biên dịch `gcc`, header
>   file, thư viện `-dev`, `git`... Bản multi-stage dùng `python:3.11-slim` nên
>   không có mấy thứ này. Tôi kiểm tra: `command -v gcc` trong `agent:single` ra
>   `/usr/bin/gcc`, trong `agent:multi` thì không có gcc.
> - **Cache của pip**: layer `pip install` ở bản 1 stage nặng 95.1MB vì không
>   dùng `--no-cache-dir`; bản multi-stage chỉ copy thư mục `/install` đã cài xong
>   sang, nặng 65.7MB.
>
> Nói gọn: stage `builder` được phép nặng rồi bị vứt đi; image cuối chỉ giữ
> Python slim + thư viện đã cài + code (~250KB). Image nhỏ hơn thì push/pull khi
> deploy nhanh hơn và ít phần mềm thừa để bị khai thác.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Tôi đổi `SERVICE_VERSION = "1.0.0"` thành `"1.0.1"` trong `app/main.py` rồi
> build lại bằng `--progress=plain`:
>
> - **Dockerfile multi-stage của tôi**: `WORKDIR`, `COPY requirements.txt`,
>   `RUN pip install`, `COPY --from=builder /install` đều **CACHED**. Chỉ chạy
>   lại từ `COPY app ./app` trở đi (`COPY app`, `COPY utils`, `RUN useradd`).
>   Tổng thời gian build: **6 giây**.
> - **Bản 1 stage (`COPY . .` đứng trước `RUN pip install`)**: `COPY . .` thay
>   đổi nên mọi layer sau nó mất cache — `pip install` chạy lại toàn bộ mất
>   **87.9 giây**, tổng **101 giây**, chỉ vì sửa một ký tự.
>
> Lý do: Docker cache theo từng layer và hủy cache từ layer đầu tiên có thay đổi
> trở đi. `requirements.txt` hiếm khi đổi nên đặt nó cùng `pip install` lên
> trước; code đổi liên tục nên để cuối. Tôi cũng nhận ra `RUN useradd` đang nằm
> sau `COPY app` nên bị chạy lại vô ích — đưa nó lên trước các lệnh `COPY` code
> thì còn cache được thêm một layer nữa.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện khi container chạy root:
>
> 1. Code Python có lỗ hổng (ví dụ ghép input của user vào lệnh shell, hoặc
>    deserialize dữ liệu không tin cậy) → kẻ tấn công chạy được lệnh tùy ý
>    **với quyền của process uvicorn**.
> 2. Process đó là root (UID 0) → kẻ tấn công là root trong container: đọc/sửa
>    mọi file, cài công cụ, đọc biến môi trường chứa secret.
> 3. Không có user namespace remap thì UID 0 trong container chính là UID 0 trên
>    host. Chỉ cần container có một cấu hình lỏng (mount thư mục host, mount
>    `/var/run/docker.sock`, `--privileged`) hoặc một lỗi kernel để thoát ra, kẻ
>    tấn công thành root trên máy host.
>
> `USER appuser` cắt chuỗi này ngay ở bước 2: process chạy với UID 10001 (tôi đã
> kiểm tra `docker compose exec agent whoami` → `appuser`). Kẻ tấn công vẫn chạy
> được lệnh nhưng chỉ với quyền user thường — không ghi được file của root, không
> cài được gói hệ thống, và nếu có thoát ra host thì cũng chỉ là UID 10001 không
> có đặc quyền.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request trong 2 giây** — gấp đôi hạn mức.
>
> Cách đạt được: gửi 10 request lúc 10:00:59 (hết quota của phút 10:00), bộ đếm
> reset lúc 10:01:00, rồi gửi tiếp 10 request lúc 10:01:00–10:01:01 (quota mới
> của phút 10:01). Cả 20 request đều "đúng luật" vì mỗi phút đồng hồ chỉ có 10.
>
> Với sliding window của tôi, lúc 10:01:01 hàm `hit_count` đếm các request trong
> khoảng (10:00:01, 10:01:01] — vẫn còn 10 request lúc 10:00:59 — nên request thứ
> 11 bị 429 ngay. Muốn gửi thêm phải đợi các request cũ trôi ra khỏi cửa sổ 60 giây.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> **Khác nhau:** rate limit đếm *số request* trong 60 giây gần nhất (chống gọi
> dồn dập, lỗi 429); cost guard đếm *số tiền* đã tiêu trong tháng (chống cháy
> ngân sách, lỗi 402). Một cái đo tốc độ, một cái đo tổng chi phí.
>
> **Rate limit cho qua nhưng cost guard chặn:** một user chỉ gửi 5 request/phút
> (dưới hạn mức 10) nhưng mỗi request có prompt rất dài và lịch sử 20 message →
> mỗi lần tốn nhiều token. Gọi đều đặn cả tháng thì tổng chi vượt 10 USD và bị
> 402, dù chưa bao giờ vượt tốc độ. (Test CP3 mô phỏng đúng việc này: đặt
> `cost:sv-test:<tháng>` = 999 thì request đầu tiên đã bị 402.)
>
> **Ngược lại:** user bấm gửi "hi" 15 lần trong một phút. Mỗi lần chỉ tốn khoảng
> 0.00002 USD, tổng chưa tới 0.001 USD — cost guard không có lý do chặn — nhưng
> request thứ 11 bị 429. Tôi quan sát đúng như vậy khi test: 10 lần 200 rồi 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Nếu `/health` kiểm tra Redis, khi Redis mất kết nối 30 giây:
>
> 1. Redis mất kết nối → cả 3 container cùng lúc gọi `ping()` thất bại → cả 3
>    trả 503 ở endpoint health.
> 2. Orchestrator thấy liveness probe fail đủ số lần (ví dụ 3 lần × 10 giây) →
>    đánh dấu **cả 3** container unhealthy gần như cùng một lúc.
> 3. Orchestrator **restart cả 3** → mọi request đang xử lý dở bị cắt, và trong
>    lúc khởi động lại không còn instance nào phục vụ → toàn hệ thống sập, không
>    chỉ các request cần Redis.
> 4. Container mới lên, nếu Redis vẫn chưa về thì lại fail probe → bị restart
>    tiếp, thời gian chờ restart (backoff) tăng dần.
> 5. Redis quay lại ở giây 30 nhưng các container đang kẹt trong vòng restart /
>    backoff → sự cố 30 giây của Redis biến thành sự cố dài hơn của cả cụm.
>
> Khi tách riêng (như bài của tôi), tôi đã thử `docker compose stop redis`:
> `/health` vẫn 200, còn `/ready` trả 503 `{"status":"not ready","redis":false}`.
> Load balancer chỉ ngừng gửi traffic, **không restart** container nào. Bật Redis
> lại thì `/ready` về 200 ngay, không mất gì.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Vì cổng `8000:8000` cố định không cho 3 container cùng bind, tôi chạy
> `docker compose up --scale agent=3` kèm service `nginx` (dùng
> `nginx/nginx.conf` có sẵn) làm load balancer ở cổng 8080, rồi gọi `/ask` 6 lần
> với cùng `X-User-Id: sv-q9`:
>
> - `history_length` lần lượt là **0, 2, 4, 6, 8, 10** — tăng đều 2 mỗi lượt.
> - Đếm log từng container: **agent-1, agent-2, agent-3 mỗi cái xử lý 2
>   request** (nginx chia round-robin). Tức là các lượt liên tiếp rơi vào các
>   container khác nhau nhưng lịch sử vẫn liền mạch, vì cả 3 cùng đọc/ghi
>   `history:sv-q9` trong một Redis.
>
> Nếu lịch sử nằm trong dict Python, mỗi container chỉ thấy các lượt mà chính
> nó xử lý. Với round-robin qua 3 container, con số sẽ nhảy kiểu
> **0, 0, 0, 2, 2, 2, 4, ...** (hoặc lộn xộn hơn nếu phân phối không đều) thay vì
> tăng đều — agent "mất trí nhớ" ngẫu nhiên tùy request rơi vào container nào,
> và mất hẳn khi container bị restart.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi:** sau khi deploy lên Railway, `/health` trả 200 nhưng `/ready` và cả
> `/ask` (không có key, lẽ ra phải 401) đều trả `HTTP 500 Internal Server Error`.
> Dashboard vẫn báo service "Online".
>
> **Tìm nguyên nhân:** `railway logs` cho thấy traceback ở mọi request:
>
> ```
> expected = get_settings().agent_api_key
> pydantic_core._pydantic_core.ValidationError: 1 validation error for Settings
> agent_api_key
>   Field required
> ```
>
> Kiểm tra `railway variables --service agent` thì service `agent` không có biến
> nào trong 5 biến (`AGENT_API_KEY`, `REDIS_URL`, ...) — tôi đã set nhầm chỗ
> nên chúng không được gắn vào service agent. `/health` vẫn 200 chỉ vì nó không
> đọc config; `/ready` và `/ask` gọi `get_settings()` nên nổ.
>
> **Sửa:** set lại biến trên đúng service bằng
> `railway variables --service agent --set ...`, với
> `REDIS_URL=${{Redis.REDIS_URL}}` để tham chiếu Redis cùng project. Railway tự
> redeploy; sau đó `/ready` trả 200 `{"status":"ready","redis":true}`, `/ask`
> không key trả 401, test CP5 pass.
>
> **Bài học:** config được đọc "lười" ở request đầu tiên, nên app vẫn khởi động
> và báo Online dù thiếu secret. Gọi `get_settings()` ngay lúc startup mới thật
> sự fail fast — deploy sẽ đỏ ngay thay vì trông như chạy tốt.
