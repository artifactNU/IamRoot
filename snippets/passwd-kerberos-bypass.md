# Ubuntu – Local user password unlock when `passwd` prompts for Kerberos

This snippet documents how to set/unlock a **local** user password when `passwd <user>` is intercepted by PAM/Kerberos and keeps asking for **“Current Kerberos password”**, or when `passwd -u <user>` warns it would create a **passwordless account**.

**When this happens:**
- `passwd <user>` prompts for **Current Kerberos password**
- `passwd -u <user>` says unlocking would result in a **passwordless account**
- The user is actually **local** (exists in `/etc/passwd`)

**Dependencies:**
openssl, sudo

---

## Confirm the user is local

    grep '^<user>:' /etc/passwd
    getent passwd <user>

If `<user>` appears in `/etc/passwd`, it’s a local account.

---

## Set a local password + unlock (bypasses Kerberos/PAM)

    read -s -p "New local password for <user>: " PW; echo
    HASH=$(openssl passwd -6 -stdin <<<"$PW")
    unset PW
    sudo usermod -p "$HASH" <user>
    sudo usermod -U <user>
    sudo passwd -S <user>

Expected: `sudo passwd -S <user>` shows `P` (password set).

---

## Optional: verify `/etc/shadow` state

    sudo awk -F: '$1=="<user>"{print $1, $2}' /etc/shadow

- Starts with `$6$...` → password hash is set (OK)
- Starts with `!` or `*` → password authentication locked/disabled

---

## Notes

- This method **avoids** the Kerberos password-change flow, which is why it works even if you don’t know the Kerberos “current password”.
- If the account is **not** local (missing from `/etc/passwd` but present in `getent`), it’s likely directory/Kerberos-managed and you should use your identity provider tools instead (e.g., `kpasswd`, `kadmin`, FreeIPA, AD, etc.).
