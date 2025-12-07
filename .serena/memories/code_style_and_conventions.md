# Code Style and Conventions

## Git Commit Rules

- Follow conventional commit format (Angular team style)
- Examples:
  - `feat(cluster): add new node configuration`
  - `fix(inventory): update dev cluster passwords`
  - `docs(readme): update deployment instructions`
  - `refactor(playbook): optimize node removal procedure`
- Do NOT mention Claude in any commits, PRs, or comments
- Do NOT add auto-generated signatures like "Generated with Claude Code"
- Only commit files related to the specific fix/implementation
- Do NOT use `git add .` - stage only relevant files

## File Organization

- **Inventory Files**: Environment-specific (inventory.dev.local.yml, inventory.prod.yml, etc.)
- **Playbooks**: Located in `playbooks/` directory
- **Roles**: Modular components in `roles/` directory
- **Documentation**: Comprehensive docs in `docs/` directory

## Ansible Configuration

- Uses `ansible.cfg` with specific settings
- Default inventory: `./inventory.yml`
- Roles path: `./roles`
- Become (sudo) enabled by default
- Host key checking disabled for automation

## YAML Style

- Standard YAML formatting for Ansible playbooks and Kubernetes manifests
- Consistent indentation (2 spaces)
- Use meaningful variable names
- Comment complex configurations

## Security Practices

- Inventory files with passwords are git-ignored
- Use example files for sharing configurations
- Separate development and production environments
- Certificate-based authentication for clusters

## Documentation Standards

- Always update documentation when making changes
- Include actual kubectl commands used
- Update timestamps in docs
- Verify changes are reflected correctly
- Maintain cluster-specific documentation
