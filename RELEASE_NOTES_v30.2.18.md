# Universal OpenWrt v30.2.18

## AWG/WARP deep audit and hardening

- Разделены два источника туннельной конфигурации: настоящий AmneziaWG-профиль провайдера и Cloudflare WARP.
- WARP больше не считается автоматически обфусцированным AWG: отсутствие J/S/H-параметров явно маркируется как WireGuard-compatible transport.
- Добавлен импорт существующего `.conf` через `--mode provider --config FILE`; параметры Jc/Jmin/Jmax/S1/S2/H1-H4 сохраняются в UCI.
- Исправлен выбор пакетов: `amneziawg-tools`, `kmod-amneziawg` и `luci-proto-amneziawg` теперь выбираются по полной паре OpenWrt/архитектура/target/subtarget.
- Перед установкой каждого стороннего AWG-пакета выполняется SHA256-проверка digest из GitHub Release API.
- Удалено отключение TLS-проверки (`--no-check-certificate`).
- Исправлен full-tunnel peer selection: маршрутизация больше не может случайно примениться к последнему WireGuard peer другого интерфейса.
- Добавлена реальная firewall-зона клиентского VPN с masquerading, MSS/MTU clamping и LAN→AWG forwarding.
- `awg-split` больше не заявляется рабочей стратегией: в проекте нет собственного policy-routing/domain classifier, поэтому автоматический выбор этой стратегии отключён до появления полноценного split-router.
- AWG/WARP остаётся частью дерева обхода как тяжёлый VPN-транспорт/fallback; DPI/DNS стратегии сохраняются отдельными механизмами.
- Добавлены regression-проверки `tests/awg_deep.sh`.

## Ограничение, которое теперь явно соблюдается

Cloudflare WARP выдаёт WireGuard-совместимую конфигурацию, но не выдаёт AmneziaWG J/S/H параметры. Поэтому WARP нельзя использовать как доказательство того, что трафик маскируется именно AmneziaWG. Для реального AWG-обхода нужен сервер/провайдер, который выдал соответствующий AmneziaWG `.conf` и согласованные параметры на серверной стороне.
