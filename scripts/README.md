# Scripts

## `azure_add_workloads.sh`

Creates **SAP-shaped RHEL VMs on Azure** for testing the migration workflow (discovery, export path, tags). These are **placeholder workloads** — RHEL with naming/tags like a clustered SAP landscape, not a full SAP/HANA software install.

### Prerequisites

```bash
python3 -m venv env && source env/bin/activate
pip install ansible
pip install -r execution-environment/requirements.txt

ansible-galaxy collection install azure.azcollection -p collections/ansible_collections
# azure.azcollection needs many more Python packages than execution-environment/requirements.txt:
pip install -r collections/ansible_collections/azure/azcollection/requirements.txt

az login
# or: export AZURE_SUBSCRIPTION_ID=... AZURE_CLIENT_ID=... AZURE_SECRET=... AZURE_TENANT=...

export AZURE_SSH_PUB_FILE=~/.ssh/id_rsa.pub   # optional
```

### Provision (default: **1 VM only** — `db2-primary` or `hana-primary`)

```bash
chmod +x scripts/azure_add_workloads.sh

./scripts/azure_add_workloads.sh \
  --resource-group sap-migration-dev \
  --sid DEV \
  --location eastus \
  --prefix sap-migration \
  --database db2
```

**SkuNotAvailable in eastus?** Trial subs often have no B/D capacity there. Default script region is `westus2`; use a new resource group in that region, or `-l centralus`. Defaults to `--min-quota` (one `Standard_A1_v2` VM). Use `--low-quota` for two 2-vCPU VMs when quota allows.

Use `--database hana` for HANA-shaped test VMs instead.

Creates in resource group `sap-migration-dev` (default **min** = one VM):

| VM (db2 default) | Role tag |
|------------------|----------|
| `{prefix}-db2-primary` | db2_primary |

More VMs: `--low-quota` (2 VMs) or `--sap` (full 5-VM layout).

Also creates VNet/subnet and NSGs with SAP port ranges (SSH, 3200–3299, HANA ports).

### Verify with discovery playbook

```bash
ansible-playbook collections/ansible_collections/acme/sap_migration/playbooks/01_azure_discovery.yml \
  -e azure_resource_group=sap-migration-dev \
  -e sap_sid=DEV
```

### Destroy workloads

```bash
./scripts/azure_add_workloads.sh --resource-group sap-migration-dev --destroy
```

### Destroy workloads and delete resource group

```bash
./scripts/azure_add_workloads.sh \
  --resource-group sap-migration-dev \
  --destroy \
  --delete-resource-group
```

### Customize VM list

Edit [`inventory/group_vars/azure_workloads.yml`](../collections/ansible_collections/acme/sap_migration/inventory/group_vars/azure_workloads.yml) (`azure_workload_vms`, sizes, image SKU).

### Makefile shortcut

```bash
make azure-add-workloads AZURE_RG=sap-migration-dev SAP_SID=DEV
make azure-destroy-workloads AZURE_RG=sap-migration-dev
```
