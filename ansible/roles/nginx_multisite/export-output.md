MIGRATION FAILED for nginx_multisite

Failure Reason:
  Stall detected after 1 attempt(s): errors unchanged between attempts, aborting.
Errors remain:
## ansible-lint Errors
```
Found 1 ansible-lint issue(s):
[VERY_HIGH] .:1 [internal-error] ERROR: running ansible-lint:
```[Errno 2] No such file or directory: 'ansible-config'``` ()

==============================
Rule Hints (How to Fix):
==============================
[internal-error] ERROR: running ansible-lint:
```[Errno 2] No such file or directory: 'ansible-config'```
  Description: ERROR: running ansible-lint:
```[Errno 2] No such file or directory: 'ansible-config'```
```

Migration Summary:
  Total items: 23
  Completed: 6
  Pending: 9
  Missing: 8
  Errors: 0
  Write attempts: 4
  Validation attempts: 1

Partial Validation Report:
Validation incomplete after 1 attempts:
## ansible-lint Errors
```
Found 1 ansible-lint issue(s):
[VERY_HIGH] .:1 [internal-error] ERROR: running ansible-lint:
```[Errno 2] No such file or directory: 'ansible-config'``` ()

==============================
Rule Hints (How to Fix):
==============================
[internal-error] ERROR: running ansible-lint:
```[Errno 2] No such file or directory: 'ansible-config'```
  Description: ERROR: running ansible-lint:
```[Errno 2] No such file or directory: 'ansible-config'```
```

Partial Checklist:
## Checklist: nginx_multisite

### Templates
- [ ] cookbooks/nginx-multisite/templates/default/fail2ban.jail.local.erb → ansible/roles/nginx_multisite/templates/fail2ban.jail.local.j2 (pending)
- [ ] cookbooks/nginx-multisite/templates/default/nginx.conf.erb → ansible/roles/nginx_multisite/templates/nginx.conf.j2 (pending)
- [ ] cookbooks/nginx-multisite/templates/default/site.conf.erb → ansible/roles/nginx_multisite/templates/site.conf.j2 (pending)
- [ ] cookbooks/nginx-multisite/templates/default/security.conf.erb → ansible/roles/nginx_multisite/templates/security.conf.j2 (pending)
- [ ] cookbooks/nginx-multisite/templates/default/sysctl-security.conf.erb → ansible/roles/nginx_multisite/templates/sysctl-security.conf.j2 (pending)

### Recipes → Tasks
- [ ] cookbooks/nginx-multisite/recipes/nginx.rb → ansible/roles/nginx_multisite/tasks/nginx.yml (missing)
- [ ] cookbooks/nginx-multisite/recipes/security.rb → ansible/roles/nginx_multisite/tasks/security.yml (missing)
- [ ] cookbooks/nginx-multisite/recipes/ssl.rb → ansible/roles/nginx_multisite/tasks/ssl.yml (missing)
- [ ] cookbooks/nginx-multisite/recipes/sites.rb → ansible/roles/nginx_multisite/tasks/sites.yml (pending)
- [ ] cookbooks/nginx-multisite/recipes/default.rb → ansible/roles/nginx_multisite/tasks/default.yml (missing)

### Attributes → Variables
- [ ] cookbooks/nginx-multisite/attributes/default.rb → ansible/roles/nginx_multisite/defaults/main.yml (pending)

### Static Files
- [ ] cookbooks/nginx-multisite/files/ci/index.html → ansible/roles/nginx_multisite/files/ci/index.html (missing)
- [ ] cookbooks/nginx-multisite/files/test/index.html → ansible/roles/nginx_multisite/files/test/index.html (missing)
- [ ] cookbooks/nginx-multisite/files/status/index.html → ansible/roles/nginx_multisite/files/status/index.html (missing)

### Structure Files
- [x] N/A → ansible/roles/nginx_multisite/meta/main.yml (complete) - Created standard meta/main.yml
- [ ] N/A → ansible/roles/nginx_multisite/defaults/main.yml (pending)
- [ ] N/A → ansible/roles/nginx_multisite/handlers/main.yml (missing)
- [ ] N/A → ansible/roles/nginx_multisite/tasks/main.yml (pending)

### Molecule Testing
- [x] N/A → ansible/roles/nginx_multisite/molecule/default/converge.yml (complete) - Generated converge.yml with all expected directory structures, config files, SSL certificates, document roots, and static content under /tmp/molecule_test/. No become, no include_role, no prepare.yml. All paths use /tmp/molecule_test/ prefix.
- [x] N/A → ansible/roles/nginx_multisite/molecule/default/molecule.yml (complete) - Created by MoleculeAgent (deterministic scaffold)
- [x] N/A → ansible/roles/nginx_multisite/molecule/default/create.yml (complete) - Created by MoleculeAgent (deterministic scaffold)
- [x] N/A → ansible/roles/nginx_multisite/molecule/default/verify.yml (complete) - Generated verify.yml with 22 verification sections covering: nginx.conf directives, security.conf settings, all 3 site configs (server_name, document_root, SSL paths, HSTS, security headers, gzip, try_files, log paths), symlinks in sites-enabled, default site removal, fail2ban jail settings, sysctl hardening, SSH hardening, SSL cert/key existence and permissions, document root existence and permissions, index.html content, log file existence, service_facts for nginx/fail2ban, and container-safe URI checks for HTTP redirect and HTTPS access (tagged molecule-notest).
- [x] N/A → ansible/roles/nginx_multisite/molecule/default/destroy.yml (complete) - Created by MoleculeAgent (deterministic scaffold)


Telemetry:
Phase: migrate
Duration: 0.00s

Agent Metrics:
  AAP Collection Discovery: 0.00s
  Credential Extractor: 214.01s
  Export Planner: 103.11s
    Tokens: 56897 in, 4415 out
    Tools: add_checklist_task: 23, get_checklist_summary: 1, list_checklist_tasks: 2
  Ansible Role Writer: 1932.41s
    Tokens: 402419 in, 51046 out
    Tools: ansible_write: 7, list_checklist_tasks: 3, list_directory: 21, read_file: 55, update_checklist_task: 16, write_file: 3
    attempts: 4
    complete: True
    files_created: 1
    files_total: 23
  Molecule Test Generator: 1298.78s
    Tokens: 247257 in, 21892 out
    Tools: get_checklist_summary: 1, list_checklist_tasks: 1, read_file: 10, update_checklist_task: 4, write_file: 2
    attempts: 1
    complete: True
  ReviewAgent: 996.67s
    Tokens: 216626 in, 26663 out
    Tools: ansible_write: 1, list_directory: 2, read_file: 18, write_file: 4
  Ansible Lint Validator: 394.42s
    Tokens: 82900 in, 17867 out
    Tools: ansible_lint: 2, ansible_role_check: 1, list_checklist_tasks: 1, list_directory: 6, read_file: 15
    validators_passed: ['role-check']
    validators_failed: ['ansible-lint']
    attempts: 1
    complete: False
    has_errors: True