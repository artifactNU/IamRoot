# ansible/

Ansible playbooks, roles, and supporting material for the IamRoot toolbox.

## Safety model

Real infrastructure details never live in this repo. The pattern is:

- `inventories/example/` — committed, fake hostnames and IPs only (RFC 5737 ranges)
- `inventories/local/` — gitignored, your real hosts go here
- Secrets use Ansible Vault; `.vault_pass` is gitignored

## Directory layout

| Path | Purpose |
|------|---------|
| `inventories/example/` | Template inventory to copy and adapt |
| `inventories/local/` | Your real inventory (gitignored) |
| `playbooks/` | Playbooks organised by domain |
| `roles/` | Reusable roles |
| `snippets/` | Short task blocks to copy into playbooks |

## Getting started

```bash
cp -r inventories/example inventories/local
# Edit inventories/local/hosts.ini with real hosts
ansible-playbook -i inventories/local/hosts.ini playbooks/system/ping.yml --check
```

## Conventions

- Always test with `--check --diff` before a real run
- Playbooks must be idempotent
- No hardcoded secrets — use `vault_` prefixed vars backed by Ansible Vault
