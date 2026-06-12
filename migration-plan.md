# MIGRATION FROM CHEF TO ANSIBLE

## Executive Summary

This repository contains a **Chef Solo** infrastructure-as-code setup with **3 custom cookbooks** managing a multi-site Nginx web server, caching services (Memcached/Redis), and a FastAPI Python application with PostgreSQL. The environment targets **Ubuntu** (with CentOS 7 support) and is provisioned via **Vagrant** using the **libvirt** provider on a **Fedora 42** base box.

The migration scope is **moderate complexity**: 3 cookbooks with 1 external dependency (nginx from Supermarket), 2 fully managed external dependencies (memcached, redisio), 5 ERB templates, 3 static HTML files, 1 custom resource, and **3 hardcoded credentials** that must be migrated to Ansible Vault. The Berksfile references 4 cookbooks total (3 local + 1 external).

**Estimated Timeline**: 3–4 weeks for a single engineer, or 2–3 weeks with a two-person team. This accounts for playbook development, template conversion, testing in Vagrant, and documentation.

---

## Module Migration Plan

This repository contains **Chef cookbooks** that need individual migration planning:

### MODULE INVENTORY

- **nginx-multisite**:
    - Description: Nginx web server provisioning with multi-site SSL-enabled virtual hosts, security hardening (fail2ban, UFW firewall, sysctl kernel parameters), and self-signed certificate generation
    - Path: cookbooks/nginx-multisite
    - Technology: Chef (Ruby DSL)
    - Key Features:
        - Dynamic site configuration via `node['nginx']['sites']` hash (3 sites: test.ci.cluster.local, ci.cluster.local, status.cluster.local)
        - SSL/TLS with self-signed certificate generation via `openssl req -x509`
        - Rate limiting zones (login: 10r/m, api: 30r/m)
        - Security headers (X-Frame-Options, X-Content-Type-Options, CSP, HSTS)
        - fail2ban jails for SSH, nginx-http-auth, nginx-limit-req, nginx-botsearch
        - UFW firewall with default-deny policy, allowing SSH/HTTP/HTTPS
        - sysctl hardening (IP spoofing protection, ICMP redirect ignore, SYN flood protection, IPv6 disable)
        - Custom `lineinfile` resource for atomic file line insertion
    - Files to migrate:
        - 5 ERB templates: `nginx.conf.erb`, `site.conf.erb`, `security.conf.erb`, `fail2ban.jail.local.erb`, `sysctl-security.conf.erb`
        - 3 static HTML files: `files/default/test/index.html`, `files/default/ci/index.html`, `files/default/status/index.html`
        - 1 custom resource: `resources/lineinfile.rb` (replaces Ansible `lineinfile` module)
        - 1 attributes file: `attributes/default.rb`
        - 5 recipe files: `default.rb`, `nginx.rb`, `ssl.rb`, `security.rb`, `sites.rb`

- **cache**:
    - Description: Caching service configuration for Memcached and Redis, including Redis authentication setup and configuration workarounds
    - Path: cookbooks/cache
    - Technology: Chef (Ruby DSL)
    - Key Features:
        - Memcached installation via external `memcached` cookbook (~> 6.0)
        - Redis configuration via external `redisio` cookbook (~> 7.2.4) with password authentication
        - Redis config file patching via `ruby_block` hack to remove deprecated directives (replica-serve-stale-data, replica-read-only, repl-ping-replica-period, client-output-buffer-limit, replica-priority)
        - Redis log directory creation
    - Files to migrate:
        - 1 recipe file: `recipes/default.rb`
        - 1 metadata file: `metadata.rb`

- **fastapi-tutorial**:
    - Description: FastAPI Python web application deployment with PostgreSQL database provisioning, systemd service management, and environment configuration
    - Path: cookbooks/fastapi-tutorial
    - Technology: Chef (Ruby DSL)
    - Key Features:
        - Python 3 environment setup (python3, python3-pip, python3-venv)
        - Git repository clone from `https://github.com/dibanez/fastapi_tutorial.git` (main branch)
        - Python virtual environment creation and dependency installation from requirements.txt
        - PostgreSQL service enablement and database/user creation
        - Environment file (.env) with database connection string
        - systemd service file for uvicorn ASGI server (port 8000, auto-restart)
    - Files to migrate:
        - 1 recipe file: `recipes/default.rb`
        - 1 metadata file: `metadata.rb`

### Infrastructure Files

- **Berksfile**: Berkshelf dependency manifest. References Supermarket as source and declares 3 local cookbooks plus 3 external cookbooks (nginx ~> 12.0, memcached ~> 6.0, redisio ~> 7.2.4). **Migration action**: Replace with Ansible Galaxy requirements.yml for collection dependencies. The nginx cookbook dependency can be replaced with the community.general.nginx role or manual nginx package management.

- **solo.json**: Chef Solo run configuration containing the run_list and all node attributes. Contains site definitions, SSL paths, and security settings. **Migration action**: Convert to Ansible inventory variables or group/host vars files. The `nginx.sites` hash maps directly to an Ansible dictionary variable.

- **solo.rb**: Chef Solo configuration specifying cache directory (`/var/chef-solo`), cookbook paths, and log level. **Migration action**: No direct equivalent in Ansible; playbook execution handles paths via `collections_path` and `roles_path`.

- **Vagrantfile**: Vagrant VM configuration for Fedora 42 with libvirt provider. Defines private network (192.168.121.10), port forwarding (80→8080, 443→8443), 2048MB RAM, 2 CPUs, and rsync synced folder. **Migration action**: Keep as-is for development/testing; create an Ansible inventory file (e.g., `inventory/vagrant.ini`) targeting the VM.

- **vagrant-provision.sh**: Shell script that bootstraps the VM: installs build-essential, Chef, Berkshelf, runs `berks install` and `berks vendor`, then executes `chef-solo`. **Migration action**: Replace with an Ansible playbook run (`ansible-playbook site.yml -i inventory/vagrant.ini`). The script's apt-get install steps can be folded into an Ansible playbook's initial setup role.

### Target Details

- **Operating System**: **Ubuntu** (primary) and **CentOS 7** (secondary). Evidence: `supports 'ubuntu', '>= 18.04'` and `supports 'centos', '>= 7.0'` in all metadata.rb files; `www-data` user (Ubuntu convention); `ufw` firewall (Ubuntu/Debian); `apt-get` in vagrant-provision.sh. The Vagrantfile uses `generic/fedora42` box, but this is a development/testing box, not the target. **Recommendation**: Target Ubuntu 22.04/24.04 as primary; CentOS 7 is EOL and should not be targeted in the Ansible migration.

- **Virtual Machine Technology**: **libvirt** (KVM/QEMU) via Vagrant. Evidence: `config.vm.provider "libvirt"` in Vagrantfile with memory, CPUs, and title settings.

- **Cloud Platform**: **Not specified**. No cloud-specific configurations detected.

---

## Migration Approach

### Key Dependencies to Address

- **nginx (supermarket cookbook, ~> 12.0)**: Replace with `community.general.nginx` Ansible collection role or manual nginx package installation + template-based configuration. The nginx cookbook provides basic package installation and service management; the Ansible equivalent is straightforward.

- **memcached (~> 6.0)**: Replace with `community.general.memcached` role or manual package installation (`apt install memcached`) + template for `/etc/memcached.conf`. The memcached cookbook is a thin wrapper around package/service management.

- **redisio (~> 7.2.4)**: Replace with `geerlingguy.redis` Ansible role or manual package installation + template for `/etc/redis/6379.conf`. The redisio cookbook provides Redis installation and configuration; the Ansible equivalent requires careful handling of the `requirepass` directive and the deprecated config workarounds.

- **fail2ban**: Replace with `community.general.fail2ban` role or manual package + template for `/etc/fail2ban/jail.local`. The fail2ban.jail.local.erb template is self-contained and can be directly converted to a Jinja2 template.

- **ufw**: Replace with `community.general.ufw` Ansible module. Straightforward mapping: default deny policy, allow SSH/HTTP/HTTPS rules.

- **postgresql**: Replace with `community.postgresql` collection roles (`postgresql_user`, `postgresql_db`) or manual package + `postgresql` module. The fastapi-tutorial cookbook uses raw `execute` blocks with `psql` commands; these map directly to Ansible's `community.postgresql.postgresql_user` and `community.postgresql.postgresql_db` modules.

### Security Considerations

- **Hardcoded Credentials (3 detected)**:
    1. **Redis password**: `'redis_secure_password_123'` in `cookbooks/cache/recipes/default.rb` — migrate to Ansible Vault variable `redis_password`.
    2. **PostgreSQL user password**: `'fastapi_password'` in `cookbooks/fastapi-tutorial/recipes/default.rb` — migrate to Ansible Vault variable `fastapi_db_password`.
    3. **PostgreSQL database connection string**: Contains the password inline in `.env` file content — migrate to use Ansible Vault variable in the Jinja2 template.

- **Self-Signed SSL Certificates**: Generated dynamically via `openssl req -x509` in `ssl.rb` recipe. In Ansible, use the `openssl_certificate` module from `community.crypto` collection to generate self-signed certificates, or copy pre-existing certificates. The current approach generates certs on first run with `not_if` guard; the Ansible equivalent should use `community.crypto.openssl_certificate` with `force: false` to avoid regenerating on every run.

- **SSH Hardening**: `disable_root: true` and `password_auth: false` settings in `solo.json` and `attributes/default.rb`. Migrate to `community.general.lineinfile` or `ansible.builtin.lineinfile` module for `/etc/ssh/sshd_config` with `PermitRootLogin no` and `PasswordAuthentication no`.

- **UFW Firewall**: Default-deny policy with SSH/HTTP/HTTPS allowed. Migrate to `community.general.ufw` module with `default: deny`, `rules: [{port: '22', proto: 'tcp', rule: 'allow'}, ...]`.

- **fail2ban**: Jails for SSHD, nginx-http-auth, nginx-limit-req, nginx-botsearch. Migrate the `fail2ban.jail.local.erb` template directly to a Jinja2 template, or use `community.general.fail2ban` role with `jails` variable.

- **sysctl Hardening**: 15+ kernel parameters for IP spoofing protection, ICMP handling, SYN flood protection, and IPv6 disable. Migrate to `ansible.builtin.sysctl` module or a Jinja2 template for `/etc/sysctl.d/99-security.conf`.

- **Vault/secrets management summary per module**:
    - **nginx-multisite**: 0 credentials detected. SSL cert paths are configuration, not secrets.
    - **cache**: 1 credential detected — Redis password (`redis_secure_password_123`).
    - **fastapi-tutorial**: 2 credentials detected — PostgreSQL user password (`fastapi_password`) and the connection string containing it.

### Technical Challenges

- **Deprecated Redis Config Directives**: The `cache` cookbook includes a `ruby_block` "HACK" that strips 5 deprecated Redis config directives (`replica-serve-stale-data`, `replica-read-only`, `repl-ping-replica-period`, `client-output-buffer-limit`, `replica-priority`) from `/etc/redis/6379.conf`. This is a version compatibility workaround. **Mitigation**: Investigate the target Redis version and determine if these directives are still deprecated. If so, use `community.general.lineinfile` with `state: absent` to remove them, or use a Jinja2 template that omits them entirely.

- **Custom `lineinfile` Resource**: The `nginx-multisite` cookbook defines a custom Chef resource (`resources/lineinfile.rb`) that mimics Ansible's `lineinfile` module. **Mitigation**: This is directly replaceable with Ansible's built-in `ansible.builtin.lineinfile` module. No custom module development needed.

- **Dynamic Site Configuration**: The `nginx-multisite` cookbook iterates over `node['nginx']['sites']` to generate site configs, create document roots, and deploy index.html files. **Mitigation**: Use Ansible `with_dict` or `loop` over a dictionary variable defined in inventory/group vars. The Jinja2 `site.conf` template can be used directly with `ansible.builtin.template` module.

- **Cross-Platform Support**: All cookbooks declare support for both Ubuntu (>= 18.04) and CentOS (>= 7). The current code uses Ubuntu-specific conventions (www-data user, ufw, apt-get). **Mitigation**: The Ansible migration should target Ubuntu as primary. If CentOS support is required, add `when` conditions or use `ansible_facts` to branch on OS family. Note: CentOS 7 is EOL (June 2024) and should be deprecated.

- **Git Repository Clone**: The `fastapi-tutorial` cookbook clones from `https://github.com/dibanez/fastapi_tutorial.git`. **Mitigation**: Use `ansible.builtin.git` module. Consider whether the repository URL should be a variable for flexibility.

- **Systemd Service Management**: The `fastapi-tutorial` cookbook writes a raw systemd unit file. **Mitigation**: Use `ansible.builtin.template` for the service file, or `community.general.systemd` module. The current service runs as `root` — consider security implications and whether a dedicated service user should be created.

- **Vagrant Development Environment**: The `vagrant-provision.sh` script installs Chef and Berkshelf on the VM. **Mitigation**: Replace with an Ansible playbook that can be run from the host against the Vagrant VM (`ansible-playbook site.yml -i inventory/vagrant.ini`). The apt-get install steps can be part of a setup playbook.

### Migration Order

1. **Priority 1 — cache** (low risk, foundational):
    - Memcached and Redis are infrastructure dependencies that nginx-multisite and fastapi-tutorial may rely on.
    - Straightforward package + template migration.
    - No complex dynamic configuration.
    - **Risk**: Low. The redisio cookbook hack is the only concern.

2. **Priority 2 — fastapi-tutorial** (moderate complexity):
    - Depends on PostgreSQL being available.
    - Involves git clone, Python venv, and systemd service creation.
    - Contains hardcoded credentials that must be vaulted.
    - **Risk**: Moderate. Database provisioning must be idempotent.

3. **Priority 3 — nginx-multisite** (high complexity, highest value):
    - Most complex module with 5 templates, dynamic site generation, SSL, security hardening.
    - Highest business value as it serves the web-facing sites.
    - Contains the most configuration to convert (sysctl, fail2ban, UFW, nginx).
    - **Risk**: High. SSL certificate generation and nginx reload ordering must be carefully handled.

4. **Infrastructure files** (parallel with cookbooks):
    - Convert `solo.json` to Ansible inventory/group vars.
    - Create `requirements.yml` for Ansible Galaxy collections.
    - Update `Vagrantfile` to reference Ansible provisioner.
    - Create `vagrant-provision.sh` equivalent Ansible playbook.

### Assumptions

1. **Target OS is Ubuntu**: All cookbooks support Ubuntu >= 18.04 and CentOS >= 7, but the provision script uses `apt-get` and the code uses `www-data` user and `ufw`, all Ubuntu/Debian conventions. The Vagrant box is Fedora 42, but this is a development/testing box. **Assumption**: Migration targets Ubuntu 22.04 or 24.04. CentOS 7 support should be evaluated separately (EOL).

2. **Redis version compatibility**: The `ruby_block` hack in the cache cookbook suggests a specific Redis version compatibility issue. **Assumption**: The target Redis version is known and the deprecated directives can be handled via `lineinfile state: absent` or template omission.

3. **SSL certificates are self-signed for development**: The `ssl.rb` recipe generates self-signed certificates with `not_if` guard. **Assumption**: Production will use real certificates (Let's Encrypt or internal CA). The Ansible migration should support both self-signed and pre-existing certificate workflows.

4. **The `nginx` Supermarket cookbook dependency is optional**: The Berksfile includes `nginx ~> 12.0` but the `nginx-multisite` cookbook's `nginx.rb` recipe installs nginx via raw `package` resource, not via the cookbook. **Assumption**: The nginx cookbook dependency can be dropped in the Ansible migration; nginx will be managed via `community.general.nginx` role or manual package management.

5. **The `ssl_certificate` cookbook is commented out**: The Berksfile has `# cookbook 'ssl_certificate', '~> 2.1'` commented out. **Assumption**: This dependency is not needed and can be ignored.

6. **The FastAPI tutorial repository is accessible**: The `fastapi-tutorial` cookbook clones from `https://github.com/dibanez/fastapi_tutorial.git`. **Assumption**: This repository is publicly accessible and the `main` branch is the target.

7. **No encrypted data bags or Chef Vault**: No evidence of Chef encrypted data bags, Chef Vault, or other Chef-specific secrets management. **Assumption**: All secrets are plaintext in attributes/recipes and should be migrated to Ansible Vault.

8. **The `lineinfile` custom resource is not used externally**: The `nginx-multisite` cookbook defines a `lineinfile` custom resource but it is not referenced in any recipe file. **Assumption**: This resource is unused and can be dropped in the Ansible migration.

9. **Port forwarding is for development only**: The Vagrantfile forwards guest port 80 to host 8080 and 443 to 8443. **Assumption**: Production will use standard ports 80/443 without forwarding.

10. **The `lost+found` directory is an artifact**: This is a filesystem artifact (ext4) and not part of the Chef repository. **Assumption**: It can be ignored.

---

## Ansible Project Structure Recommendation

```
ansible-migration/
├── inventory/
│   ├── group_vars/
│   │   ├── all.yml          # Global variables (nginx sites, security settings)
│   │   └── cache.yml        # Redis/Memcached variables
│   ├── host_vars/
│   │   └── chef-nginx.yml   # Per-host overrides
│   └── hosts.ini            # Vagrant inventory
├── roles/
│   ├── nginx-multisite/
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── install.yml
│   │   │   ├── ssl.yml
│   │   │   ├── security.yml
│   │   │   └── sites.yml
│   │   ├── templates/
│   │   │   ├── nginx.conf.j2
│   │   │   ├── site.conf.j2
│   │   │   ├── security.conf.j2
│   │   │   ├── fail2ban.jail.local.j2
│   │   │   └── sysctl-security.conf.j2
│   │   ├── files/
│   │   │   ├── test/index.html
│   │   │   ├── ci/index.html
│   │   │   └── status/index.html
│   │   ├── vars/
│   │   │   └── main.yml
│   │   └── meta/
│   │       └── main.yml
│   ├── cache/
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── templates/
│   │   │   └── redis.conf.j2
│   │   └── vars/
│   │       └── main.yml
│   └── fastapi-tutorial/
│       ├── tasks/
│       │   └── main.yml
│       ├── templates/
│       │   ├── .env.j2
│       │   └── fastapi-tutorial.service.j2
│       └── vars/
│           └── main.yml
├── group_vars/
│   └── all.yml              # Vault-encrypted variables
├── vault/
│   └── secrets.yml          # Ansible Vault encrypted file
├── site.yml                 # Main playbook
├── requirements.yml         # Ansible Galaxy collections
├── Vagrantfile              # Updated to use Ansible provisioner
└── vagrant-provision.sh     # Updated to run Ansible playbook
```

## Coordination Guidance

1. **Team of 2 recommended**: One engineer handles nginx-multisite (complex, high-value), the other handles cache + fastapi-tutorial (moderate complexity).

2. **Template conversion priority**: The 5 ERB templates should be converted to Jinja2 first, as they are the most direct 1:1 migration candidates. The `site.conf.erb` template is the most complex with conditional SSL blocks.

3. **Testing strategy**: Use the existing Vagrant environment for testing. Update `vagrant-provision.sh` to run the Ansible playbook instead of Chef. Test each role independently before integrating.

4. **Secrets migration**: Create the Ansible Vault file (`vault/secrets.yml`) first, then update each role to reference vault variables. Never commit plaintext secrets.

5. **Documentation**: Document the mapping from Chef concepts to Ansible equivalents:
   - Chef `node['attribute']` → Ansible `group_vars/all.yml`
   - Chef `include_recipe` → Ansible `roles:` in playbook
   - Chef `template` → Ansible `ansible.builtin.template`
   - Chef `execute` → Ansible `ansible.builtin.command` or `ansible.builtin.shell`
   - Chef `service` → Ansible `ansible.builtin.service`
   - Chef `package` → Ansible `ansible.builtin.apt` or `ansible.builtin.package`
