# FortiGate configuration backups

## Convention

| Pattern | Committed | Content |
|---|---|---|
| `*.sanitized.conf` | Yes | Full configuration with secrets redacted |
| `*.conf.full` | **No** (gitignored) | Raw export from the device |

## Why

A raw FortiGate export contains, in cleartext-recoverable form:

- `set password ENC <hash>` — administrator credentials
- `set private-key "-----BEGIN ENCRYPTED PRIVATE KEY-----"` — certificate private keys
- PSK secrets for any configured VPN tunnel

FortiOS `ENC` encoding is not a safe one-way hash; treat those values as
credentials, not as digests. Never commit a raw export to a repository that is
public or shared.

## Producing a sanitized copy

Redact, at minimum: every `set password` / `passwd` / `psksecret` / `secret` /
`key` value, every PEM block (`private-key`, `certificate`, `ca`), and the
appliance serial number where present — the FortiGate `maintainer` recovery
account derives its password from the serial.

Verify before committing:

```bash
grep -nEi "ENC [A-Za-z0-9+/=]{20,}|BEGIN .*PRIVATE KEY" *.sanitized.conf
```

No output means clean.
