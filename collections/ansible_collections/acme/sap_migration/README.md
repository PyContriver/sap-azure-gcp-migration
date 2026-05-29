# acme.sap_migration

Ansible collection for orchestrating clustered SAP workload migration from Azure to GCP.

## Overview

This collection provides playbooks and roles that compose Red Hat certified Ansible
collections into a phased AAP workflow:

1. Azure discovery and sizing
2. GCP landing zone and VM provisioning
3. Greenfield SAP shell install with Pacemaker/HSR
4. System copy export, GCS transfer, and import
5. Validation, cutover, and optional Azure decommission

## Quick start

```bash
cd sap-azure-gcp-migration
ansible-galaxy collection install -r collections/ansible_collections/acme/sap_migration/requirements.yml
ansible-playbook collections/ansible_collections/acme/sap_migration/playbooks/00_prerequisites.yml \
  -e @collections/ansible_collections/acme/sap_migration/inventory/group_vars/all.yml
```

## AAP integration

See `aap/` for Workflow Job Template definitions and survey variables.

## Day 2 playbook

`playbooks/day2_operations.yml` — recurring health, backup (Backint→GCS), firewall audit. See [Day 2 slide pack](docs/day2_operations_slide.md).

## Documentation

- [Workflow Survey](docs/workflow_survey.md)
- [Cutover Runbook](docs/runbook_cutover.md)
- [Day 2 Operations (PPT + Mermaid)](docs/day2_operations_slide.md)
