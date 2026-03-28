# litellm-local-config

> **LiteLLM proxy configuration for local AI stacks on ARM64 Windows/WSL2**  
> Unified OpenAI-compatible endpoint · Free tier aggregation · Local NPU/CPU fallback

[![Platform](https://img.shields.io/badge/platform-WSL2%20%7C%20Linux%20ARM64-blue)](https://github.com/BerriAI/litellm)
[![LiteLLM](https://img.shields.io/badge/LiteLLM-v1.82.4+-orange)](https://github.com/BerriAI/litellm)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## What This Is

Production-tested LiteLLM proxy configuration for running a **unified local AI API** that:

- Aggregates **~16,000+ free requests/day** across Groq, Gemini, OpenRouter, HuggingFace
- Routes to **local NPU/CPU inference** (Ollama, GenieAPIService) when cloud is unavailable
- Exposes a single **OpenAI-compatible endpoint** at `http://localhost:4000/v1`
- Implements **automatic failover** with per-provider cooldown

**Primary target hardware:** Snapdragon X Elite / ARM64 Windows 11 + WSL2  
**Also works on:** Any Linux/WSL2 environment with Ollama

---

## Architecture

```
Client (Open WebUI / bolt.diy / curl / any OpenAI SDK)
        │
        ▼
http://localhost:4000/v1   ← LiteLLM Proxy (WSL2, systemd --user)
        │
        ├─► [Tier 1]  fast    → Groq       (llama-3.3-70b, 300+ tok/s, 14.4K req/day)
        │             smart   → Gemini 2.0 Flash (1500 req/day)
        │
        ├─► [Tier 2]  cloud-free → OpenRouter (~800 req/day, 29+ free models)
        │             hf-free    → HuggingFace (1000 req/hr)
        │
        ├─► [Tier 3]  cohere  → Cohere Command R+ (20 req/min, RAG-optimized)
        │             embed   → Cohere embed-multilingual-v3 (embeddings)
        │
        └─► [Local]   local-smart → Ollama CPU  (unlimited, qwen2.5:14b)
                      local-fast  → Ollama CPU  (unlimited, qwen2.5-coder:1.5b)
                      local-npu   → GenieAPIService NPU (Hexagon v73, ~60 req/min)
```

**Failover behavior:** On `429` (rate limit) or `5xx` — automatic 60-second cooldown,
then routes to next provider in chain. No manual intervention required.

---

## Free Tier Summary

| Provider | Daily Limit | Speed | Notes |
|----------|------------|-------|-------|
| Groq | 14,400 req/day | 300+ tok/s | Best for latency-sensitive tasks |
| Google Gemini | 1,500 req/day | Fast | Gemini 2.0 Flash, excellent quality |
| OpenRouter | ~800 req/day total | Varies | 29+ free models, per-model limits |
| HuggingFace | 1,000 req/hr | Moderate | Llama 3.1, Mistral available |
| Cohere | 1,000 req/month | Fast | Trial key — not for production |
| **Total** | **~16,000+/day** | — | Local is unlimited |

---

## Quick Start

### 1. Prerequisites

```bash
# WSL2 Ubuntu 24.04 with Python 3.11+
python3 --version

# Install LiteLLM in isolated virtualenv
python3 -m venv ~/litellm-env
source ~/litellm-env/bin/activate
pip install 'litellm[proxy]'
litellm --version
```

### 2. Configure

```bash
mkdir -p ~/litellm
cp config/config.yaml.example ~/litellm/config.yaml

# Edit: add your API keys
nano ~/litellm/config.yaml
```

**Required API keys** (all have free tiers — see [docs/api-keys.md](docs/api-keys.md)):
- `GROQ_API_KEY` — [console.groq.com](https://console.groq.com)
- `GEMINI_API_KEY` — [aistudio.google.com](https://aistudio.google.com)
- `OPENROUTER_API_KEY` — [openrouter.ai](https://openrouter.ai)

### 3. Start

```bash
# Manual start
source ~/litellm-env/bin/activate
litellm --config ~/litellm/config.yaml --port 4000

# Or install as systemd user service (recommended)
cp scripts/litellm-proxy.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable litellm-proxy
systemctl --user start litellm-proxy
```

### 4. Verify

```bash
curl -s http://localhost:4000/health \
  -H "Authorization: Bearer sk-local-vivo2" | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'Healthy: {d[\"healthy_count\"]} | Unhealthy: {d[\"unhealthy_count\"]}')
"
# Expected: Healthy: 9 | Unhealthy: 0
```

---

## Usage

All requests use standard OpenAI SDK syntax, just point to `localhost:4000`:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key="sk-local-vivo2"
)

# Fast cloud inference
response = client.chat.completions.create(
    model="fast",   # → Groq, 300+ tok/s
    messages=[{"role": "user", "content": "Summarize this log file: ..."}],
    max_tokens=500
)

# Smart reasoning
response = client.chat.completions.create(
    model="smart",  # → Gemini 2.0 Flash
    messages=[{"role": "user", "content": "Analyze this architecture diagram..."}]
)

# Local NPU (no cloud, privacy-first)
response = client.chat.completions.create(
    model="local-npu",  # → GenieAPIService / Hexagon v73
    messages=[{"role": "user", "content": "Process this sensitive document..."}]
)
```

---

## File Structure

```
litellm-local-config/
├── README.md
├── config/
│   ├── config.yaml.example       ← Template with placeholders (safe to commit)
│   └── config.yaml               ← Your actual config (DO NOT COMMIT — in .gitignore)
├── scripts/
│   ├── litellm-proxy.service     ← systemd user service unit
│   ├── install.sh                ← One-shot install script
│   └── health-check.sh           ← Quick diagnostic
└── docs/
    ├── api-keys.md               ← Where to get each free API key
    ├── provider-limits.md        ← Rate limits reference
    └── troubleshooting.md        ← Common issues
```

---

## Security Notes

- `sk-local-vivo2` is a **local-only master key** — change it to a random value
- `config.yaml` is in `.gitignore` — **never commit it** (contains real API keys)
- Proxy binds to `127.0.0.1:4000` by default — not externally accessible
- Use `config.yaml.example` as the public template with `YOUR_KEY_HERE` placeholders

---

## Related

- [snapdragon-ai-stack](https://github.com/your-username/snapdragon-ai-stack) — Full stack setup
- [windows-ai-autostart](https://github.com/your-username/windows-ai-autostart) — Autostart automation
- [LiteLLM docs](https://docs.litellm.ai/docs/) — Official documentation
