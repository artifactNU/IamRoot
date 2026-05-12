# roles/

Reusable Ansible roles. Each role lives in its own subdirectory following the
standard Ansible role layout:

```
roles/
└── role-name/
    ├── tasks/main.yml
    ├── handlers/main.yml
    ├── defaults/main.yml   # overridable defaults
    ├── vars/main.yml       # non-overridable vars
    ├── templates/
    ├── files/
    └── meta/main.yml
```

Roles are shared across playbooks. Prefer roles over inline tasks once a
pattern is used in more than one playbook.
