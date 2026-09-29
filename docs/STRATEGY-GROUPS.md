# Strategy groups

Universal OpenWrt treats service groups as independent policy domains:

- YouTube
- Social
- AI
- Gaming
- Telegram
- Streaming
- Messaging
- Developer
- News

A dedicated strategy (for example Telegram SOCKS5/WS) is isolated to its group. Shared infrastructure strategies such as DPI or AWG full-tunnel are marked `global`; the group engine prevents a second group from silently replacing a different active global strategy.

The system never claims that a per-group policy is active merely because a strategy is stored. Activation must pass capability, configuration, connectivity and regression checks. If a backend cannot provide true domain/policy classification, the UI reports the strategy as unavailable rather than pretending to have split routing.

AI services are handled as connectivity/access diagnostics. The engine can test DNS, TCP/HTTPS, IPv4/IPv6 and HTTP/3 where supported, then select an available transport. It does not bypass provider authentication, account controls or platform safety mechanisms.
