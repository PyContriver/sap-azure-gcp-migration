# AAP Workflow Survey Variables

Configure these as **Survey questions** on the Workflow Job Template in AAP Controller.

## Required variables

| Variable | Type | Description |
|----------|------|-------------|
| `migration_name` | text | Unique migration identifier (e.g. `prd-q1-2026`) |
| `sap_database_type` | choice | `db2` (IBM Db2 AnyDB) or `hana` (SAP HANA) |
| `sap_sid` | text | SAP System ID (3 chars, must match source) |
| `sap_db2_instance` | text | Db2 instance name (e.g. `db2inst1`) when `db2` |
| `sap_instance_nr` | text | ABAP instance number (e.g. `00`) |
| `sap_hana_instance_nr` | text | HANA instance number (e.g. `00`) |
| `azure_subscription_id` | text | Azure subscription ID |
| `azure_resource_group` | text | Source Azure resource group |
| `azure_location` | text | Azure region (e.g. `eastus`) |
| `gcp_project` | text | Target GCP project ID |
| `gcp_region` | text | GCP region (e.g. `us-central1`) |
| `gcp_zone` | text | GCP zone (e.g. `us-central1-a`) |

## Optional variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `sap_domain` | text | `sap.local` | SAP DNS domain |
| `system_copy_gcs_bucket` | text | `{gcp_project}-sap-migration` | GCS staging bucket |
| `system_copy_export_path` | text | `/sapmnt/{sid}/export` | Export path on Azure |
| `sap_migration_dry_run` | boolean | `false` | Skip destructive SAP/cloud actions |
| `sap_migration_skip_decommission` | boolean | `true` | Skip Azure VM deletion |
| `sap_azure_decommission_delete_vms` | boolean | `false` | Delete (not just stop) Azure VMs |

## Credentials (AAP Credential Manager)

| Credential type | Used by |
|-----------------|---------|
| Microsoft Azure Resource Manager | Playbooks 00, 01, 08, 12 |
| Google Cloud Platform | Playbooks 02, 03, 09 |
| Machine SSH | Playbooks 04–08, 10–11 |
| Vault / custom for `<sid>adm` passwords | Playbooks 05–08, 10 |

## Manual approval gates

Insert **Workflow Approval** nodes before:

1. **Node 08** — System copy export (production quiesce)
2. **Node 11** — Cutover (DNS/VIP switch)
3. **Node 12** — Azure decommission

## Extra-vars from discovery

After playbook `01_azure_discovery` runs, review job artifacts for:

- `sap_azure_discovery_report`
- `sap_inferred_cluster_nodes`
- `sap_user_uid_gid`

Update `sap_ha_cluster` inventory group_vars if discovery differs from defaults.
