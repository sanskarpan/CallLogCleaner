# Encryption Pipeline Reference

This document is a precise technical reference for every cryptographic operation CallLogCleaner performs. It is intended for security researchers, auditors, and contributors who need to understand exactly how iPhone encrypted backup decryption works.

---

## Background: iTunes/Finder Encrypted Backups

When you enable "Encrypt local backup" in Finder (or iTunes), Apple encrypts every file in the backup using a per-file AES key. These per-file keys are themselves encrypted ("wrapped") using one of several "class keys", which are derived from your backup password. The result is that no file in the backup is readable without the correct password.

The cryptographic design is documented in Apple Platform Security:
https://support.apple.com/guide/security/backup-keybag-sec21f770d68/web

---

## Backup Directory Layout

```
~/Library/Application Support/MobileSync/Backup/{UDID}/
├── Info.plist           device name, model, iOS version, phone number
├── Manifest.plist       encryption metadata: BackupKeyBag, ManifestKey, IsEncrypted
├── Manifest.db          encrypted SQLite: file index (domain, relativePath, fileID, wrapped keys)
├── Status.plist         backup status
└── {xx}/               first 2 hex chars of file hash
    └── {hash}           encrypted file content
```

**File hash formula:**
```
fileID = lowercase_hex( SHA1( domain + "-" + relativePath ) )
```

For `CallHistory.storedata`:
```
fileID = SHA1("HomeDomain-Library/CallHistoryDB/CallHistory.storedata")
       = "2b2b0084a1bc3a5ac8c27afdf14afb42c61a19ca"
```

---

## Step 1: Parse BackupKeyBag

`Manifest.plist` contains a `BackupKeyBag` binary blob encoded as a Tag-Length-Value (TLV) stream:

```
┌──────────────────────┬──────────────────────┬──────────────────┐
│  Tag (4 bytes ASCII) │  Length (4 bytes BE) │  Value (N bytes) │
└──────────────────────┴──────────────────────┴──────────────────┘
```

**Top-level tags (read first):**

| Tag | Type | Purpose |
|-----|------|---------|
| `VERS` | UInt32 | KeyBag version (expect 3) |
| `TYPE` | UInt32 | KeyBag type (expect 3 = backup) |
| `DPSL` | Data | PBKDF2 stage-1 salt (32 bytes) |
| `DPIC` | UInt32 | PBKDF2 stage-1 iteration count |
| `SALT` | Data | PBKDF2 stage-2 salt (20 bytes) |
| `ITER` | UInt32 | PBKDF2 stage-2 iteration count |
| `UUID` | Data | KeyBag UUID (16 bytes) |
| `HMCK` | Data | HMAC check key |

**Per-class key tags (one set per protection class):**

| Tag | Type | Purpose |
|-----|------|---------|
| `CLS ` | UInt32 | Protection class number (1–12) |
| `WRAP` | UInt32 | Wrap type (3 = uses password) |
| `WPKY` | Data | Wrapped class key (40 bytes) |
| `KTYP` | UInt32 | Key type |
| `PBKY` | Data | Public key (Curve25519, optional) |

A new class-key group begins when the parser sees a second `CLS ` tag. This is a two-pass parse: the first pass extracts the top-level PBKDF2 parameters; the second extracts all class keys.

---

## Step 2: Two-Stage PBKDF2 Key Derivation

The Key Encryption Key (KEK) is derived from the backup password using two consecutive PBKDF2 passes, as required by Apple's keybag format.

### Stage 1 — PBKDF2-SHA256

```
input:  password (UTF-8 bytes)
salt:   DPSL  (32 bytes from BackupKeyBag)
iter:   DPIC  (typically 10,000,000 — intentionally slow)
keylen: 32 bytes
PRF:    HMAC-SHA256

output: intermediate_key (32 bytes)
```

Swift (CommonCrypto):
```swift
CCKeyDerivationPBKDF(
    CCPBKDFAlgorithm(kCCPBKDF2),
    passwordBytes, passwordLength,
    dpslBytes, dpslLength,
    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
    UInt32(dpic),
    &derivedKey, 32
)
```

### Stage 2 — PBKDF2-SHA1

```
input:  intermediate_key (from stage 1, used as the "password")
salt:   SALT  (20 bytes from BackupKeyBag)
iter:   ITER  (typically 1)
keylen: 32 bytes
PRF:    HMAC-SHA1

output: KEK (Key Encryption Key, 32 bytes)
```

Swift (CommonCrypto):
```swift
CCKeyDerivationPBKDF(
    CCPBKDFAlgorithm(kCCPBKDF2),
    intermediateKeyBytes, 32,
    saltBytes, saltLength,
    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
    UInt32(iter),
    &kek, 32
)
```

**Password validation:** After deriving the KEK, attempt to unwrap every class key using it. If at least one unwrap succeeds (returns without error), the password is correct. If none succeed, throw `BackupError.wrongPassword`.

---

## Step 3: RFC 3394 AES Key Unwrap

Each class key in the BackupKeyBag is wrapped using AES Key Wrap (RFC 3394):

```
wrapped_class_key (40 bytes) + KEK (32 bytes) → class_key (32 bytes)
```

Swift (CommonCrypto):
```swift
CCSymmetricKeyUnwrap(
    CCWrappingAlgorithm(kCCWRAPAES),
    CCrfc3394_iv, CCrfc3394_ivLen,
    kekBytes, 32,
    wrappedKeyBytes, 40,
    &unwrappedKey, &unwrappedKeyLen  // unwrappedKeyLen = 32
)
```

Returns `kCCSuccess` on correct unwrap. On wrong password, returns an error code (typically `kCCDecodeError`).

---

## Step 4: Decrypt Manifest.db

`Manifest.plist` contains a `ManifestKey` field — a binary blob structured as:

```
[4 bytes: ProtectionClass (big-endian UInt32)] [N bytes: wrapped_manifest_key]
```

Typically `ProtectionClass = 4` (Always).

```
wrapped_manifest_key (40 bytes) + class_keys[ProtectionClass] → manifest_file_key (32 bytes)
```

Then decrypt `Manifest.db`:
```
AES-256-CBC(key=manifest_file_key, iv=0x00 * 16, PKCS7) → Manifest.db plaintext (SQLite)
```

---

## Step 5: Query Manifest.db

`Manifest.db` is a standard SQLite database with a `Files` table:

```sql
CREATE TABLE Files (
    fileID        TEXT PRIMARY KEY,
    domain        TEXT,
    relativePath  TEXT,
    flags         INTEGER,
    file          BLOB      -- binary plist
);
```

To find `CallHistory.storedata`:
```sql
SELECT fileID, domain, flags, file
FROM Files
WHERE domain = 'HomeDomain'
  AND relativePath = 'Library/CallHistoryDB/CallHistory.storedata';
```

The `file` column is a binary plist. The keys of interest are:

| Key path | Meaning |
|----------|---------|
| `$objects[1].ProtectionClass` | Protection class number for this file |
| `$objects[1].EncryptionKey.$data` | Wrapped per-file key (40 bytes) |

The binary plist uses `NSKeyedArchiver` format. The `EncryptionKey` value has a 4-byte length prefix that must be stripped before passing to the key-unwrap step.

---

## Step 6: Decrypt CallHistory.storedata

```
wrapped_file_key (40 bytes) + class_keys[ProtectionClass] → file_key (32 bytes)
```
```
AES-256-CBC(key=file_key, iv=0x00 * 16, PKCS7) → CallHistory.storedata (SQLite)
```

The decrypted bytes are a valid Core Data SQLite database. Write them to a temp file and open with SQLite.

---

## Step 7: Modify CallHistory.storedata

```sql
-- Delete selected records
DELETE FROM ZCALLRECORD WHERE Z_PK IN (?, ?, ...);

-- Clean up related handle rows
DELETE FROM Z_2REMOTEPARTICIPANTHANDLES
WHERE Z_2CALLRECORDS IN (?, ?, ...);
```

All deletes are wrapped in `BEGIN IMMEDIATE` / `COMMIT` for atomicity.

**Core Data timestamp note:** `ZDATE` values in `ZCALLRECORD` use the Core Data reference date (January 1, 2001 UTC). To convert to Unix timestamp:
```
unix_timestamp = zdate + 978307200
```

---

## Step 8: Re-encrypt and Write Back

```
modified_sqlite_bytes
  └── AES-256-CBC(key=file_key, iv=0x00 * 16, PKCS7) → new_ciphertext
  └── new_fileID  (any unique hex string — a new random UUID works)
  └── Write new_ciphertext to {backup}/{new_fileID[0:2]}/{new_fileID}
```

Update `Manifest.db`:
```sql
UPDATE Files SET fileID = new_fileID WHERE fileID = old_fileID;
```

Re-encrypt the updated `Manifest.db`:
```
AES-256-CBC(key=manifest_file_key, iv=0x00 * 16, PKCS7) → new_manifest_ciphertext
```

Overwrite `{backup}/Manifest.db` with `new_manifest_ciphertext`.

Delete the old file at `{backup}/{old_fileID[0:2]}/{old_fileID}`.

---

## Cryptographic Constants Summary

| Constant | Value |
|----------|-------|
| Block cipher | AES-256 |
| Cipher mode | CBC |
| IV | 16 zero bytes (0x00 * 16) |
| Padding | PKCS7 |
| Key wrap | RFC 3394 AES Key Wrap |
| KDF | PBKDF2 (2-stage: SHA-256 then SHA-1) |
| File ID hash | SHA-1 |
| Class key size | 32 bytes (256 bits) |
| Wrapped class key size | 40 bytes (32 + 8-byte RFC 3394 IV) |

---

## Frameworks Used

All cryptographic operations use Apple's `CommonCrypto` system library, which is part of macOS and requires no additional packages:

```swift
import CommonCrypto
```

Key functions:
- `CCKeyDerivationPBKDF` — PBKDF2
- `CCSymmetricKeyUnwrap` / `CCSymmetricKeyWrap` — RFC 3394
- `CCCrypt` with `kCCAlgorithmAES`, `kCCOptionPKCS7Padding` — AES-CBC
- `CC_SHA1` — SHA-1

---

## Security Considerations

1. **Password handling:** The backup password is held in memory only for the duration of the decrypt/re-encrypt operation and cleared immediately after. It is never written to disk.
2. **Temp files:** Decrypted SQLite bytes are written to `NSTemporaryDirectory()` and deleted after use. If the app crashes mid-operation, these are left behind — they are in the system temp directory and subject to OS periodic cleanup.
3. **Original backup preservation:** Before writing any modified file, the original encrypted file is preserved. In the event of a failure during re-encryption, the backup remains in its original state.
4. **No network access:** The app has no network entitlements and makes no outbound connections.
