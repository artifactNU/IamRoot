# inventories/

## Structure

```
inventories/
├── example/          # Committed — fake hosts, documents the expected layout
│   ├── hosts.ini
│   └── group_vars/
└── local/            # Gitignored — your real hosts go here
    ├── hosts.ini
    └── group_vars/
```

## Usage

Copy `example/` to `local/` and replace placeholder values:

```bash
cp -r inventories/example inventories/local
```

`local/` is in `.gitignore` and will never be committed.
