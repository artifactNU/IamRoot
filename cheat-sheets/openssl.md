# OpenSSL Cheat Sheet

Practical reference for keys, certificates, TLS inspection, and cryptographic operations.
Covers the most common `openssl` subcommands used in daily sysadmin and security work.

---

## Table of Contents

- [Key Concepts](#key-concepts)
- [Generating Keys](#generating-keys)
- [Certificate Signing Requests (CSRs)](#certificate-signing-requests-csrs)
- [Self-Signed Certificates](#self-signed-certificates)
- [Inspecting Certificates & Keys](#inspecting-certificates--keys)
- [Verifying Certificates](#verifying-certificates)
- [Format Conversion](#format-conversion)
- [TLS Testing with s_client](#tls-testing-with-s_client)
- [Hashing & Digests](#hashing--digests)
- [Symmetric Encryption](#symmetric-encryption)
- [Random Data](#random-data)
- [Certificate Authority (CA) Operations](#certificate-authority-ca-operations)
- [OCSP & CRL Checking](#ocsp--crl-checking)
- [Troubleshooting](#troubleshooting)

---

## Key Concepts

| Term | Meaning |
|------|---------|
| PEM | Base64-encoded format, delimited by `-----BEGIN ...-----` headers |
| DER | Binary (ASN.1) encoding of the same data as PEM |
| CSR | Certificate Signing Request — carries a public key + subject info, signed by the private key |
| CA | Certificate Authority — entity that signs CSRs to produce trusted certificates |
| SAN | Subject Alternative Name — modern way to bind hostnames/IPs to a cert |
| PKCS#12 | Container format that bundles cert + key (and optionally chain) into one `.p12`/`.pfx` file |
| PKCS#8 | Standard format for storing private keys (encrypted or unencrypted) |

---

## Generating Keys

### RSA

```bash
# 4096-bit private key (unencrypted)
openssl genrsa -out private.key 4096

# 4096-bit private key encrypted with AES-256
openssl genrsa -aes256 -out private.key 4096
```

### ECDSA (preferred for modern use)

```bash
# List available curves
openssl ecparam -list_curves

# Generate P-256 (prime256v1) key
openssl ecparam -name prime256v1 -genkey -noout -out ec-private.key

# Generate P-384 key
openssl ecparam -name secp384r1 -genkey -noout -out ec-private.key
```

### Extract public key from private key

```bash
openssl rsa   -in private.key -pubout -out public.key   # RSA
openssl ec    -in ec-private.key -pubout -out ec-public.key  # EC
```

---

## Certificate Signing Requests (CSRs)

### Generate a CSR with an existing key

```bash
openssl req -new -key private.key -out request.csr
```

### Generate a new key and CSR in one step

```bash
openssl req -newkey rsa:4096 -keyout private.key -out request.csr
```

### Non-interactive CSR with subject inline

```bash
openssl req -new -key private.key -out request.csr \
  -subj "/C=US/ST=California/L=San Francisco/O=Acme Inc/CN=example.com"
```

### CSR with Subject Alternative Names (required for modern browsers)

Create a config file `san.cnf`:
```ini
[req]
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[req_distinguished_name]
CN = example.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = example.com
DNS.2 = www.example.com
IP.1  = 192.168.1.10
```

```bash
openssl req -new -key private.key -out request.csr -config san.cnf
```

### Inspect a CSR

```bash
openssl req -in request.csr -noout -text
openssl req -in request.csr -noout -subject
```

---

## Self-Signed Certificates

### Quick self-signed cert (90 days)

```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 90
```

### Self-signed with SANs

```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes -config san.cnf \
  -extensions v3_req
```

> Use `-nodes` to skip passphrase encryption on the key (useful for servers that start unattended).

### Sign a CSR with a local CA

```bash
openssl x509 -req -in request.csr \
  -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -out signed.crt -days 365 -sha256
```

---

## Inspecting Certificates & Keys

### Certificate details

```bash
openssl x509 -in cert.pem -noout -text       # full details
openssl x509 -in cert.pem -noout -subject    # subject only
openssl x509 -in cert.pem -noout -issuer     # issuer only
openssl x509 -in cert.pem -noout -dates      # validity window
openssl x509 -in cert.pem -noout -fingerprint -sha256  # fingerprint
openssl x509 -in cert.pem -noout -serial     # serial number
openssl x509 -in cert.pem -noout -ext subjectAltName   # SANs only
```

### Private key

```bash
openssl rsa -in private.key -check -noout    # verify RSA key integrity
openssl ec  -in ec-private.key -check -noout # verify EC key
openssl pkey -in private.key -noout -text    # generic key info (RSA or EC)
```

### Check that a cert and key match

```bash
# Both outputs must be identical
openssl x509 -noout -modulus -in cert.pem   | openssl md5
openssl rsa  -noout -modulus -in private.key | openssl md5
```

For EC keys:
```bash
openssl x509   -noout -pubkey -in cert.pem  | openssl md5
openssl ec     -pubout       -in ec.key     | openssl md5
```

### Inspect a DER-encoded certificate

```bash
openssl x509 -inform DER -in cert.der -noout -text
```

### View a certificate chain / bundle

```bash
openssl crl2pkcs7 -nocrl -certfile chain.pem | openssl pkcs7 -print_certs -noout -text
```

---

## Verifying Certificates

### Verify against a CA bundle

```bash
openssl verify -CAfile ca-bundle.pem cert.pem
# Output: cert.pem: OK
```

### Verify a full chain

```bash
openssl verify -CAfile root-ca.pem -untrusted intermediate.pem leaf.pem
```

### Check expiry quickly (exit 1 if expiring within N seconds)

```bash
openssl x509 -in cert.pem -checkend 0              # expired already?
openssl x509 -in cert.pem -checkend 2592000         # expires within 30 days?
```

---

## Format Conversion

| Source → Target | Command |
|----------------|---------|
| PEM → DER | `openssl x509 -in cert.pem -outform DER -out cert.der` |
| DER → PEM | `openssl x509 -in cert.der -inform DER -out cert.pem` |
| PEM key → PKCS#8 | `openssl pkcs8 -topk8 -in key.pem -out key.p8 -nocrypt` |
| PKCS#12 → PEM (cert + key) | `openssl pkcs12 -in bundle.p12 -out bundle.pem -nodes` |
| PKCS#12 → cert only | `openssl pkcs12 -in bundle.p12 -nokeys -out cert.pem` |
| PKCS#12 → key only | `openssl pkcs12 -in bundle.p12 -nocerts -nodes -out key.pem` |
| PEM cert + key → PKCS#12 | `openssl pkcs12 -export -in cert.pem -inkey key.pem -out bundle.p12` |
| PEM + chain → PKCS#12 | `openssl pkcs12 -export -in cert.pem -inkey key.pem -certfile chain.pem -out bundle.p12` |

---

## TLS Testing with s_client

### Basic connection

```bash
openssl s_client -connect example.com:443
```

### Show full certificate chain

```bash
openssl s_client -connect example.com:443 -showcerts </dev/null
```

### Check SNI (required for virtual hosting)

```bash
openssl s_client -connect example.com:443 -servername example.com </dev/null
```

### Check specific TLS version

```bash
openssl s_client -connect example.com:443 -tls1_2   # TLS 1.2
openssl s_client -connect example.com:443 -tls1_3   # TLS 1.3
```

### Extract the remote certificate

```bash
openssl s_client -connect example.com:443 </dev/null 2>/dev/null \
  | openssl x509 -noout -text
```

### Check expiry of a remote cert

```bash
openssl s_client -connect example.com:443 </dev/null 2>/dev/null \
  | openssl x509 -noout -dates
```

### Test SMTP with STARTTLS

```bash
openssl s_client -connect mail.example.com:587 -starttls smtp
```

### Test with a client certificate

```bash
openssl s_client -connect example.com:443 \
  -cert client.crt -key client.key
```

---

## Hashing & Digests

### Hash a file

```bash
openssl dgst -sha256 file.txt
openssl dgst -sha512 file.txt
openssl dgst -md5    file.txt    # avoid MD5 for security purposes
```

### HMAC

```bash
openssl dgst -sha256 -hmac "secretkey" file.txt
```

### Sign a file (requires private key)

```bash
openssl dgst -sha256 -sign private.key -out signature.bin file.txt
```

### Verify a signature

```bash
openssl dgst -sha256 -verify public.key -signature signature.bin file.txt
```

---

## Symmetric Encryption

> Prefer asymmetric or hybrid encryption for sensitive data. Symmetric `enc` is useful for quick file encryption.

```bash
# Encrypt a file with AES-256-CBC (prompts for passphrase)
openssl enc -aes-256-cbc -pbkdf2 -in plaintext.txt -out encrypted.bin

# Decrypt
openssl enc -d -aes-256-cbc -pbkdf2 -in encrypted.bin -out decrypted.txt

# Pass passphrase on command line (use only in secure scripts)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASSPHRASE" -in file.txt -out file.enc
```

> Always use `-pbkdf2` — it applies a proper key derivation function instead of the weak legacy default.

---

## Random Data

```bash
# 32 random bytes in hex (64 chars)
openssl rand -hex 32

# 32 random bytes in base64
openssl rand -base64 32

# Generate a random passphrase (32 bytes → ~43 printable chars)
openssl rand -base64 32 | tr -d '=+/' | cut -c1-32
```

---

## Certificate Authority (CA) Operations

### Minimal CA setup

```bash
mkdir -p ca/{certs,newcerts,private,crl}
chmod 700 ca/private
touch ca/index.txt
echo 1000 > ca/serial
```

### Generate CA key and self-signed root cert

```bash
openssl genrsa -aes256 -out ca/private/ca-key.pem 4096
chmod 400 ca/private/ca-key.pem

openssl req -new -x509 -days 3650 -key ca/private/ca-key.pem \
  -out ca/certs/ca-cert.pem \
  -subj "/C=US/O=My CA/CN=My Root CA"
```

### Sign a CSR with the CA

```bash
openssl ca -config openssl.cnf \
  -in request.csr -out signed.crt \
  -days 365 -notext -md sha256
```

### Revoke a certificate and update CRL

```bash
openssl ca -config openssl.cnf -revoke signed.crt
openssl ca -config openssl.cnf -gencrl -out ca/crl/ca.crl
```

---

## OCSP & CRL Checking

### Extract OCSP URL from a certificate

```bash
openssl x509 -in cert.pem -noout -text | grep -A2 "OCSP"
```

### Check OCSP status

```bash
openssl ocsp \
  -issuer intermediate.pem \
  -cert cert.pem \
  -url http://ocsp.example.com \
  -noverify -text
```

### Download and inspect a CRL

```bash
# Get CRL distribution URL
openssl x509 -in cert.pem -noout -text | grep -A2 "CRL Distribution"

# Download and inspect
curl -s http://crl.example.com/ca.crl | openssl crl -inform DER -text -noout
```

---

## Troubleshooting

**`unable to load Private Key`**
- Check PEM headers match (`-----BEGIN RSA PRIVATE KEY-----` vs `-----BEGIN PRIVATE KEY-----`)
- If PKCS#8, add `-inform PEM` or convert first

**`certificate verify failed`**
- The chain is incomplete — make sure intermediate certs are included
- Check that system time is correct (certs have validity windows)
- Verify against the correct CA bundle: `-CAfile /etc/ssl/certs/ca-certificates.crt`

**`bad decrypt` / passphrase error**
- Wrong passphrase on an encrypted key
- Key format mismatch — try `openssl pkey -in key.pem -noout -text` to diagnose

**Cert and key modulus mismatch**
```bash
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa  -noout -modulus -in key.pem  | openssl md5
# Outputs must match
```

**`no peer certificate available` from s_client**
- The server may require SNI: add `-servername <hostname>`

**Check which TLS versions a server accepts**
```bash
for v in tls1 tls1_1 tls1_2 tls1_3; do
  result=$(echo Q | openssl s_client -connect example.com:443 -$v 2>&1 | grep -E "Protocol|handshake")
  echo "$v: $result"
done
```
