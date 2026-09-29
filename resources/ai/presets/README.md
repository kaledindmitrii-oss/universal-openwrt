# AI / DPI preset registry

These entries are **reserve adapters**, not blindly applied defaults. Universal OpenWrt keeps the upstream references so a router can explicitly fetch a current community preset when the built-in diagnosis says that DPI desync is appropriate.

Why this is deliberate:

- Zapret v1 (`nfqws`) and Zapret2 (`nfqws2`) are different engines and their strategy syntax is not interchangeable.
- A community preset can be useful on one ISP/path and harmful or ineffective on another.
- DNS/IP/geo restrictions cannot be repaired by TLS desync alone.
- The project therefore tests direct access first, classifies the failure, and only then offers a compatible preset family.

The Universal V9/V8/V2.1 entries come from the public `RixyPow/Zapret-UNIVERSAL-preset` repository. Its README states that the presets target Zapret2/NetZapret and cover AI services among other traffic classes. The project does not vendor the upstream text files; use the explicit fetch/import action to retrieve the current upstream copy.
