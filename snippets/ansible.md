## Ansible Snippets

Copy-paste material for both command-line usage and task blocks.

---

### Command-line: connectivity and inventory

```bash
# Ping all hosts in an inventory
ansible all -i inventories/local/hosts.ini -m ping

# Ping a single group
ansible webservers -i inventories/local/hosts.ini -m ping

# Ping a single host
ansible web01.example.com -i inventories/local/hosts.ini -m ping

# List all hosts Ansible sees in the inventory
ansible-inventory -i inventories/local/hosts.ini --list

# Show inventory as a tree
ansible-inventory -i inventories/local/hosts.ini --graph

# Show all vars Ansible has for a specific host
ansible-inventory -i inventories/local/hosts.ini --host web01.example.com
```

---

### Command-line: ad-hoc commands

```bash
# Run a shell command on all hosts
ansible all -i inventories/local/hosts.ini -m shell -a 'uptime'

# Check disk usage on a group
ansible webservers -i inventories/local/hosts.ini -m shell -a 'df -h /'

# Check which kernel is running everywhere
ansible all -i inventories/local/hosts.ini -m shell -a 'uname -r'

# Check a service status
ansible webservers -i inventories/local/hosts.ini -m shell -a 'systemctl is-active nginx'

# Install a package on the fly
ansible webservers -i inventories/local/hosts.ini -m apt -a 'name=curl state=present' --become

# Fetch a file from a remote host
ansible web01.example.com -i inventories/local/hosts.ini -m fetch \
  -a 'src=/etc/os-release dest=/tmp/fetched/ flat=yes'
```

---

### Command-line: playbook execution patterns

```bash
# Always dry-run first — no changes, show what would change
ansible-playbook -i inventories/local/hosts.ini playbooks/system/harden.yml --check --diff

# Real run scoped to one group
ansible-playbook -i inventories/local/hosts.ini playbooks/system/harden.yml -l webservers

# Real run scoped to one host
ansible-playbook -i inventories/local/hosts.ini playbooks/system/harden.yml -l web01.example.com

# Run only tasks tagged 'packages'
ansible-playbook -i inventories/local/hosts.ini playbooks/system/harden.yml --tags packages

# Skip slow tasks
ansible-playbook -i inventories/local/hosts.ini playbooks/system/harden.yml --skip-tags slow

# Pass a variable at runtime
ansible-playbook -i inventories/local/hosts.ini playbooks/deploy.yml -e "version=1.4.2"

# Step through tasks interactively (confirm each one)
ansible-playbook -i inventories/local/hosts.ini playbooks/system/harden.yml --step

# List tasks without running them
ansible-playbook -i inventories/local/hosts.ini playbooks/system/harden.yml --list-tasks

# Retry only the hosts that failed in the last run
ansible-playbook -i inventories/local/hosts.ini playbooks/system/harden.yml -l @harden.retry
```

---

### Command-line: vault

```bash
# Create and encrypt a new vault file
ansible-vault create group_vars/all/vault.yml

# Encrypt an existing file
ansible-vault encrypt group_vars/all/vault.yml

# Edit an encrypted file
ansible-vault edit group_vars/all/vault.yml

# View without editing
ansible-vault view group_vars/all/vault.yml

# Encrypt a single string to paste into a vars file
ansible-vault encrypt_string 'mysecret' --name 'vault_db_password'

# Run a playbook and prompt for vault password
ansible-playbook -i inventories/local/hosts.ini playbooks/deploy.yml --ask-vault-pass

# Run with a vault password file (add .vault_pass to .gitignore)
ansible-playbook -i inventories/local/hosts.ini playbooks/deploy.yml --vault-password-file .vault_pass
```

---

### Command-line: facts

```bash
# Dump all facts for a host
ansible web01.example.com -i inventories/local/hosts.ini -m setup

# Filter facts by prefix
ansible web01.example.com -i inventories/local/hosts.ini -m setup -a 'filter=ansible_distribution*'

# Show memory facts only
ansible web01.example.com -i inventories/local/hosts.ini -m setup -a 'filter=ansible_memory_mb'

# Show network interface facts
ansible web01.example.com -i inventories/local/hosts.ini -m setup -a 'filter=ansible_interfaces'
```

---

### Task blocks: Package management

```yaml
# Install a package
- name: Install curl
  ansible.builtin.apt:
    name: curl
    state: present
    update_cache: yes
  become: true

# Install multiple packages
- name: Install base packages
  ansible.builtin.apt:
    name:
      - curl
      - vim
      - htop
      - unzip
    state: present
    update_cache: yes
  become: true

# Remove a package
- name: Remove telnet
  ansible.builtin.apt:
    name: telnet
    state: absent
  become: true

# Upgrade all packages
- name: Full system upgrade
  ansible.builtin.apt:
    upgrade: dist
    update_cache: yes
  become: true
```

---

### Task blocks: Service management

```yaml
# Ensure a service is running and enabled at boot
- name: Enable and start nginx
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
  become: true

# Restart a service
- name: Restart sshd
  ansible.builtin.service:
    name: sshd
    state: restarted
  become: true

# Stop and disable a service
- name: Disable and stop avahi-daemon
  ansible.builtin.service:
    name: avahi-daemon
    state: stopped
    enabled: false
  become: true
```

---

### Task blocks: File and template operations

```yaml
# Copy a file to remote hosts
- name: Deploy motd
  ansible.builtin.copy:
    src: files/motd
    dest: /etc/motd
    owner: root
    group: root
    mode: '0644'
  become: true

# Render a Jinja2 template
- name: Deploy sshd_config
  ansible.builtin.template:
    src: templates/sshd_config.j2
    dest: /etc/ssh/sshd_config
    owner: root
    group: root
    mode: '0600'
    validate: /usr/sbin/sshd -t -f %s
  become: true
  notify: Restart sshd

# Ensure a directory exists
- name: Create app directory
  ansible.builtin.file:
    path: /opt/myapp
    state: directory
    owner: deploy
    group: deploy
    mode: '0755'
  become: true

# Set a single line in a file (idempotent)
- name: Set vm.swappiness
  ansible.builtin.lineinfile:
    path: /etc/sysctl.conf
    regexp: '^vm.swappiness'
    line: 'vm.swappiness=10'
  become: true

# Remove a line from a file
- name: Remove old repo entry
  ansible.builtin.lineinfile:
    path: /etc/apt/sources.list
    regexp: 'old-repo.example.com'
    state: absent
  become: true
```

---

### Task blocks: User management

```yaml
# Create a system user
- name: Create deploy user
  ansible.builtin.user:
    name: deploy
    system: true
    shell: /bin/bash
    create_home: true
    home: /home/deploy
  become: true

# Add SSH authorized key
- name: Add deploy SSH key
  ansible.posix.authorized_key:
    user: deploy
    state: present
    key: "{{ lookup('file', 'files/deploy.pub') }}"
  become: true

# Add user to a group
- name: Add deploy to sudo group
  ansible.builtin.user:
    name: deploy
    groups: sudo
    append: true
  become: true
```

---

### Task blocks: Vault variable usage

```yaml
# Reference a vaulted variable in a task.
# The variable is defined in group_vars/all/vault.yml (ansible-vault encrypted)
# and referenced via a plain wrapper in group_vars/all/vars.yml.
#
# group_vars/all/vault.yml (encrypted):
#   vault_db_password: "supersecret"
#
# group_vars/all/vars.yml (plain):
#   db_password: "{{ vault_db_password }}"

- name: Write database config
  ansible.builtin.template:
    src: templates/db.conf.j2
    dest: /etc/myapp/db.conf
    mode: '0640'
    owner: root
    group: myapp
  become: true
  # In the template: password={{ db_password }}
```

---

### Task blocks: Conditionals

```yaml
# Run only on Debian/Ubuntu
- name: Install apt-transport-https
  ansible.builtin.apt:
    name: apt-transport-https
    state: present
  become: true
  when: ansible_os_family == "Debian"

# Run only on a specific major version
- name: Apply Ubuntu 22 workaround
  ansible.builtin.shell: some-fix-command
  become: true
  when: ansible_distribution_major_version == "22"

# Skip if a variable is not defined
- name: Configure proxy
  ansible.builtin.lineinfile:
    path: /etc/environment
    line: "http_proxy={{ proxy_url }}"
  when: proxy_url is defined
```

---

### Task blocks: Loops

```yaml
# Loop over a list
- name: Create multiple directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /opt/myapp/logs
    - /opt/myapp/tmp
    - /opt/myapp/config

# Loop over a list of dicts
- name: Create users
  ansible.builtin.user:
    name: "{{ item.name }}"
    shell: "{{ item.shell }}"
  loop:
    - { name: alice, shell: /bin/bash }
    - { name: bob,   shell: /bin/sh }
  become: true
```

---

### Task blocks: Handlers

```yaml
# Handlers are defined at the play level and triggered by notify.
# They run once at the end of the play, even if notified multiple times.

tasks:
  - name: Deploy nginx config
    ansible.builtin.template:
      src: templates/nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    become: true
    notify: Reload nginx

handlers:
  - name: Reload nginx
    ansible.builtin.service:
      name: nginx
      state: reloaded
    become: true
```

---

### Task blocks: Blocks and error handling

```yaml
# Group tasks and handle errors together
- name: Deploy application
  block:
    - name: Copy binary
      ansible.builtin.copy:
        src: files/myapp
        dest: /usr/local/bin/myapp
        mode: '0755'

    - name: Start service
      ansible.builtin.service:
        name: myapp
        state: started

  rescue:
    - name: Notify on failure
      ansible.builtin.debug:
        msg: "Deployment failed on {{ inventory_hostname }}"

  always:
    - name: Clean up temp files
      ansible.builtin.file:
        path: /tmp/myapp-deploy
        state: absent

  become: true
```

---

### Task blocks: Gathering and using facts

```yaml
# Use a fact in a task
- name: Print OS info
  ansible.builtin.debug:
    msg: "{{ ansible_distribution }} {{ ansible_distribution_version }}"

# Use the primary IPv4 address
- name: Print host IP
  ansible.builtin.debug:
    msg: "{{ ansible_default_ipv4.address }}"

# Disable fact gathering for a fast play (e.g. ad-hoc style)
- hosts: webservers
  gather_facts: false
  tasks:
    - name: Ping
      ansible.builtin.ping:
```

---

### Task blocks: Tags

```yaml
# Tag individual tasks to allow selective runs:
#   ansible-playbook playbook.yml --tags hardening
#   ansible-playbook playbook.yml --skip-tags slow

- name: Set sysctl hardening values
  ansible.builtin.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
    reload: yes
  loop:
    - { key: net.ipv4.tcp_syncookies, value: '1' }
    - { key: net.ipv4.conf.all.rp_filter, value: '1' }
  become: true
  tags: hardening
```
