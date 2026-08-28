# FortiGate configuration backups

## Convention

| Pattern | Committed | Content |
|---|---|---|
| `fgt-prod-01.sanitized.conf` | Yes | Current configuration, secrets redacted |
| `*.conf.full` | **No** (gitignored) | Raw exports from the device, kept locally |
| `*.conf` | **No** (gitignored) | Any raw export, by default |

**One sanitized file, overwritten in place.** Timestamped copies are not kept:
each commit's diff shows what actually changed in the firewall configuration,
which is far more readable than comparing two near-identical 130 KB files.
Git history holds every previous state.

Raw exports keep their timestamped names locally and stay out of the
repository. They are the only copies that can actually restore the appliance —
a sanitized file cannot, because the redacted values are real configuration.

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
