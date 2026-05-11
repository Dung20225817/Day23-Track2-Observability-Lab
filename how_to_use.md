# Hướng Dẫn Sử Dụng — Day 23 Observability Lab

> Hướng dẫn chi tiết cách chạy lab, chụp ảnh minh chứng, và nộp bài.
> Xem thêm: `README.md` (tổng quan), `rubric.md` (tiêu chí chấm điểm), `submission/REFLECTION.md` (bài luận cá nhân).

---

## 1. Chuẩn Bị (Chỉ Làm Một Lần)

### 1.1. Clone & tạo .env

```bash
git clone <your-fork> && cd Day23-Track2-Observability-Lab
cp .env.example .env
```

Mở file `.env`, sửa `SLACK_WEBHOOK_URL` thành webhook URL từ Slack app của bạn
(Settings → Incoming Webhooks → tạo webhook mới, copy URL vào).

### 1.2. Setup (pre-pull Docker images)

```bash
make setup
```

Script này:
- Pull 6 Docker images (Prometheus, Alertmanager, Grafana, Loki, Jaeger, OTel Collector)
- Chạy `verify-docker.py` kiểm tra Docker + RAM + cổng
- Tạo file `00-setup/setup-report.json`

### 1.3. Khởi động stack

```bash
make up
```

Đợi ~30 giây cho tất cả service khởi động xong.

### 1.4. Kiểm tra mọi thứ healthy

```bash
make smoke
```

Kết quả mong đợi: **7/7 services OK**.

---

## 2. Cách Chụp Ảnh Minh Chứng (Rubric Checklist)

> **Quan trọng:** Lab này chấm điểm dựa trên **ảnh chụp màn hình** trong thư mục `submission/screenshots/`.
> Tất cả ảnh phải chụp **sau khi** đã chạy `make load` để tạo traffic thực tế.
>
> Thứ tự khuyến nghị: **smoke → load → chụp dashboard → alert → chụp Jaeger → chụp Slack → drift → chụp drift → verify**

---

### 2.1. Chạy Load Test (bắt buộc trước chụp dashboard)

```bash
make load
```

Load test chạy 60 giây, tạo ~1000+ requests để metric có data thực.

---

### 2.2. Grafana Dashboards (3 ảnh)

Truy cập **http://localhost:3000** → Đăng nhập `admin` / `admin`

#### Ảnh 1: AI Service Overview (`submission/screenshots/dashboard-overview.png`)

1. Vào **Dashboards** → chọn **AICB Day 23** → **AI Service Overview**
2. Chờ 1-2 phút sau load test để data hiển thị
3. Chụp ảnh toàn bộ dashboard (6 panels: RPS, Latency P50/P95/P99, Error Rate, GPU Util, Token Throughput, In-Flight)
4. Lưu vào `submission/screenshots/dashboard-overview.png`

#### Ảnh 2: SLO Burn Rate (`submission/screenshots/slo-burn-rate.png`)

1. Vào **Dashboards** → **AICB Day 23** → **SLO Burn Rate**
2. Dashboard phải hiển thị các burn rate (5m/30m/1h/6h) — có thể "No Data" nếu chưa có alert
3. Chụp ảnh
4. Lưu vào `submission/screenshots/slo-burn-rate.png`

#### Ảnh 3: Cost & Tokens (`submission/screenshots/cost-and-tokens.png`)

1. Vào **Dashboards** → **AICB Day 23** → **Cost & Tokens**
2. Panel `$ / hr` phải hiển thị số > 0
3. Chụp ảnh
4. Lưu vào `submission/screenshots/cost-and-tokens.png`

---

### 2.3. Grafana Dashboard List (`submission/screenshots/grafana-dashboard-list.png`)

1. Vào **Dashboards** → **Browse**
2. Chụp ảnh danh sách hiển thị đủ **5 dashboards**:
   - AI Service Overview
   - SLO Burn Rate
   - Cost & Tokens
   - Cross-Day Stack
   - (dashboard thứ 5 tùy setup)
3. Lưu vào `submission/screenshots/grafana-dashboard-list.png`

---

### 2.4. Jaeger Traces (2 ảnh)

Truy cập **http://localhost:16686**

#### Ảnh 4: Jaeger Trace Overview (`submission/screenshots/jaeger-trace.png`)

1. Search: `service: inference-api`, click **Find Traces**
2. Danh sách traces xuất hiện → chụp ảnh
3. Lưu vào `submission/screenshots/jaeger-trace.png`

#### Ảnh 5: Jaeger Trace Chi Tiết (`submission/screenshots/jaeger-trace-detailed.png`)

1. Click vào một trace bất kỳ (trace có nhiều spans)
2. Trong trace detail, mở panel **Attributes** (hoặc **Tags**)
3. Chụp ảnh sao cho thấy rõ:
   - 3 child spans: `embed-text`, `vector-search`, `generate-tokens`
   - Attributes theo GenAI conventions: `gen_ai.request.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`
4. Lưu vào `submission/screenshots/jaeger-trace-detailed.png`

---

### 2.5. Alert (2 ảnh Slack)

```bash
make alert
```

Script này: kill app → chờ alert fire → restore app → chờ resolve.

Trong Slack channel đã nhận webhook:

#### Ảnh 6: Alert FIRE (`submission/screenshots/slack-fire.png`)

1. Sau khi `make alert` chạy khoảng 30-90 giây
2. Slack nhận message **"ServiceDown FIRE"**
3. Chụp ảnh message đó

#### Ảnh 7: Alert RESOLVED (`submission/screenshots/slack-resolved.png`)

1. Tiếp tục sau khi app restart (thêm ~60 giây)
2. Slack nhận message **"ServiceDown RESOLVED"**
3. Chụp ảnh message đó

> **Nếu không nhận được Slack:** Kiểm tra `.env` có đúng `SLACK_WEBHOOK_URL` chưa.
> Nếu không muốn dùng Slack, có thể bỏ qua checkpoint 10-11 nhưng sẽ mất 10 điểm.

---

### 2.6. Drift Detection (2 ảnh)

```bash
make drift
```

Script tạo `04-drift-detection/reports/drift-summary.json` và `drift-report.html`.

#### Ảnh 8: Evidently HTML Report (`submission/screenshots/drift-report.png`)

1. Mở file `04-drift-detection/reports/drift-report.html` trong trình duyệt
2. Chụp ảnh toàn bộ trang
3. Lưu vào `submission/screenshots/drift-report.png`

#### Ảnh 9: Drift Summary (`submission/screenshots/drift-summary.png`)

1. Chạy lệnh: `python scripts/drift_detect.py`
2. Hoặc mở `04-drift-detection/reports/drift-summary.json`
3. Chụp output cho thấy **≥ 1 feature có `drift: yes`**
4. Lưu vào `submission/screenshots/drift-summary.png`

---

### 2.7. Cross-Day Dashboard (1 ảnh)

1. Vào **Dashboards** → **AICB Day 23** → **Cross-Day Stack**
2. Dashboard hiển thị metrics từ Days 16-22 (6 panels)
3. Có thể hiển thị "No Data" — vẫn hợp lệ miễn là dashboard load được
4. Chụp ảnh
5. Lưu vào `submission/screenshots/cross-day-dashboard.png`

---

## 3. Tổng Hợp Ảnh Cần Thiết

| # | File | Nội dung | Điểm |
|---|---|---|---|
| 1 | `dashboard-overview.png` | Grafana AI Service Overview (6 panels) | 5+5 |
| 2 | `slo-burn-rate.png` | Grafana SLO Burn Rate | 5+5 |
| 3 | `cost-and-tokens.png` | Grafana Cost & Tokens (số > 0) | 5 |
| 4 | `grafana-dashboard-list.png` | Danh sách 5 dashboards | 5 |
| 5 | `jaeger-trace.png` | Jaeger trace overview | 5 |
| 6 | `jaeger-trace-detailed.png` | Jaeger trace + GenAI attrs | 5 |
| 7 | `slack-fire.png` | Slack: ServiceDown FIRE | 5 |
| 8 | `slack-resolved.png` | Slack: ServiceDown RESOLVED | 5 |
| 9 | `drift-report.png` | Evidently HTML report | 5 |
| 10 | `drift-summary.png` | drift-summary.json (≥1 drift) | 5 |
| 11 | `cross-day-dashboard.png` | Cross-Day Stack dashboard | 5+5 |

**Tổng cộng: 11 ảnh minh chứng cho rubric core.**

---

## 4. Viết REFLECTION.md

Sau khi chụp đủ ảnh, viết bài luận trong `submission/REFLECTION.md`:

### Cấu trúc bắt buộc:

**Section 1: Instrument the AI service (3 Pillars + RED + USE)**
Mô tả đã thêm những metrics nào vào FastAPI, tại sao chọn histogram/counter/gauge.

**Section 2: Prometheus scrape + alerting rules**
Giải thích Prometheus scrape interval, alert rules đã cấu hình.

**Section 3: OTel Collector tail-sampling**
Giải thích tại sao dùng tail-sampling (giữ all errors + 1% healthy).
Trích dẫn 1 dòng log có `trace_id` (copy trực tiếp từ terminal/logs).

**Section 4: Drift detection**
Chọn test phù hợp cho từng feature:
- `prompt_length` → **PSI** (phân phối input)
- `embedding_norm` → **KL/KS** (vector similarity)
- `response_quality` → **PSI** (số thực)
Giải thích lý do.

**Section 5: "Thay đổi duy nhất có ý nghĩa nhất"**
Viết 2-3 đoạn văn về một thay đổi cụ thể đã tạo ra khác biệt lớn nhất trong toàn bộ lab.
(Từ rubric: graded for substance, not length)

---

## 5. Verify & Nộp Bài

### 5.1. Kiểm tra cuối cùng

```bash
make verify
```

Exit code 0 = pass đủ rubric core.

### 5.2. Commit & push

```bash
git add submission/screenshots/ submission/REFLECTION.md 00-setup/setup-report.json
git commit -m "Day 23: observability lab submission"
git push origin main
```

### 5.3. Gửi URL repo

Nộp URL GitHub repo (public) cho người chấm.

---

## 6. Xử Lý Lỗi Thường Gặp

| Lỗi | Cách khắc phục |
|---|---|
| `make smoke` → FAIL | Đợi thêm 30s, kiểm tra `docker compose ps` |
| `make load` → locust not found | Không cần fix — đã dùng Docker thay thế |
| `make alert` → no fire | Kiểm tra Prometheus đang scrape `up{job="inference-api"}` |
| Slack không nhận | Kiểm tra `.env` → `SLACK_WEBHOOK_URL` đúng chưa |
| Drift không tạo file | Chạy `python scripts/drift_detect.py` trong `04-drift-detection/` |
| Dashboard trống | Đợi 1-2 phút sau load test, refresh trình duyệt |
| Jaeger không có trace | Kiểm tra OTel Collector đang chạy, app có gửi traces không |

---

## 7. Các Service

| Service | URL | Mục đích |
|---|---|---|
| `day23-app` | http://localhost:8000 | FastAPI inference API |
| `day23-prometheus` | http://localhost:9090 | Metrics collection |
| `day23-alertmanager` | http://localhost:9093 | Alert routing → Slack |
| `day23-grafana` | http://localhost:3000 | Dashboards (admin/admin) |
| `day23-loki` | http://localhost:3100 | Log aggregation |
| `day23-jaeger` | http://localhost:16686 | Distributed tracing |
| `day23-otel-collector` | http://localhost:8888 | OTel Collector metrics |

---

## 8. Cấu Trúc Project

```
Day23-Track2-Observability-Lab/
├── Makefile                     ← make setup/up/smoke/load/alert/drift/verify/down
├── docker-compose.yml           ← 7 services
├── .env.example                 ← SLACK_WEBHOOK_URL template
├── 00-setup/                    ← Docker pre-flight + setup-report.json
├── 01-instrument-fastapi/       ← FastAPI app (metrics + traces + logs)
├── 02-prometheus-grafana/       ← Prometheus config, 3 dashboards, alerts
├── 03-tracing-and-logs/         ← OTel Collector (tail-sampling), Loki config
├── 04-drift-detection/          ← PSI/KL/KS detection + Evidently HTML
├── 05-integration/              ← Cross-day dashboard (Days 16-22)
├── scripts/                     ← verify.py, trigger-alert.py, lint-dashboards.py
├── submission/
│   ├── REFLECTION.md            ← Bài luận rubric (bắt buộc)
│   └── screenshots/            ← Ảnh minh chứng (bắt buộc)
│       ├── dashboard-overview.png
│       ├── slo-burn-rate.png
│       ├── cost-and-tokens.png
│       ├── cross-day-dashboard.png
│       ├── grafana-dashboard-list.png
│       ├── jaeger-trace.png
│       ├── jaeger-trace-detailed.png
│       ├── slack-fire.png
│       ├── slack-resolved.png
│       ├── drift-report.png
│       └── drift-summary.png
├── BONUS-llm-native-obs/         ← Self-hosted Langfuse (optional +10pts)
├── BONUS-ebpf-profiling/        ← Pyroscope (Linux/WSL only, optional +10pts)
├── rubric.md                    ← Tiêu chí chấm điểm đầy đủ
├── README.md                    ← Tổng quan lab
├── HARDWARE-GUIDE.md            ← Yêu cầu phần cứng
└── VIBE-CODING.md              ← Chọn persona (SRE / Platform / Data)
```
