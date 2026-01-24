# Repository Guidelines

## Project Structure & Module Organization
Core automation lives under `playbooks/` (`site.yml`, `upgrade.yml`, `reset.yml`, `reboot.yml`) and composes reusable roles in `roles/` (defaults, vars, templates, files). Environment manifests and Helm values sit in directories such as `apps/`, `monitoring/`, `longhorn/`, and `sig-noz/`, while helper binaries stay in `scripts/` and `longhornctl/`. Shared inventories (`inventory.*.yml`) must remain private—derive new ones from `inventory.yml.example`. Reference documentation and runbooks are in `docs/`.

## Build, Test, and Development Commands
```bash
ansible-playbook playbooks/site.yml -i inventory.yml        # Provision or update a cluster
ansible-playbook playbooks/upgrade.yml -i inventory.yml     # Roll K3s to inventory-defined version
ansible-playbook playbooks/reset.yml -i inventory.yml       # Tear down nodes when decommissioning
ansible-playbook playbooks/site.yml -i inventory.yml --check  # Dry-run changes
vagrant up                                                  # Spin up the 5-node lab from Vagrantfile
ansible-lint playbooks site roles                            # Lint before sending a PR
```

## Coding Style & Naming Conventions
Use two-space YAML indentation and declarative, lowercase task names (`install k3s`). Keep variables snake_case and scope prefixes consistent (`k3s_server_`, `longhorn_`). Prefer fully qualified module names (`ansible.builtin.service`). Stick to defaults in `defaults/main.yml`, pushing environment-specific overrides to inventories or `group_vars/`. Run `ansible-lint` and `yamllint` (see repo configs) before committing; fix the root cause instead of disabling checks.

## Testing Guidelines
Run `ansible-playbook ... --check` and `--diff` for lightweight validation. Exercise new roles with the `vagrant up` lab, keeping any resource tweaks documented in `Vagrantfile`. For production-like QA, stage against hosts from `inventory.dev.local.yml`, then confirm cluster health via `kubectl get nodes` using the generated kubeconfig. New dashboards or apps should include a smoke test note or manual validation steps in `docs/`.

## Commit & Pull Request Guidelines
History follows Conventional Commits (`feat(scope):`, `fix(scope):`, `chore(scope):`). Keep subjects under 72 characters and explain the “why” in the body. Each PR must summarize user impact, call out inventories or docs touched, and list the verification commands you ran (`ansible-lint`, `ansible-playbook --check`, `vagrant up`). Link issues, scrub secrets from diffs, and attach screenshots when altering monitoring assets.

## Security & Configuration Tips
Never commit populated `inventory.yml`; store secrets in Ansible Vault or environment-specific files already ignored by `.gitignore`. Keep kubeconfigs inside the `kubeconfig*` folders only for local use, and scrub credentials before sharing logs or manifests. Follow `docs/SECURITY_GUIDELINES.md` and `docs/INVENTORY_MANAGEMENT.md` when onboarding new clusters.
