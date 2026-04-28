# LAMP Stack

Apache + PHP + MariaDB. Copy, configure, and run.

## Quick start

```bash
cp .env.example .env        # edit credentials and versions
docker compose up -d --build
```

Open `http://localhost` — the status page confirms PHP and MariaDB are up.

Replace `www/index.php` with your application.

## Versions

Set in `.env`:

```
PHP_VERSION=8.3
MARIADB_VERSION=11
```

Any tag from the official [PHP image](https://hub.docker.com/_/php) and [MariaDB image](https://hub.docker.com/_/mariadb) works.

## Configuration

All config files are mounted as volumes — edit and restart, no rebuild needed.

| File | Controls |
|------|----------|
| `config/apache/000-default.conf` | Virtual host, document root, `.htaccess` support |
| `config/php/custom.ini` | Upload limits, memory, error reporting, opcache |
| `config/mariadb/custom.cnf` | Character set, buffer pool size |

## Common tasks

```bash
# Rebuild after changing PHP_VERSION or Dockerfile
docker compose up -d --build

# Open a MariaDB shell
docker compose exec mariadb mariadb -u app -p app

# Tail Apache logs
docker compose logs -f apache-php

# Stop and remove containers (data volume is preserved)
docker compose down

# Stop and remove containers AND wipe the database volume
docker compose down -v
```

## Adding PHP extensions

Edit the `Dockerfile` and add to the `docker-php-ext-install` line, then rebuild:

```dockerfile
RUN docker-php-ext-install pdo_mysql mysqli mbstring gd zip opcache intl
```

Some extensions need extra system packages first — check the [official PHP Docker docs](https://hub.docker.com/_/php#how-to-install-more-php-extensions).
