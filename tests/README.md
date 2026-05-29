# DEV Validation Checklist

Use this checklist to validate the workflow against a **non-prod Azure clustered DEV** system before QA/PROD cutover.

## Pre-requisites

- [ ] AAP controller with **SAP Migration EE** registered
- [ ] Automation Hub synced with certified collections
- [ ] Azure Service Principal with read access to DEV resource group
- [ ] GCP DEV project with compute/storage permissions
- [ ] SSH access to Azure and GCP SAP nodes
- [ ] SAP media/SWPM available on staging path (for shell install phases)

## Phase validation

| Phase | Playbook | Pass criteria |
|-------|----------|---------------|
| 0 | `00_prerequisites` | All collection checks pass |
| 1 | `01_azure_discovery` | VMs discovered; UID/GID captured |
| 2 | `02_gcp_landing_zone` | VPC, subnet, firewall, GCS bucket exist |
| 3 | `03_gcp_provision_vms` | All cluster nodes SSH-accessible |
| 4 | `04_os_preconfigure` | SAP preconfigure roles complete without error |
| 5–7 | `05`–`07` | Empty HANA/NW shell; Pacemaker healthy on GCP |
| 8 | `08_system_copy_export` | Export manifest created on Azure |
| 9 | `09_transfer_to_gcs` | Objects visible in GCS bucket |
| 10 | `10_system_copy_import` | Import complete; SAP starts on GCP |
| 11 | `11_validate_cutover` | sapcontrol GREEN; pcs status OK |
| 12 | `12_azure_decommission` | Skipped in DEV (`sap_migration_skip_decommission=true`) |

## Automated checks

```bash
# Structure validation (no cloud credentials required)
make validate

# Dry-run prerequisites (requires collections installed)
make dry-run-prerequisites
```

## Workflow integration test

1. Create Workflow JT from `aap/workflow_job_template.yml`
2. Run with `sap_migration_dry_run=true` through node 07
3. Verify approval nodes pause before nodes 08, 11, 12
4. Run nodes 08–11 against DEV with real export/import during maintenance window

## Sign-off

| Role | Name | Date | Approved |
|------|------|------|----------|
| SAP Basis | | | |
| Cloud (GCP) | | | |
| Automation | | | |
