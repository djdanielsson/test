---
source-path: cookbooks/nginx-multisite
---



# Migration Plan: nginx-multisite

**TLDR**: Multi-site Nginx web server hosting 3 virtual hosts (test.cluster.local, ci.cluster.local, status.cluster.local) with SSL, fail2ban intrusion prevention, UFW firewall, and SSH hardening. Each site serves static content from /opt/server/{site} with HTTP-to-HTTPS redirect and self-signed SSL certificates.

## Service Type and Instances

**Service Type**: Web Server

**Configured Instances**:
- **test.cluster.local**: 
  - Location/Path: `/opt/server/test`
  - Port/Socket: 80 → redirects to 443
  - Key Config: SSL enabled (self-signed), log files at `/var/log/nginx/test.cluster.local_{access,error}.log`

- **ci.cluster.local**: 
  - Location/Path: `/opt/server/ci`
  - Port/Socket: 80 → redirects to 443
  - Key Config: SSL enabled (self-signed), log files at `/var/log/nginx/ci.cluster.local_{access,error}.log`

- **status.cluster.local**: 
  - Location/Path: `/opt/server/status`
  - Port/Socket: 80 → redirects to 443
  - Key Config: SSL enabled (self-signed), log files at `/var/log/nginx/status.cluster.local_{access,error}.log`

## File Structure

**MANDATORY: Preserve this section from the original plan.**

```
cookbooks/nginx-multisite/recipes/default.rb
cookbooks/nginx-multisite/recipes/security.rb
cookbooks/nginx-multisite/recipes/nginx.rb
cookbooks/nginx-multisite/recipes/ssl.rb
cookbooks/nginx-multisite/recipes/sites.rb
cookbooks/nginx-multisite/templates/default/fail2ban.jail.local.erb
cookbooks/nginx-multisite/templates/default/site.conf.erb
cookbooks/nginx-multisite/templates/default/sysctl-security.conf.erb
cookbooks/nginx-multisite/templates/default/nginx.conf.erb
cookbooks/nginx-multisite/templates/default/security.conf.erb
cookbooks/nginx-multisite/attributes/default.rb
```

## Module Explanation

The cookbook performs operations in this order:

**IMPORTANT: Use FULL paths from the File Structure section (e.g., `cookbooks/myapp/recipes/default.rb` not just `recipes/default.rb`)**

1. **security** (`cookbooks/nginx-multisite/recipes/security.rb`):
   - Installs security packages: fail2ban, ufw
   - Enables and starts fail2ban service
   - Deploys fail2ban jail configuration to `/etc/fail2ban/jail.local`
     - Template: `cookbooks/nginx-multisite/templates/default/fail2ban.jail.local.erb` → `/etc/fail2ban/jail.local`
     - Monitors SSH brute force attacks (maxretry=3, bantime=3600s)
     - Monitors nginx HTTP auth failures (maxretry=3, bantime=3600s)
     - Monitors nginx rate limiting violations (maxretry=10, bantime=3600s)
     - Monitors nginx bot search (maxretry=2, bantime=3600s)
   - Configures UFW firewall:
     - Sets default deny policy for all incoming traffic
     - Allows SSH (port 22), HTTP (port 80), HTTPS (port 443)
     - Enables UFW
   - Deploys sysctl security hardening to `/etc/sysctl.d/99-security.conf`
     - Template: `cookbooks/nginx-multisite/templates/default/sysctl-security.conf.erb` → `/etc/sysctl.d/99-security.conf`
     - Enables IP spoofing protection, ICMP redirect protection, SYN flood protection
     - Disables IPv6, source routing, and ICMP ping responses
   - Conditionally disables root SSH login (if `node['security']['ssh']['disable_root']` is true):
     - Modifies `/etc/ssh/sshd_config` PermitRootLogin to "no"
   - Conditionally disables SSH password authentication (if `node['security']['ssh']['password_auth']` is false):
     - Modifies `/etc/ssh/sshd_config` PasswordAuthentication to "no"
   - Resources: package (1), service (2), template (2), execute (8)

2. **nginx** (`cookbooks/nginx-multisite/recipes/nginx.rb`):
   - Installs nginx package
   - Deploys main nginx configuration to `/etc/nginx/nginx.conf`
     - Template: `cookbooks/nginx-multisite/templates/default/nginx.conf.erb` → `/etc/nginx/nginx.conf`
     - Sets user=www-data, worker_processes=auto, worker_connections=768
     - Enables gzip compression, sendfile, tcp_nopush, tcp_nodelay
     - Includes conf.d/*.conf and sites-enabled/*
   - Deploys security configuration to `/etc/nginx/conf.d/security.conf`
     - Template: `cookbooks/nginx-multisite/templates/default/security.conf.erb` → `/etc/nginx/conf.d/security.conf`
     - Hides nginx version (server_tokens off)
     - Configures rate limiting zones: login (10r/m), api (30r/m)
     - Sets client buffer limits (1K body, 1K header, 1K max body size)
     - Sets timeout values (10s for body, header, send)
     - Configures SSL session cache and protocols (TLSv1.2, TLSv1.3)
   - Enables and starts nginx service
   - Iterates over nginx.sites (3 items): test.cluster.local, ci.cluster.local, status.cluster.local
     - Creates document root directory for each site with owner=www-data, group=www-data, mode=0755
       - test.cluster.local: /opt/server/test
       - ci.cluster.local: /opt/server/ci
       - status.cluster.local: /opt/server/status
     - Deploys index.html static file from cookbook files:
       - test.cluster.local: test/index.html → /opt/server/test/index.html
       - ci.cluster.local: ci/index.html → /opt/server/ci/index.html
       - status.cluster.local: status/index.html → /opt/server/status/index.html
   - Resources: package (1), template (2), service (1), directory (3), cookbook_file (3)

3. **ssl** (`cookbooks/nginx-multisite/recipes/ssl.rb`):
   - Installs SSL packages: openssl, ca-certificates
   - Creates ssl-cert system group
   - Creates SSL certificate directory `/etc/ssl/certs` (owner=root, group=root, mode=0755)
   - Creates SSL private key directory `/etc/ssl/private` (owner=root, group=ssl-cert, mode=0710)
   - Iterates over nginx.sites (3 items) where ssl_enabled=true: test.cluster.local, ci.cluster.local, status.cluster.local
     - For each site, generates self-signed SSL certificate:
       - test.cluster.local:
         - Certificate: /etc/ssl/certs/test.cluster.local.crt
         - Private key: /etc/ssl/private/test.cluster.local.key
         - Command: openssl req -x509 -nodes -days 365 -newkey rsa:2048
         - Subject: /C=US/ST=Example/L=Example/O=Example Org/OU=IT/CN=test.cluster.local/emailAddress=admin@example.com
         - Key permissions: chmod 640, chown root:ssl-cert
       - ci.cluster.local:
         - Certificate: /etc/ssl/certs/ci.cluster.local.crt
         - Private key: /etc/ssl/private/ci.cluster.local.key
         - Command: openssl req -x509 -nodes -days 365 -newkey rsa:2048
         - Subject: /C=US/ST=Example/L=Example/O=Example Org/OU=IT/CN=ci.cluster.local/emailAddress=admin@example.com
         - Key permissions: chmod 640, chown root:ssl-cert
       - status.cluster.local:
         - Certificate: /etc/ssl/certs/status.cluster.local.crt
         - Private key: /etc/ssl/private/status.cluster.local.key
         - Command: openssl req -x509 -nodes -days 365 -newkey rsa:2048
         - Subject: /C=US/ST=Example/L=Example/O=Example Org/OU=IT/CN=status.cluster.local/emailAddress=admin@example.com
         - Key permissions: chmod 640, chown root:ssl-cert
   - Resources: package (1), group (1), directory (2), execute (3)

4. **sites** (`cookbooks/nginx-multisite/recipes/sites.rb`):
   - Iterates over nginx.sites (3 items): test.cluster.local, ci.cluster.local, status.cluster.local
     - For each site, deploys site configuration template:
       - test.cluster.local:
         - Template: `cookbooks/nginx-multisite/templates/default/site.conf.erb` → /etc/nginx/sites-available/test.cluster.local
         - Variables: server_name=test.cluster.local, document_root=/opt/server/test, ssl_enabled=true, cert_file=/etc/ssl/certs/test.cluster.local.crt, key_file=/etc/ssl/private/test.cluster.local.key
       - ci.cluster.local:
         - Template: `cookbooks/nginx-multisite/templates/default/site.conf.erb` → /etc/nginx/sites-available/ci.cluster.local
         - Variables: server_name=ci.cluster.local, document_root=/opt/server/ci, ssl_enabled=true, cert_file=/etc/ssl/certs/ci.cluster.local.crt, key_file=/etc/ssl/private/ci.cluster.local.key
       - status.cluster.local:
         - Template: `cookbooks/nginx-multisite/templates/default/site.conf.erb` → /etc/nginx/sites-available/status.cluster.local
         - Variables: server_name=status.cluster.local, document_root=/opt/server/status, ssl_enabled=true, cert_file=/etc/ssl/certs/status.cluster.local.crt, key_file=/etc/ssl/private/status.cluster.local.key
     - Creates symlink from sites-enabled to sites-available:
       - test.cluster.local: /etc/nginx/sites-enabled/test.cluster.local → /etc/nginx/sites-available/test.cluster.local
       - ci.cluster.local: /etc/nginx/sites-enabled/ci.cluster.local → /etc/nginx/sites-available/ci.cluster.local
       - status.cluster.local: /etc/nginx/sites-enabled/status.cluster.local → /etc/nginx/sites-available/status.cluster.local
   - Deletes default site configuration: /etc/nginx/sites-enabled/default
   - Resources: template (3), link (3), file (1)

## Dependencies

**External cookbook dependencies**: None detected (no metadata.rb dependencies listed)
**System package dependencies**: nginx, fail2ban, ufw, openssl, ca-certificates
**Service dependencies**: nginx, fail2ban, ssh (systemd services)

## Credentials

**Detection Summary**: 0 credentials detected across 0 files

No credentials or secrets were detected in this cookbook. All SSL certificates are self-signed and generated locally using openssl. No data bags, vaults, environment variables, or hardcoded secrets were found. The cookbook uses only non-sensitive configuration values.

## Checks for the Migration

**Files to verify**:
- `/etc/nginx/nginx.conf` - main nginx configuration
- `/etc/nginx/conf.d/security.conf` - nginx security hardening
- `/etc/nginx/sites-available/test.cluster.local` - site config for test
- `/etc/nginx/sites-available/ci.cluster.local` - site config for ci
- `/etc/nginx/sites-available/status.cluster.local` - site config for status
- `/etc/nginx/sites-enabled/test.cluster.local` - symlink to test config
- `/etc/nginx/sites-enabled/ci.cluster.local` - symlink to ci config
- `/etc/nginx/sites-enabled/status.cluster.local` - symlink to status config
- `/etc/nginx/sites-enabled/default` - should NOT exist (deleted)
- `/etc/fail2ban/jail.local` - fail2ban configuration
- `/etc/sysctl.d/99-security.conf` - sysctl security settings
- `/etc/ssh/sshd_config` - SSH configuration (modified)
- `/etc/ssl/certs/test.cluster.local.crt` - SSL certificate for test
- `/etc/ssl/certs/ci.cluster.local.crt` - SSL certificate for ci
- `/etc/ssl/certs/status.cluster.local.crt` - SSL certificate for status
- `/etc/ssl/private/test.cluster.local.key` - SSL private key for test
- `/etc/ssl/private/ci.cluster.local.key` - SSL private key for ci
- `/etc/ssl/private/status.cluster.local.key` - SSL private key for status
- `/opt/server/test/index.html` - static content for test
- `/opt/server/ci/index.html` - static content for ci
- `/opt/server/status/index.html` - static content for status
- `/var/log/nginx/test.cluster.local_access.log` - access log for test
- `/var/log/nginx/test.cluster.local_error.log` - error log for test
- `/var/log/nginx/ci.cluster.local_access.log` - access log for ci
- `/var/log/nginx/ci.cluster.local_error.log` - error log for ci
- `/var/log/nginx/status.cluster.local_access.log` - access log for status
- `/var/log/nginx/status.cluster.local_error.log` - error log for status

**Service endpoints to check**:
- Ports listening: 80 (HTTP), 443 (HTTPS), 22 (SSH)
- Network interfaces: nginx binds to all interfaces (0.0.0.0) by default

**Templates rendered**:
- `cookbooks/nginx-multisite/templates/default/fail2ban.jail.local.erb` → /etc/fail2ban/jail.local (1 time)
- `cookbooks/nginx-multisite/templates/default/sysctl-security.conf.erb` → /etc/sysctl.d/99-security.conf (1 time)
- `cookbooks/nginx-multisite/templates/default/nginx.conf.erb` → /etc/nginx/nginx.conf (1 time)
- `cookbooks/nginx-multisite/templates/default/security.conf.erb` → /etc/nginx/conf.d/security.conf (1 time)
- `cookbooks/nginx-multisite/templates/default/site.conf.erb` → /etc/nginx/sites-available/{site_name} (3 times: test.cluster.local, ci.cluster.local, status.cluster.local)

## Pre-flight checks:
```bash
# Service status
systemctl status nginx
systemctl status fail2ban
systemctl status ssh

# Nginx configuration validation
nginx -t
nginx -V 2>&1 | grep -o 'nginx version: nginx/[0-9.]*'

# Nginx process check
ps aux | grep nginx | grep -v grep
ps aux | grep nginx | wc -l  # should show master + worker processes

# HTTP endpoint checks - verify HTTP to HTTPS redirect
# Site: test.cluster.local
curl -I http://test.cluster.local/  # should return 301 redirect to https
curl -kI https://test.cluster.local/  # should return 200 OK

# Site: ci.cluster.local
curl -I http://ci.cluster.local/  # should return 301 redirect to https
curl -kI https://ci.cluster.local/  # should return 200 OK

# Site: status.cluster.local
curl -I http://status.cluster.local/  # should return 301 redirect to https
curl -kI https://status.cluster.local/  # should return 200 OK

# SSL certificate verification - check each site
# Site: test.cluster.local
openssl s_client -connect test.cluster.local:443 -servername test.cluster.local </dev/null 2>/dev/null | openssl x509 -noout -subject -dates
openssl s_client -connect test.cluster.local:443 -servername test.cluster.local </dev/null 2>/dev/null | grep "Verify return code"

# Site: ci.cluster.local
openssl s_client -connect ci.cluster.local:443 -servername ci.cluster.local </dev/null 2>/dev/null | openssl x509 -noout -subject -dates
openssl s_client -connect ci.cluster.local:443 -servername ci.cluster.local </dev/null 2>/dev/null | grep "Verify return code"

# Site: status.cluster.local
openssl s_client -connect status.cluster.local:443 -servername status.cluster.local </dev/null 2>/dev/null | openssl x509 -noout -subject -dates
openssl s_client -connect status.cluster.local:443 -servername status.cluster.local </dev/null 2>/dev/null | grep "Verify return code"

# SSL certificate file verification
ls -lah /etc/ssl/certs/test.cluster.local.crt
ls -lah /etc/ssl/certs/ci.cluster.local.crt
ls -lah /etc/ssl/certs/status.cluster.local.crt
ls -lah /etc/ssl/private/test.cluster.local.key
ls -lah /etc/ssl/private/ci.cluster.local.key
ls -lah /etc/ssl/private/status.cluster.local.key
stat -c '%a %U:%G' /etc/ssl/private/test.cluster.local.key  # should be 640 root:ssl-cert
stat -c '%a %U:%G' /etc/ssl/private/ci.cluster.local.key  # should be 640 root:ssl-cert
stat -c '%a %U:%G' /etc/ssl/private/status.cluster.local.key  # should be 640 root:ssl-cert

# Fail2ban status
fail2ban-client status
fail2ban-client status sshd
fail2ban-client status nginx-http-auth
fail2ban-client status nginx-limit-req
fail2ban-client status nginx-botsearch

# UFW firewall status
ufw status verbose
ufw status | grep -E "22/tcp|80/tcp|443/tcp"  # should show all three allowed

# SSH configuration verification
grep -E '^PermitRootLogin|^PasswordAuthentication' /etc/ssh/sshd_config  # should show PermitRootLogin no and PasswordAuthentication no

# Sysctl security settings
sysctl net.ipv4.conf.default.rp_filter
sysctl net.ipv4.conf.all.accept_redirects
sysctl net.ipv4.tcp_syncookies
cat /etc/sysctl.d/99-security.conf

# Document root verification
ls -lah /opt/server/test/
ls -lah /opt/server/ci/
ls -lah /opt/server/status/
cat /opt/server/test/index.html
cat /opt/server/ci/index.html
cat /opt/server/status/index.html

# Nginx site configuration verification
ls -lah /etc/nginx/sites-available/
ls -lah /etc/nginx/sites-enabled/
cat /etc/nginx/sites-available/test.cluster.local
cat /etc/nginx/sites-available/ci.cluster.local
cat /etc/nginx/sites-available/status.cluster.local
test -f /etc/nginx/sites-enabled/default && echo "ERROR: default site still exists" || echo "OK: default site removed"

# Nginx main configuration
cat /etc/nginx/nginx.conf | grep -E 'user|worker_processes|worker_connections|gzip'
cat /etc/nginx/conf.d/security.conf

# Log files
ls -lah /var/log/nginx/
tail -f /var/log/nginx/test.cluster.local_access.log
tail -f /var/log/nginx/test.cluster.local_error.log
tail -f /var/log/nginx/ci.cluster.local_access.log
tail -f /var/log/nginx/ci.cluster.local_error.log
tail -f /var/log/nginx/status.cluster.local_access.log
tail -f /var/log/nginx/status.cluster.local_error.log

# Network listening
netstat -tulpn | grep -E ':80|:443|:22'
ss -tlnp | grep -E ':80|:443|:22'
lsof -i :80
lsof -i :443
lsof -i :22

# Fail2ban jail configuration
cat /etc/fail2ban/jail.local | grep -E 'bantime|maxretry|enabled'

# Group verification
getent group ssl-cert  # should exist
getent group www-data  # should exist

# Directory permissions
stat -c '%a %U:%G' /etc/ssl/certs
stat -c '%a %U:%G' /etc/ssl/private
stat -c '%a %U:%G' /opt/server/test
stat -c '%a %U:%G' /opt/server/ci
stat -c '%a %U:%G' /opt/server/status
```