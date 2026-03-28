# API Keys — Where to Get Each Free Tier

> All providers listed here have **free tiers** sufficient for local AI stack use.  
> No credit card required for any of them at the free level.

---

## Groq — `fast` model alias

**URL:** https://console.groq.com  
**Free tier:** 14,400 requests/day, 30 requests/minute  
**Models available:** Llama 3.3 70B, Llama 3.1 8B, Mixtral, Gemma 2

```
1. Sign up at console.groq.com
2. Left sidebar → API Keys → Create API Key
3. Copy value → paste into config.yaml as GROQ_API_KEY
```

**Best for:** Fast agent loops, batch processing, any latency-sensitive task.
At 300+ tokens/second, Groq is the fastest free inference available.

---

## Google AI Studio (Gemini) — `smart` model alias

**URL:** https://aistudio.google.com  
**Free tier:** 1,500 requests/day, 15 requests/minute  
**Models:** Gemini 2.0 Flash (recommended), Gemini 1.5 Pro

```
1. Sign in with Google account at aistudio.google.com
2. Top right → Get API Key → Create API key in new project
3. Copy value → paste as GEMINI_API_KEY
```

**Best for:** Complex reasoning, long-context tasks, code generation, analysis.

---

## OpenRouter — `cloud-free` model alias

**URL:** https://openrouter.ai  
**Free tier:** 200 requests/day per model, 20 req/min  
**Free models:** 29+ including Llama 3.1, Mistral 7B, Gemma 2, DeepSeek

```
1. Sign up at openrouter.ai
2. Top right → Keys → Create Key
3. Copy value → paste as OPENROUTER_API_KEY
```

Browse free models at: https://openrouter.ai/models?order=newest&supported_parameters=free

**In config.yaml** — change the model string to switch free models:
```yaml
model: openrouter/meta-llama/llama-3.1-8b-instruct:free
# Alternatives:
# openrouter/mistralai/mistral-7b-instruct:free
# openrouter/google/gemma-2-9b-it:free
# openrouter/deepseek/deepseek-r1-distill-llama-8b:free
```

---

## HuggingFace — `hf-free` model alias

**URL:** https://huggingface.co/settings/tokens  
**Free tier:** 1,000 requests/hour  
**Models:** Llama 3.1, Mistral, Qwen, many others

```
1. Sign up at huggingface.co
2. Settings → Access Tokens → New Token
3. Token type: Fine-grained
4. Permissions needed:
   ✅ Inference Providers (serverless)
   ✅ Read access to public gated repos
5. Copy value → paste as HUGGINGFACE_TOKEN
```

**Note:** Some models (Llama 3.1) require accepting a license on the model page first.
Visit the model page and click "Agree and access repository" when logged in.

---

## Cohere — `cohere` and `embed` aliases

**URL:** https://dashboard.cohere.com  
**Free tier (trial key):** 1,000 requests/month, 20 requests/minute  
**Models:** Command R+, embed-multilingual-v3

```
1. Sign up at dashboard.cohere.com
2. API Keys → Copy trial key
3. Paste as COHERE_TRIAL_KEY
```

**Important:** Trial key is for development only — not for commercial use.
For production, upgrade to a paid plan.

**Best for:** RAG with long documents (Command R+ has 128K context),
multilingual embedding.

---

## Security Checklist

After filling in all keys in `config.yaml`:

```bash
# 1. Verify .gitignore is protecting config.yaml
git status
# config.yaml must NOT appear in the output

# 2. Test .gitignore works
git check-ignore -v config/config.yaml
# Expected: config/.gitignore:2:config/config.yaml  config/config.yaml

# 3. Verify no keys in git history (if repo is new, this is fine)
git log --all --full-history -- "*config.yaml"
# Should be empty if you've never committed it

# 4. Double-check example file has no real keys
grep -n "YOUR_" config/config.yaml.example | wc -l
# Should match number of API key placeholders
```
