# Provider Rate Limits Reference

> Current free tier limits for all providers configured in this repo. Last verified: March 2026.

---

## Quick Reference

| Provider | Alias | Req/day | Req/min | Tokens/min | Notes |
|---|---|---|---|---|---|
| Groq | `fast` | 14,400 | 30 | 6,000 | 300+ tok/s output |
| Gemini 2.0 Flash | `smart` | 1,500 | 15 | 1,000,000 | Generous token limit |
| OpenRouter | `cloud-free` | ~800 total | 20/model | varies | 29+ free models |
| HuggingFace | `hf-free` | 24,000 | 1,000/hr | varies | License accept needed |
| Cohere Command R+ | `cohere` | ~33/day | 20 | — | 1,000/month trial |
| Cohere Embed v3 | `embed` | ~33/day | 20 | — | 1,000/month trial |
| **Total cloud** | — | **~16,000+** | — | — | Local is unlimited |

---

## Groq

**Dashboard:** https://console.groq.com/settings/limits

| Model | RPD | RPM | TPM |
|---|---|---|---|
| llama-3.3-70b-versatile | 1,000 | 30 | 12,000 |
| llama-3.1-8b-instant | 14,400 | 30 | 6,000 |
| gemma2-9b-it | 14,400 | 30 | 15,000 |
| mixtral-8x7b-32768 | 14,400 | 30 | 5,000 |

**Strategy:** Use `llama-3.1-8b-instant` for high-volume tasks (14,400 RPD). Reserve `llama-3.3-70b` for quality-critical requests.

---

## Google Gemini (AI Studio)

**Dashboard:** https://ai.google.dev/gemini-api/docs/rate-limits

| Model | RPD | RPM | TPM |
|---|---|---|---|
| gemini-2.0-flash | 1,500 | 15 | 1,000,000 |
| gemini-1.5-flash | 1,500 | 15 | 1,000,000 |
| gemini-1.5-pro | 50 | 2 | 32,000 |

**Strategy:** Use `gemini-2.0-flash` as the primary `smart` alias. Avoid `gemini-1.5-pro` on free tier (50 RPD).

---

## OpenRouter

**Dashboard:** https://openrouter.ai/settings/limits

Free models are labeled `:free` in the model string. Each model has its own per-model limit:

| Model | RPD approx. | Notes |
|---|---|---|
| meta-llama/llama-3.1-8b-instruct:free | 200 | Fastest Llama on OR |
| mistralai/mistral-7b-instruct:free | 200 | Good general use |
| google/gemma-2-9b-it:free | 200 | Google alternative |
| deepseek/deepseek-r1-distill-llama-8b:free | 200 | Reasoning tasks |
| microsoft/phi-3-mini-128k-instruct:free | 200 | Long context |

**Total across all free models: ~800–1,200 RPD**

LiteLLM distributes requests across models via `model_list` round-robin when the same alias maps to multiple providers.

---

## HuggingFace Inference API

**Dashboard:** https://huggingface.co/settings/tokens

| Quota | Value |
|---|---|
| Requests/hour | 1,000 |
| Requests/day (derived) | 24,000 |
| Concurrent requests | 1–2 |

**Note:** Some popular models have additional per-model rate limits during peak hours. Errors like `Model is currently loading` are normal — LiteLLM retries automatically.

---

## Cohere (Trial Key)

**Dashboard:** https://dashboard.cohere.com/api-keys

| Quota | Value |
|---|---|
| Requests/month | 1,000 |
| Requests/minute | 20 |
| Derived daily | ~33 |

**Note:** Trial keys are **not for production use**. Upgrade to a paid plan for higher limits. Useful for RAG prototyping with `embed-multilingual-v3`.

---

## Failover Behavior

LiteLLM implements automatic failover per the config:

```yaml
# In config.yaml:
litellm_settings:
  drop_params: true
  num_retries: 3
  request_timeout: 30
  fallbacks:
    - fast: [cloud-free, local-smart]
    - smart: [fast, local-smart]
    - cloud-free: [local-smart]
```

When a `429 Too Many Requests` is received:
1. LiteLLM marks the provider as unhealthy for `cooldown_time` seconds (default: 60)
2. Routes to the next provider in the `fallbacks` chain
3. Re-enables the original provider after cooldown

Check current provider health:

```bash
curl -s http://localhost:4000/health | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'Healthy: {d[\"healthy_count\"]} | Unhealthy: {d[\"unhealthy_count\"]}')
for p in d.get('healthy_endpoints', []):
    print(f'  ✅ {p[\"model\"]}')
for p in d.get('unhealthy_endpoints', []):
    print(f'  ❌ {p[\"model\"]} - {p.get(\"error\", \"\")}')
"
```

---

## Daily Budget Estimation

For a typical homelab AI workflow (chat + agents + RAG):

| Activity | Requests/day |
|---|---|
| Chat (Open WebUI) | 50–200 |
| n8n agent workflows | 100–500 |
| RAG queries | 50–200 |
| Code assist | 50–150 |
| **Total** | **250–1,050** |

At 250–1,050 requests/day, the free tier budget (~16,000 req/day) is more than sufficient. Local inference handles overflow for sensitive or high-volume tasks.

---

*Rate limits verified March 2026. Providers update limits periodically — check dashboards for current values.*
