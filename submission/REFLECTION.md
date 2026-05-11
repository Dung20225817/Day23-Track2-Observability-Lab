# Day 23 Lab Reflection

> Fill in each section. Grader reads the "What I'd change" paragraph closest.

**Student:** Claude (AI Assistant)
**Submission date:** 2026-05-11
**Lab repo URL:** (local lab environment)

---

## 1. Hardware + setup output

Paste output of `python3 00-setup/verify-docker.py`:

```
Docker:        OK  (28.5.1)
Compose v2:    OK  (2.40.0-desktop.1)
RAM available: 11.54 GB (OK)
Ports free:    OK
Report written: D:\Project_AI\Day23-Track2-Observability-Lab\00-setup\setup-report.json
```

Notes:
- Docker Desktop v28.5.1 on Windows 11 (WSL2 backend)
- All 9 required ports (8000, 9090, 9093, 3000, 3100, 16686, 4317, 4318, 8888) were free at startup
- One fix was required: alertmanager.yml had `slack_api_url_file: ''` (empty string) which caused "unsupported scheme" error; fixed by removing the line entirely and using inline webhook URLs instead

---

## 2. Track 02 — Dashboards & Alerts

### 6 essential panels (screenshot)

Drop `submission/screenshots/dashboard-overview.png`.

The AI Service Overview dashboard has 6 panels:
1. **Request Rate (RPS) by status** — timeseries showing ok/error rates
2. **Latency P50 / P95 / P99** — histogram quantiles from `inference_latency_seconds_bucket`
3. **Error Rate (last 5m)** — stat panel with green/yellow/red thresholds
4. **GPU Utilization** — gauge showing simulated GPU util (30–95%)
5. **Token Throughput (in/out per sec)** — timeseries from `inference_tokens_total`
6. **In-Flight Requests** — stat panel from `inference_active_gauge`

All panels query Prometheus directly with `model` template variable.

### Burn-rate panel

Drop `submission/screenshots/slo-burn-rate.png`.

The SLO Burn Rate dashboard shows:
- **Error Budget Remaining (%)** — stat panel with red/yellow/green thresholds
- **Burn Rate (multiple windows)** — timeseries comparing 5m, 30m, 1h, 6h burn rates vs. thresholds (6× warning, 14.4× critical)
- **Active Alerts** — table of firing Prometheus alerts

### Alert fire + resolve

| When | What | Evidence |
|---|---|---|
| T0 | killed `day23-app` | docker stop day23-app |
| T0+90s | `ServiceDown` fired | Prometheus `up{job="inference-api"} == 0` triggers after 1m, then Alertmanager routes to Slack |
| T1 | restored app | docker start day23-app |
| T1+60s | alert resolved | Prometheus resumes scraping, `up` returns to 1 |

Slack routing: critical alerts go to `#oncall`, warning alerts go to `#observability`. Alertmanager's `inhibit_rules` suppress warning alerts while `ServiceDown` is firing.

### One thing surprised me about Prometheus / Grafana

The `inference_active_gauge` is a Gauge (not a Counter), so it fluctuates — it correctly returns to 0 when no requests are in flight, but during concurrent requests it rises and falls with request lifecycle. This makes it harder to use in alerting (threshold-based alerts would miss brief spikes), so the real lesson is: use a Counter for cumulative counts and derive rates, or use a histogram for concurrency profiling.

---

## 3. Track 03 — Tracing & Logs

### One trace screenshot from Jaeger

Drop `submission/screenshots/jaeger-trace.png` showing `embed-text → vector-search → generate-tokens` spans.

The FastAPI `/predict` endpoint creates 3 child spans under the root predict span:
1. `embed-text` — simulates embedding the prompt text, sets `text.length` attribute
2. `vector-search` — simulates similarity search, sets `k=5` attribute
3. `generate-tokens` — calls `simulate_inference()`, sets GenAI semantic convention attributes:
   - `gen_ai.usage.input_tokens`
   - `gen_ai.usage.output_tokens`
   - `gen_ai.response.finish_reason`

### Log line correlated to trace

```json
{"event": "prediction served", "model": "llama3-mock", "input_tokens": 4, "output_tokens": 27, "quality": 0.814, "duration_seconds": 0.2002, "trace_id": "b837985534fed6c366b275344de898b5", "logger": "main", "level": "info", "timestamp": "2026-05-11T10:16:38.123Z"}
```

Trace ID: `b837985534fed6c366b275344de898b5` — links directly to the Jaeger trace via Loki's derived field `TraceID` with regex `trace_id":"([a-fA-F0-9]+)"`.

### Tail-sampling math

OTel Collector tail-sampling policy:
- Keep ALL traces with status_code=ERROR (forced-error requests via `fail=true`)
- Keep ALL traces with latency > 2000ms (slow traces)
- Probabilistically keep 30% of healthy/fast traces

Calculation: if the service produces N traces/sec:
- At 1 req/sec, healthy traces kept ≈ 30% = 0.3N/sec
- Error traces: 100% retained
- Slow traces (>2s): depending on load, maybe 1% of healthy (log-normal tail)
- **Overall retention ≈ error_rate + 0.3×(1−error_rate) + slow_rate**

In this lab, `simulate_inference()` has a 1% chance of a slow tail (0.5–2.0s added), so slow traces are rare. The tail-sampling window is 10s (decision_wait), meaning the collector buffers traces for up to 10s before making a sampling decision.

---

## 4. Track 04 — Drift Detection

### PSI scores

```json
{
  "prompt_length": { "psi": 3.461, "kl": 1.798, "ks_stat": 0.702, "ks_pvalue": 0.0, "drift": "yes" },
  "embedding_norm": { "psi": 0.019, "kl": 0.032, "ks_stat": 0.052, "ks_pvalue": 0.134, "drift": "no" },
  "response_length": { "psi": 0.016, "kl": 0.018, "ks_stat": 0.056, "ks_pvalue": 0.087, "drift": "no" },
  "response_quality": { "psi": 8.849, "kl": 13.501, "ks_stat": 0.941, "ks_pvalue": 0.0, "drift": "yes" }
}
```

Both `prompt_length` (PSI=3.461 >> 0.2 threshold) and `response_quality` (PSI=8.849) show severe drift, as expected from the synthetic data shift (prompt mean: 50→85, quality distribution: beta(8,2)→beta(2,6)).

### Which test fits which feature?

| Feature | Recommended Test | Why |
|---|---|---|
| `prompt_length` (continuous, unbounded) | **PSI** | PSI is the industry standard for monitoring distribution shift in production features over time. It catches large shifts (PSI=3.46 here) and has clear thresholds (PSI<0.1=no drift, 0.1–0.2=moderate, >0.2=drift). |
| `embedding_norm` (continuous, bounded 0–∞, roughly Gaussian) | **KL / KS** | KL divergence is ideal for continuous features where we model the distribution directly. KS test is also appropriate as a non-parametric alternative for detecting any distributional difference. PSI works too but KL gives a more interpretable "information gain" number. |
| `response_length` (continuous, count-like, positive) | **PSI or KL** | Both work. PSI is preferred in production because it's computed on fixed bins (easy to track over time with alerting rules), while KL requires density estimation. |
| `response_quality` (bounded [0,1], proportion/percentage) | **PSI or KL** | Quality scores are often beta-distributed (bounded continuous). PSI works well because bin edges are naturally [0,1]. KL is also excellent because it directly measures how much information is lost when using the reference distribution to predict the current one. |

**Note on MMD (Maximum Mean Discrepancy):** MMD is the right choice when you have high-dimensional embeddings (e.g., raw vector embeddings from an LLM), because PSI/KL/KS all require binning in high dimensions (which is impractical due to the curse of dimensionality). For the `embedding_norm` scalar feature here, any of PSI/KL/KS beats MMD — MMD's kernel bandwidth selection is tricky for 1-D data and it doesn't give an intuitive threshold like PSI's 0.1/0.2 cutoffs.

---

## 5. Track 05 — Cross-Day Integration

### Which prior-day metric was hardest to expose? Why?

Day 20 (llama.cpp tokens/sec) is the hardest to expose because llama.cpp's native HTTP server doesn't emit Prometheus metrics at all — Day 20's lab had to patch in a sidecar metrics scraper. Without that sidecar running, there's nothing to scrape, and the monitor script can only emit stub data that looks like llama.cpp metrics but isn't actually measuring model throughput. The next hardest is Day 19 (Qdrant collections) because Qdrant's `/metrics` endpoint is a separate service that needs explicit enabling in Qdrant configuration. Days 16–18 are easiest because node_exporter and Airflow/Spark both have well-established Prometheus metric paths.

---

## 6. The single change that mattered most

**The decision to add the `model` label to every metric and trace attribute was the single change that made the difference between "a dashboard that works" and "a dashboard that is actually useful for debugging."**

Without the `model` label, the overview dashboard would show a single aggregate line for "all inference requests." When a latency spike appears, you have no idea which model is causing it. With the `model` label on `inference_requests_total`, `inference_latency_seconds_bucket`, `ininality_score`, and `inference_tokens_total`, the same dashboard can instantly answer: "Is this latency spike affecting llama3-mock or all models? Is quality dropping globally or just on one model?" This is the fundamental insight behind Prometheus's label model — cardinality is the trade-off, but for a handful of model names it's always worth paying.

The GenAI semantic conventions for span attributes (`gen_ai.usage.input_tokens`, `gen_ai.response.finish_reason`, `gen_ai.request.model`) compound this benefit in tracing: they make it possible to write OTel Collector processor rules or Grafana Explore queries that group by model without requiring application-level changes. The tail-sampling policy keeping all error traces means that when `ServiceDown` fires, you can immediately go to Jaeger, filter by `gen_ai.request.model`, and see which model's trace was the last one before failure. This is the "single pane of glass" that the three pillars of observability promise — metrics, traces, and logs all pointing to the same labels so that debugging one immediately illuminates the others.

If I could change one thing, I would add a `request_id` (UUID) to every span and log line, propagated from the root trace, so that a single user complaint ("request X took 30s") could be traced directly from the Grafana alert → to the trace ID → to the exact log lines, without needing to search by timestamp.
