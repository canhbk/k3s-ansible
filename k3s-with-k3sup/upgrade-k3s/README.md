# Upgrade K3s cluster

```bash
ansible-playbook -i inventory.ini upgrade-control-plane.yml
ansible-playbook -i inventory.ini upgrade-agent.yml
```
