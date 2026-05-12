# playbooks/

Playbooks organised by domain, mirroring the `scripts/` layout.

| Directory | Purpose |
|-----------|---------|
| `system/` | OS-level: packages, users, cron, backups |
| `security/` | Hardening, auditing, access control |
| `networking/` | Firewall, interfaces, DNS |

## Running a playbook

```bash
# Dry run first — always
ansible-playbook -i inventories/local/hosts.ini playbooks/system/ping.yml --check --diff

# Real run
ansible-playbook -i inventories/local/hosts.ini playbooks/system/ping.yml
```

## Conventions

- One playbook per task; keep them short and focused
- All playbooks must be idempotent
- Target a specific group, never `all` unless intentional
