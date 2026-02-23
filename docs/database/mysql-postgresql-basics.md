# MySQL and PostgreSQL Administration Basics

## Overview

MySQL and PostgreSQL are the most common open-source relational databases in production environments. While they differ internally, operational tasks are similar: managing users, taking backups, monitoring health, and responding to problems.

This guide covers **sysadmin tasks**—how to keep the database running, not how to optimize queries or design schemas.

---

## Architecture Overview

Both databases follow a similar architecture:

**Server Process**  
The background daemon (mysqld for MySQL, postgres for PostgreSQL) that manages data files, handles client connections, and executes queries.

**Data Files**  
Physical files on disk storing tables, indexes, and transaction logs. Location varies:
- MySQL typically uses `/var/lib/mysql/`
- PostgreSQL typically uses `/var/lib/postgresql/data/`

**Client Connections**  
The database accepts connections on a TCP port (3306 for MySQL, 5432 for PostgreSQL) or Unix socket. The server manages connection resources and queries.

**Transaction Log**  
Both databases maintain transaction logs (binary log in MySQL, WAL—write-ahead log—in PostgreSQL) for crash recovery and replication.

**Buffer Pool**  
In-memory cache of frequently accessed data. This is where most query performance gains come from. Larger buffer pools generally perform better.

---

## Installation and Initial Setup

### MySQL

**Installation** (Debian/Ubuntu):
```bash
sudo apt update
sudo apt install mysql-server
```

**Verify installation**:
```bash
sudo systemctl status mysql
mysql --version
sudo mysql -u root -p  # Connect and check
```

**Initial security** (important):
```bash
sudo mysql_secure_installation  # Removes test database, sets root password
```

### PostgreSQL

**Installation** (Debian/Ubuntu):
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

**Verify installation**:
```bash
sudo systemctl status postgresql
psql --version
sudo -u postgres psql  # Connect as postgres user
```

### Basic Configuration

Both databases have configuration files that control behavior:

**MySQL**: `/etc/mysql/mysql.conf.d/mysqld.cnf` (or `/etc/my.cnf`)  
**PostgreSQL**: `/var/lib/postgresql/<version>/main/postgresql.conf`

Common settings:

```ini
# MySQL
max_connections = 100           # Max simultaneous connections
innodb_buffer_pool_size = 2G    # Memory for caching (important!)
bind-address = 127.0.0.1        # Only listen on localhost
```

```conf
# PostgreSQL
max_connections = 100
shared_buffers = 256MB          # Similar to MySQL buffer pool
effective_cache_size = 1GB
listen_addresses = 'localhost'  # Only listen on localhost
```

After changing configuration, restart the database:
```bash
sudo systemctl restart mysql       # MySQL
sudo systemctl restart postgresql  # PostgreSQL
```

---

## User and Privilege Management

Both databases separate **database users** from **system users**. The database user is who connects and what permissions they have.

### MySQL User Management

**Create a user**:
```bash
sudo mysql -u root -p
mysql> CREATE USER 'appuser'@'localhost' IDENTIFIED BY 'password123';
```

The `@'localhost'` part restricts where the user can connect from. Use `@'%'` for any host (dangerous).

**Grant privileges**:
```bash
mysql> GRANT SELECT, INSERT, UPDATE ON myapp.* TO 'appuser'@'localhost';
mysql> FLUSH PRIVILEGES;  # Make changes take effect
```

**Check current privileges**:
```bash
mysql> SHOW GRANTS FOR 'appuser'@'localhost';
```

**Remove a user**:
```bash
mysql> DROP USER 'appuser'@'localhost';
```

**Change root password** (if needed):
```bash
sudo mysqladmin -u root -p password newpassword
```

### PostgreSQL User Management

**Create a user**:
```bash
sudo -u postgres createuser appuser
sudo -u postgres psql -c "ALTER USER appuser WITH PASSWORD 'password123';"
```

**Grant privileges**:
```bash
sudo -u postgres psql
postgres=# GRANT CONNECT ON DATABASE myapp TO appuser;
postgres=# GRANT USAGE ON SCHEMA public TO appuser;
postgres=# GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO appuser;
```

**Check privileges**:
```bash
postgres=# \du  # List users and their attributes
postgres=# SELECT * FROM information_schema.role_table_grants WHERE grantee='appuser';
```

**Remove a user**:
```bash
sudo -u postgres dropuser appuser
```

### Principle of Least Privilege

Always grant the minimum privileges needed:

- Never give the root/postgres user to applications
- Use separate users for different applications
- Grant SELECT only if the app only reads
- Restrict network connections to specific hosts

---

## Backup and Recovery

Backups are the only thing standing between data loss and disaster. Regular backups are mandatory.

### MySQL Backups

**Logical backup** (dump the data):
```bash
mysqldump -u root -p --all-databases > backup.sql  # All databases
mysqldump -u root -p myapp > myapp_backup.sql      # One database
```

This creates a text file with SQL statements. Advantages: portable, human-readable. Disadvantages: slow for large databases.

**Point-in-time recovery** (using binary logs):
```bash
# First, enable binary logging in /etc/mysql/mysql.conf.d/mysqld.cnf:
# log_bin = /var/log/mysql/mysql-bin.log
# Then restart MySQL

mysql-binlog /var/log/mysql/mysql-bin.000001 > recovery.sql
```

**Backup script example**:
```bash
#!/bin/bash
BACKUP_DIR="/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
mysqldump -u root -p --all-databases | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete
```

### PostgreSQL Backups

**Logical backup** (pg_dump):
```bash
sudo -u postgres pg_dump myapp > myapp_backup.sql    # One database
sudo -u postgres pg_dumpall > full_backup.sql        # All databases
```

**Compressed backup** (more common):
```bash
sudo -u postgres pg_dump -Fc myapp > myapp_backup.dump
```

**Restore from backup**:
```bash
sudo -u postgres psql myapp < myapp_backup.sql       # From SQL dump
sudo -u postgres pg_restore -d myapp myapp_backup.dump  # From .dump file
```

**Point-in-time recovery** (using WAL):
Requires WAL archiving to be configured. More complex than MySQL but very powerful.

### Backup Best Practices

- Automate backups with cron jobs (run daily)
- Store backups off-site or on separate storage
- Test recovery procedures regularly (not just backups)
- Monitor backup completion (alert if a backup fails)
- Include the database version in the backup metadata

Example cron entry:
```bash
0 2 * * * /usr/local/bin/backup-mysql.sh  # Run at 2 AM daily
```

---

## Monitoring and Health Checks

### MySQL Monitoring

**Check server status**:
```bash
sudo systemctl status mysql
sudo mysql -u root -p -e "STATUS;"  # Connection info, uptime, queries
```

**Check database size**:
```bash
mysql -u root -p -e "SELECT table_schema AS 'Database', 
  ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES GROUP BY table_schema;"
```

**Check active connections**:
```bash
mysql -u root -p -e "SHOW PROCESSLIST;"  # Currently running queries
mysql -u root -p -e "SHOW STATUS LIKE 'Threads_connected';"
```

**Check replication status** (if replicating):
```bash
mysql -u root -p -e "SHOW SLAVE STATUS\G"  # Check lag, errors
```

**Check binary log status**:
```bash
mysql -u root -p -e "SHOW BINARY LOGS;"  # List binary logs
mysql -u root -p -e "SHOW MASTER STATUS;"  # Current position
```

### PostgreSQL Monitoring

**Check server status**:
```bash
sudo systemctl status postgresql
sudo -u postgres pg_isready  # Quick connectivity check
```

**Check database size**:
```bash
sudo -u postgres psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database ORDER BY pg_database_size(datname) DESC;"
```

**Check active connections**:
```bash
sudo -u postgres psql -c "SELECT usename, application_name, state 
FROM pg_stat_activity WHERE state != 'idle';"
```

**Check WAL and replication**:
```bash
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"  # Replication status
```

**Check table sizes**:
```bash
sudo -u postgres psql myapp -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

### Setting Up Monitoring Alerts

For production systems, use monitoring tools:

```bash
# Simple script to check if database is responding
#!/bin/bash
RESPONSE=$(mysqladmin -u root -p -h localhost ping 2>&1)
if [[ ! "$RESPONSE" == *"mysqld is alive"* ]]; then
  echo "Database is down!" | mail -s "Alert: Database Down" admin@example.com
fi
```

Add to cron (every 5 minutes):
```bash
*/5 * * * * /usr/local/bin/check-mysql-health.sh
```

---

## Common Failure Modes and Diagnostics

### "Too Many Connections"

**Symptom**: Applications cannot connect, error says "Too many connections"

**Diagnosis**:
```bash
mysql -u root -p -e "SHOW PROCESSLIST;"  # See who is connected
mysql -u root -p -e "SHOW VARIABLES LIKE 'max_connections';"
```

**Solution**:
- Increase `max_connections` in config, then restart
- Kill idle connections: `KILL <id>;` (careful!)
- Restart the database to close all connections: `sudo systemctl restart mysql`

### Database Will Not Start

**Diagnosis**:
```bash
sudo systemctl status mysql        # Check error message
sudo tail -50 /var/log/mysql/error.log  # Read error log
```

**Common causes**:
- Corrupted data files (rare but possible after crash)
- Permission issues on `/var/lib/mysql`
- Incompatible configuration after upgrade

**Recovery**:
```bash
# MySQL crash recovery
sudo service mysql start  # Often auto-recovers from InnoDB crash
sudo mysqlcheck -u root -p --all-databases  # Check for corruption
```

### Slow Queries or High CPU Usage

**Diagnosis**:
```bash
# See currently running queries
mysql -u root -p -e "SHOW PROCESSLIST;"

# Check slow query log (if enabled)
tail /var/log/mysql/slow.log
```

**Identify the problem query**:
```bash
# Look at the query
EXPLAIN <query>;  # Understand how MySQL executes it
SHOW CREATE TABLE <table>;  # Understand table structure
SHOW INDEX FROM <table>;  # See what indexes exist
```

**Temporary solution**:
- Kill the slow query: `KILL <id>;`
- Restart database if CPU is pegged

**Long-term solution**:
- Create missing indexes
- Optimize table structure
- Adjust buffer pool size
- Consider archiving old data

### Disk Space Running Out

**Diagnosis**:
```bash
df -h  # Check overall disk usage
mysql -u root -p -e "SELECT table_schema, 
  ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
FROM information_schema.TABLES GROUP BY table_schema;"  # Database sizes
```

**Solution**:
- Archive old data and delete it
- Clean up binary logs (if replication is not using them)
- Expand disk if needed

```bash
# Delete old binary logs (MySQL)
mysql -u root -p -e "PURGE BINARY LOGS BEFORE '2025-02-01';"
```

### Replication Lag or Failure

**Diagnosis** (MySQL slave):
```bash
mysql -u root -p -e "SHOW SLAVE STATUS\G"  # Check Seconds_Behind_Master
```

**Common causes**:
- Network latency
- Slow slave hardware
- Long-running queries on slave

**Recovery**:
```bash
# If replication is broken:
mysql> STOP SLAVE;
mysql> RESET SLAVE;
mysql> START SLAVE;
```

---

## Performance Tuning (Basics)

Most performance comes from a few key settings:

### MySQL Tuning

```ini
# Key settings in /etc/mysql/mysql.conf.d/mysqld.cnf

# Allocate based on available RAM (start with 50-80% of RAM)
innodb_buffer_pool_size = 8G

# Larger values are better (default is too small)
innodb_log_file_size = 512M

# Reduce disk seeks for writes
innodb_flush_log_at_trx_commit = 2  # (1 = safest, 2 = good balance)
```

### PostgreSQL Tuning

```conf
# Key settings in /var/lib/postgresql/<version>/main/postgresql.conf

# Allocate based on available RAM (typically 25% of RAM)
shared_buffers = 4GB

# Help planner make better decisions
effective_cache_size = 12GB
work_mem = 100MB
```

After tuning, **restart the database and monitor**:
```bash
sudo systemctl restart mysql
# Monitor performance for several hours
```

Do not over-tune. Start with the basics above and measure before making drastic changes.

---

## Maintenance Tasks

### Regular Tasks

**Daily**:
- Verify backups completed successfully
- Check disk space
- Monitor error logs for warnings

**Weekly**:
- Run database integrity checks
- Clean up old transaction logs
- Review connection patterns

**Monthly**:
- Review slow query log (if enabled)
- Check and analyze table sizes
- Test backup restoration procedure

### Example Maintenance Script

```bash
#!/bin/bash
# Weekly database maintenance

DATE=$(date +%Y-%m-%d)
LOG_FILE="/var/log/maintenance-$DATE.log"

echo "Starting database maintenance..." >> $LOG_FILE

# MySQL integrity check
mysqladmin -u root -p flush-logs >> $LOG_FILE 2>&1
mysqlcheck -u root -p --all-databases >> $LOG_FILE 2>&1

# Cleanup old binary logs
mysql -u root -p -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);" >> $LOG_FILE 2>&1

echo "Maintenance complete" >> $LOG_FILE
```

Add to cron:
```bash
0 3 * * 0 /usr/local/bin/db-maintenance.sh  # Run every Sunday at 3 AM
```

---

## Security Considerations

### Network Access

By default, only allow connections from localhost:

```ini
# MySQL
bind-address = 127.0.0.1  # Only localhost

# PostgreSQL
listen_addresses = 'localhost'  # Only localhost
```

If applications need remote access, use a firewall to restrict by IP:

```bash
sudo ufw allow from 10.0.1.5 to any port 3306  # Allow specific IP only
```

### Passwords

- Use strong passwords for all database users
- Do not embed passwords in plaintext in scripts
- Store passwords in `~/.my.cnf` (MySQL) or `~/.pgpass` (PostgreSQL) with restricted permissions

Example `~/.my.cnf`:
```ini
[client]
user=root
password=yourpassword
```

Set permissions:
```bash
chmod 600 ~/.my.cnf
```

### User Privileges

Never grant unnecessary privileges:
- `root` and `postgres` users should not be used by applications
- Create application-specific users with minimal permissions
- Audit who has access regularly

### Encryption

For production systems, consider:
- Encrypted connections to the database (SSL/TLS)
- Encrypted storage of data on disk
- Encrypted backups

These add complexity but are important for sensitive data.

---

## When to Call For Help

Database issues can escalate quickly. Know when to escalate:

- **Data integrity issues**: Corruption detected by integrity checks
- **Unrecoverable failure**: Database will not start
- **Replication issues**: Lag cannot be resolved and is growing
- **Performance mystery**: Database is slow but no obvious cause
- **Security incident**: Unauthorized access or data breach

Have a plan to contact database specialists before a crisis occurs.
