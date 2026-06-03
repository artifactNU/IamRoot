# Supermicro IPMI – Recover access by creating a new admin user from the host OS

This snippet documents how to create a new IPMI/BMC administrator account when no working IPMI credentials are available, but you have `sudo` access to the server OS.

**When to use this:**

* IPMI web UI is reachable but credentials are unknown
* No current staff know the IPMI password
* You have root/sudo access to the host OS
* `ipmitool` can communicate with the BMC

**Dependencies:**
ipmitool, sudo

---

## Confirm BMC access from the host

```
sudo ipmitool mc info
```

Expected: BMC information is returned (manufacturer, firmware version, etc.).

---

## List existing IPMI users

```
sudo ipmitool user list 1
```

Identify an unused user ID.

Example:

```
ID  Name
2   ADMIN
3
```

In this example, user ID `3` is available.

---

## Create a new administrator account

```
sudo ipmitool user set name 3 <username>
sudo ipmitool user enable 3
sudo ipmitool channel setaccess 1 3 link=on ipmi=on callin=on privilege=4
```

Set a password:

```
sudo ipmitool user set password 3
```

If interactive password prompts are not supported:

```
set +o history
sudo ipmitool user set password 3 '<strong-password>'
set -o history
history -w
```

---

## Verify account configuration

```
sudo ipmitool user list 1
sudo ipmitool channel getaccess 1 3
```

Expected:

```
User Name            : <username>
Link Authentication  : enabled
IPMI Messaging       : enabled
Privilege Level      : ADMINISTRATOR
Enable Status        : enabled
```

---

## Find the BMC IP address

```
sudo ipmitool lan print 1
```

Look for:

```
IP Address              : x.x.x.x
```

---

## Test authentication before using the web UI

```
read -s IPMIPASS
ipmitool -I lanplus -H <bmc-ip> -U <username> -P "$IPMIPASS" mc info
unset IPMIPASS
```

Expected: BMC information is returned.

---

## Optional: restart the BMC

If the account appears correct but the web UI rejects login:

```
sudo ipmitool mc reset cold
```

This restarts the BMC/IPMI controller only and does **not** reboot the server OS.

---

## Notes

* `privilege=4` corresponds to **ADMINISTRATOR**.
* On Supermicro systems, user IDs `2-10` are typically available for local accounts.
* Creating a new account is generally safer than modifying the existing `ADMIN` account.
* If `ipmitool mc info` fails, the OS cannot communicate with the BMC and this procedure will not work until that issue is resolved.
* Tested on Supermicro X11 (`X11DPG-QT`) with IPMI 2.0.
