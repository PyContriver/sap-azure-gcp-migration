# SAP Azure→GCP Migration Workflow

Ansible Automation Platform workflow for migrating **clustered SAP workloads** from Azure to GCP using a **greenfield GCP build** and **SAP system copy export/import**, orchestrated with Red Hat certified collections.

## Repository layout

```
sap-azure-gcp-migration/
├── collections/ansible_collections/acme/sap_migration/   # Orchestration collection
├── execution-environment/                                 # Custom AAP EE definition
├── aap/                                                   # Workflow JT seed + inventories
└── tests/                                                 # Validation scripts
```

## Certified collection stack

| Collection | Purpose |
|------------|---------|
| `redhat.sap_install` | OS preconfigure, HANA/NW install, Pacemaker, HSR |
| `sap.sap_operations` | SAP stop/start, operational tasks |
| `azure.azcollection` | Azure discovery and decommission |
| `google.cloud` | GCP VPC, VMs, GCS |
| `cloud.gcp_ops` | GCP validated operational content |
| `ansible.platform` | AAP controller seeding |

## Azure test workloads (optional)

Provision SAP-shaped RHEL VMs on Azure before running discovery/migration:

```bash
./scripts/azure_add_workloads.sh --resource-group sap-migration-dev --sid DEV --database db2
```

See [scripts/README.md](scripts/README.md) and [database profiles](collections/ansible_collections/acme/sap_migration/docs/database_profiles.md).

## Quick start

### 1. Build Execution Environment

```bash
cd execution-environment
ansible-builder build -t sap-migration-ee:latest -f execution-environment.yml
```

Push the image to your registry and register it in AAP as **SAP Migration EE**.

### 2. Install collection dependencies

```bash
ansible-galaxy collection install -r \
  collections/ansible_collections/acme/sap_migration/requirements.yml
```

### 3. Dry-run prerequisites check

```bash
ansible-playbook \
  collections/ansible_collections/acme/sap_migration/playbooks/00_prerequisites.yml \
  -e sap_migration_dry_run=true \
  -e sap_sid=DEV \
  -e azure_resource_group=dev-sap-rg \
  -e gcp_project=my-gcp-project
```

### 4. Seed AAP workflow

```bash
export CONTROLLER_HOST=https://aap.example.com
export CONTROLLER_PASSWORD=...
ansible-playbook aap/seed_controller.yml
```

Then create the Workflow Job Template in AAP UI using the node graph in [`aap/workflow_job_template.yml`](aap/workflow_job_template.yml).

## Workflow phases

| # | Playbook | Phase |
|---|----------|-------|
| 00 | `00_prerequisites.yml` | Validate collections and variables |
| 01 | `01_azure_discovery.yml` | Discover Azure cluster topology |
| 02 | `02_gcp_landing_zone.yml` | VPC, firewall, VIPs, GCS bucket |
| 03 | `03_gcp_provision_vms.yml` | Provision RHEL for SAP VMs |
| 04–07 | OS/HANA/NW/HA playbooks | Greenfield SAP shell on GCP |
| 08–10 | Export/transfer/import | System copy migration |
| 11–12 | Cutover/decommission | Validation and Azure cleanup |

Manual **approval gates** before export, cutover, and decommission.

## Day 2 operations (post-migration)

After cutover, run [`day2_operations.yml`](collections/ansible_collections/acme/sap_migration/playbooks/day2_operations.yml) on a schedule:

| Tag | Purpose |
|-----|---------|
| `day2_health` | sapcontrol, Pacemaker, HSR checks |
| `day2_backup` | HANA Backint backup to GCS |
| `day2_firewall` | SAP firewall + GCP tag audit |
| `day2_report` | Aggregate health to AAP |

PPT content and Mermaid diagrams: [`docs/day2_operations_slide.md`](collections/ansible_collections/acme/sap_migration/docs/day2_operations_slide.md)

```bash
ansible-playbook collections/ansible_collections/acme/sap_migration/playbooks/day2_operations.yml \
  --tags day2_health -i <gcp_inventory>
```

## Documentation

- [Workflow Survey Variables](collections/ansible_collections/acme/sap_migration/docs/workflow_survey.md)
- [Cutover Runbook](collections/ansible_collections/acme/sap_migration/docs/runbook_cutover.md)

## Validation

```bash
make validate
```

See [tests/README.md](tests/README.md) for non-prod DEV validation checklist.
