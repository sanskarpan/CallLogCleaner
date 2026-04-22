# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest (`main`) | ✅ |
| Older releases | ❌ — please update to the latest release |

---

## Reporting a Vulnerability

If you discover a security vulnerability, **do not open a public GitHub issue**. Instead, please report it privately:

1. Open a [GitHub Security Advisory](https://github.com/sanskarpan/CallLogCleaner/security/advisories/new) on this repository
2. Include a clear description of the vulnerability, steps to reproduce, and the potential impact
3. You will receive a response within 7 days
4. Once a fix is available, the advisory will be published with credit to the reporter (unless you prefer to remain anonymous)

---

## Scope

### In scope
- Vulnerabilities that could allow a malicious backup to execute arbitrary code when processed by the app
- Memory safety issues in the C-interop layer (`SQLite3`, `CommonCrypto`)
- Issues that could cause the app to write incorrect data back to a backup, silently corrupting it
- Information leakage (e.g. backup password or decrypted data written to disk in an insecure location)

### Out of scope
- Issues that require the attacker to already have full access to the user's Mac (if they have that, the backup is already accessible to them)
- Social engineering attacks
- Issues in Apple's backup format itself — report those to Apple Product Security

---

## Data Handling Guarantees

This section documents exactly what the app does with your data so you can make an informed decision about trusting it.

### What stays on your machine
- Your backup password is held **in memory only** for the duration of the decrypt/re-encrypt operation and is cleared immediately after. It is never written to disk, logged, or transmitted anywhere.
- Decrypted `CallHistory.storedata` bytes are written to `NSTemporaryDirectory()` during processing and deleted when the operation completes (or on next launch if a crash occurred).

### What the app does NOT do
- ❌ No network requests — the app has no network entitlements
- ❌ No analytics or telemetry
- ❌ No iCloud access
- ❌ No keychain access

### Backup safety
Before writing any modified file, the original encrypted file at the old hash location is left in place until the new file has been successfully written and `Manifest.db` updated. If the app crashes mid-operation:
- The original encrypted `CallHistory.storedata` file remains at the old hash path
- `Manifest.db` may point to the new (possibly incomplete) file
- The backup may be in an inconsistent state — **do not restore a backup that was being modified when the app crashed**. Re-run the operation from scratch or restore from a known-good backup.

### What you should do before using this app
1. Make a second copy of the backup folder at `~/Library/Application Support/MobileSync/Backup/{UDID}/` before making any modifications
2. Verify the restored backup is correct on a test device before relying on it

---

## Cryptographic Implementation Notes

For the full specification of the cryptographic operations, see [`docs/ENCRYPTION.md`](docs/ENCRYPTION.md).

In summary:
- All cryptography is performed by Apple's `CommonCrypto` system library — no third-party crypto code
- AES-256-CBC with a null IV is used (this matches Apple's backup format specification — the per-file key is single-use so IV reuse is not a concern)
- Two-stage PBKDF2 (SHA-256 then SHA-1) matches Apple's documented key derivation for backup keybags
- RFC 3394 AES Key Wrap is used exactly as specified for class key storage
