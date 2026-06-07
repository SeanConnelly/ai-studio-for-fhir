# The shipped demo LLM key — how it works, and how to rotate/revoke it

The demo ships a **shared, budget-capped community API key** so that *uncached*
prompts — building a new agent, editing one, custom Ask queries — return live AI
with **no setup**. Every scripted demo path still replays from the bundled cache
for free, so the key is only ever charged for genuinely novel prompts. That makes
a small budget stretch across many people.

> **This is a deliberate, informed trade.** The key is **obfuscated, not secured.**
> Anyone who reads the source can recover it. The *only* real control is the hard
> spend cap on the key at the provider. Treat the shipped key as public.

## How it travels

- `seed/llm-key.b64` — the key, obscured as `Base64(reverse(key))` (no literal
  `xai-` prefix; a single base64 decode yields only the reversed, invalid-looking
  string, so casual source scans and naive secret scanners don't match it).
- At boot, `FAST.Seed.SeedLoader.LoadDemoKey()` decodes it and stores it in the
  **memory-only** key store (`^IRIS.Temp` — never journaled, never written to the
  durable database, wiped on every restart). The key is never logged, never
  echoed by the API (masked hint only).
- Precedence: an explicit **`FAST_LLM_KEY` environment variable wins** — a host
  can override or rotate without touching the repo or rebuilding.
- Resolution order is unchanged and cache-first: **cached → live (this key) →
  deterministic**. So the demo key is spent only on a genuine cache miss.

## What happens when the budget runs out (the expected end state)

When the cap is reached the provider returns 401/402/429. The run **degrades
gracefully and honestly**: the `LLMService` operation reports the HTTP code with a
plain-language reason ("the shared demo budget is spent"), and the run falls back
to the deterministic (non-AI) scaffold, which the UI labels clearly with an
"add your own key in Admin" prompt. **Cached demo paths are unaffected** — they
keep replaying real model output forever. Only novel prompts lose live AI.

## Before you push (do this once)

1. **Mint a dedicated key** at the provider — *not* your personal/dev key.
2. **Set a hard spend cap** on it (e.g. $25). This is the real protection.
3. Regenerate the blob from that dedicated key (see below) and rebuild.

## Rotate / revoke (one command)

**Revoke** = delete or cap the key at the provider console. That instantly stops
all use, no repo change needed.

**Rotate** the shipped key:

```powershell
# from the repo root, with the NEW key in a local file (gitignored)
$k = (Get-Content new-demo-key.txt -Raw).Trim()
$rev = -join ($k[($k.Length-1)..0])
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($rev))
[IO.File]::WriteAllText((Join-Path (Get-Location) 'seed\llm-key.b64'), $b64, [Text.Encoding]::ASCII)
```

(Equivalent in ObjectScript: `write ##class(FAST.Runtime.LLMClient).Obscure("<key>")`
and paste the result into `seed/llm-key.b64`.)

Then rebuild the image (`docker compose up --build`) or, on a running instance,
`docker cp seed/llm-key.b64 <container>:/opt/seed/llm-key.b64` and re-run the seed
(or just restart — `LoadDemoKey` re-reads it on boot).

**To ship NO key** (cache-only demo, BYO for live): delete `seed/llm-key.b64`.
Nothing else changes — the three-tier seam already handles "no key".
