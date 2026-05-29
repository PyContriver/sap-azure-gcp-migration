# Database profiles — IBM Db2 vs SAP HANA

Set **`sap_database_type`** in the AAP survey or extra-vars:

| Value | Landscape | Profile file |
|-------|-----------|--------------|
| `db2` | ECC / NetWeaver AnyDB, distributed + HA | `profiles/db2_ha.yml` |
| `hana` | S/4HANA on HANA, distributed + HA | `profiles/hana_ha.yml` |

Default in [`all.yml`](../inventory/group_vars/all.yml): **`db2`**.

## IBM Db2 migration path

| Phase | Playbook | Db2-specific behavior |
|-------|----------|------------------------|
| Azure test VMs | `provision_azure_workloads` / script | `db2-primary`, `db2-secondary` nodes |
| GCP VMs | `03_gcp_provision_vms` | `db2_primary`, `db2_secondary` in `sap_cluster_nodes` |
| OS prep | `04_os_preconfigure` | NetWeaver preconfigure on Db2 hosts |
| DB shell | `05_database_shell_install` | `db2_shell_install` + SWPM (inifile required) |
| HA | `07_ha_cluster_build` | Pacemaker + **Db2 HADR** (not HSR) |
| Export | `08_system_copy_export` | `db2 backup database ... online` or SWPM export |
| Transfer | `09_transfer_to_gcs` | Same GCS staging |
| Import | `10_system_copy_import` | `db2 restore database` or SWPM import |
| Cutover | `11_validate_cutover` | `db2 list active databases` |
| Day 2 | `day2_operations` | `db2 connect`, `db2pd -hadr` (no HANA Backint) |

### Db2 export methods (`system_copy_export_method`)

- `db2_online_backup` — default for Db2 profile
- `db2_offline_backup` — deactivate DB first
- `swpm_homogeneous` — SWPM export (full landscape)

### Db2 import methods (`system_copy_import_method`)

- `db2_restore` — default for Db2 profile
- `swpm_homogeneous` — SWPM import

### Required variables

```yaml
sap_db2_instance: db2inst1
sap_db2_database: "{{ sap_sid }}"
sap_db2_export_path: /db2/db2inst1/export
sap_db2_swpm_inifile_dir: /sapmedia/SWPM/inifile   # for greenfield shell
```

## SAP HANA migration path

Set `-e sap_database_type=hana` to use `profiles/hana_ha.yml`, playbooks `05` (HANA install), `07` (HSR), HANA backup/SWPM export-import, and HANA Backint on Day 2.

## Examples

```bash
# IBM Db2 (default)
./scripts/azure_add_workloads.sh -g sap-dev -s PRD --database db2
ansible-playbook playbooks/05_database_shell_install.yml -e sap_database_type=db2

# SAP HANA
./scripts/azure_add_workloads.sh -g sap-dev -s PRD --database hana
ansible-playbook playbooks/05_database_shell_install.yml -e sap_database_type=hana
```
