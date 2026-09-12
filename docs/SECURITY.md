# Security model

Do not store credentials or private VPN material in Git.

The LuCI backend uses an allowlist of supported commands and validates user-controlled profile names and modes before invoking the runtime. It does not expose an arbitrary shell command endpoint.

Release archives can be verified with SHA256. Cryptographic signatures should be added when a signing key and release policy are established.
