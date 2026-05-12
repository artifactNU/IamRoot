# Ansible Cheat Sheet

Practical reference for ad-hoc commands, playbook execution, inventory, vault, and debugging.

---

## Table of Contents

- [Basics](#basics)
- [Inventory](#inventory)
- [Ad-hoc Commands](#ad-hoc-commands)
- [Playbook Execution](#playbook-execution)
- [Vault](#vault)
- [Variables and Facts](#variables-and-facts)
- [Roles and Galaxy](#roles-and-galaxy)
- [Debugging](#debugging)
- [Useful One-Liners](#useful-one-liners)

---

## Basics

- Show version and config file in use
  - `ansible --version`

- Show active configuration
  - `ansible-config dump --only-changed`

- List all configured hosts
  - `ansible-inventory -i inventories/local/hosts.ini --list`

- Show inventory as a graph
  - `ansible-inventory -i inventories/local/hosts.ini --graph`

- Ping all hosts (connectivity check)
  - `ansible all -i inventories/local/hosts.ini -m ping`

---

## Inventory

- Specify inventory file
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml`

- Specify inventory directory (loads all files in it)
  - `ansible-playbook -i inventories/local/ playbook.yml`

- List hosts matched by a pattern
  - `ansible webservers -i inventories/local/hosts.ini --list-hosts`

- Target a single host
  - `ansible-playbook -i inventories/local/hosts.ini -l web01.example.com playbook.yml`

- Target a group
  - `ansible-playbook -i inventories/local/hosts.ini -l webservers playbook.yml`

- Target multiple groups
  - `ansible-playbook -i inventories/local/hosts.ini -l 'webservers:dbservers' playbook.yml`

---

## Ad-hoc Commands

- Run a shell command on all hosts
  - `ansible all -i inventories/local/hosts.ini -m shell -a 'uptime'`

- Copy a file to hosts
  - `ansible webservers -i inventories/local/hosts.ini -m copy -a 'src=/tmp/motd dest=/etc/motd'`

- Install a package
  - `ansible webservers -i inventories/local/hosts.ini -m apt -a 'name=curl state=present' --become`

- Restart a service
  - `ansible webservers -i inventories/local/hosts.ini -m service -a 'name=nginx state=restarted' --become`

- Fetch a file from a host
  - `ansible web01 -i inventories/local/hosts.ini -m fetch -a 'src=/etc/os-release dest=/tmp/fetched/'`

- Run with sudo
  - `ansible all -i inventories/local/hosts.ini -m ping --become`

- Run as a different user
  - `ansible all -i inventories/local/hosts.ini -m ping --become --become-user=root`

---

## Playbook Execution

- Dry run — no changes, show what would change
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --check --diff`

- Real run with verbose output
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml -v`

- Even more verbose (shows module args and return values)
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml -vvv`

- Limit to specific hosts or groups
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml -l webservers`

- Run only tasks with a specific tag
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --tags hardening`

- Skip tasks with a specific tag
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --skip-tags slow`

- List tasks without running them
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --list-tasks`

- List hosts the playbook would target
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --list-hosts`

- Step through tasks interactively
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --step`

- Start at a specific task
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --start-at-task 'Enable firewall'`

- Pass extra variables
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml -e "version=1.2.3 env=staging"`

- Retry failed hosts from last run
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml -l @playbook.retry`

---

## Vault

- Encrypt a new file
  - `ansible-vault encrypt group_vars/all/vault.yml`

- Decrypt a file (in place)
  - `ansible-vault decrypt group_vars/all/vault.yml`

- Edit an encrypted file
  - `ansible-vault edit group_vars/all/vault.yml`

- View an encrypted file without editing
  - `ansible-vault view group_vars/all/vault.yml`

- Encrypt a single string (for embedding in a playbook)
  - `ansible-vault encrypt_string 'mysecretvalue' --name 'vault_db_password'`

- Re-key a vault file (change the password)
  - `ansible-vault rekey group_vars/all/vault.yml`

- Run a playbook with vault (prompted password)
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --ask-vault-pass`

- Run a playbook with vault (password file — keep this in .gitignore)
  - `ansible-playbook -i inventories/local/hosts.ini playbook.yml --vault-password-file .vault_pass`

---

## Variables and Facts

- Show all facts for a host
  - `ansible web01 -i inventories/local/hosts.ini -m setup`

- Filter facts by prefix
  - `ansible web01 -i inventories/local/hosts.ini -m setup -a 'filter=ansible_distribution*'`

- Show memory facts
  - `ansible web01 -i inventories/local/hosts.ini -m setup -a 'filter=ansible_memory_mb'`

- Show network facts
  - `ansible web01 -i inventories/local/hosts.ini -m setup -a 'filter=ansible_interfaces'`

- Dump all host and group vars
  - `ansible-inventory -i inventories/local/hosts.ini --host web01`

---

## Roles and Galaxy

- Create a new role scaffold
  - `ansible-galaxy role init roles/myrole`

- Install a role from Galaxy
  - `ansible-galaxy role install geerlingguy.nginx`

- Install roles from a requirements file
  - `ansible-galaxy install -r requirements.yml`

- List installed roles
  - `ansible-galaxy role list`

- Install a collection
  - `ansible-galaxy collection install community.general`

---

## Debugging

- Check playbook syntax without running
  - `ansible-playbook playbook.yml --syntax-check`

- Print a variable mid-play (add to tasks)
  - `- debug: var=ansible_hostname`

- Print a message mid-play
  - `- debug: msg="Value is {{ my_var }}"`

- Pause and prompt during a run
  - `- pause: prompt="Continue?"`

- Show host connection info
  - `ansible web01 -i inventories/local/hosts.ini -m debug -a 'var=hostvars[inventory_hostname]'`

- Test a Jinja2 expression against a host
  - `ansible web01 -i inventories/local/hosts.ini -m debug -a "msg={{ ansible_distribution + ' ' + ansible_distribution_version }}"`

---

## Useful One-Liners

- Check disk usage on all hosts
  - `ansible all -i inventories/local/hosts.ini -m shell -a 'df -h /'`

- Check which OS version is running on all hosts
  - `ansible all -i inventories/local/hosts.ini -m shell -a 'lsb_release -d'`

- Check uptime on all hosts
  - `ansible all -i inventories/local/hosts.ini -m shell -a 'uptime -p'`

- Show running kernel version
  - `ansible all -i inventories/local/hosts.ini -m shell -a 'uname -r'`

- List listening ports (requires ss)
  - `ansible all -i inventories/local/hosts.ini -m shell -a 'ss -tlnp' --become`

- Reboot all hosts and wait for them to come back
  - `ansible all -i inventories/local/hosts.ini -m reboot --become`

- Run a raw command (no Python required on target)
  - `ansible all -i inventories/local/hosts.ini -m raw -a 'cat /etc/hostname'`
