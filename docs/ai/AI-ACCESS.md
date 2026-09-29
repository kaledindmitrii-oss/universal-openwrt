# AI Access Engine

The AI Access Engine is a diagnostic and policy layer for AI services such as ChatGPT, Claude, Gemini, Kimi, DeepSeek, Perplexity, Mistral, Grok, Copilot, Hugging Face, Poe, Cohere and OpenRouter.

## Decision order

1. Direct HTTPS control probe.
2. DNS result check.
3. IPv4 and IPv6 reachability checks.
4. HTTPS timing and response classification.
5. HTTP/3/QUIC capability check when the installed curl supports it.
6. Classify the likely failure: `DNS_BLOCK`, `DPI_BLOCK`, `QUIC_BLOCK`, `IP_BLOCK_OR_GEO`, `AUTH_BLOCK`, `SERVICE_DOWN`, or `PASS`.
7. Only after explicit `--ai-auto` may a compatible local strategy be selected.

The engine never claims that DPI desync can defeat a source-IP or country restriction. Those cases are reported as requiring a selective proxy/relay or an optional tunnel path.

## Presets

Community presets remain available as a fallback registry under `resources/ai/presets/registry.tsv`. The registry intentionally distinguishes Zapret1 and Zapret2. Zapret2 uses Lua strategy calls and is not compatible with Zapret1 `--dpi-desync=*` syntax.

The measured `zapret2-openwrt` project is also tracked as a reference. Its documentation describes a measured `flat` strategy and warns that `nfqws2` is a different engine from Zapret v1.

## Safety

- No AI service is routed through a proxy automatically by diagnosis alone.
- No VPN/WARP is enabled automatically by diagnosis alone.
- Applying an external preset requires the corresponding engine to be installed and a successful syntax/compatibility validation.
- Existing firewall state should be snapshotted before any future mutating adapter is enabled.
