#!/usr/bin/env bash
# Validate repository structure matches the migration plan.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COLLECTION="$ROOT/collections/ansible_collections/acme/sap_migration"

REQUIRED_PLAYBOOKS=(
  00_prerequisites.yml
  01_azure_discovery.yml
  02_gcp_landing_zone.yml
  03_gcp_provision_vms.yml
  04_os_preconfigure.yml
  05_hana_shell_install.yml
  05_database_shell_install.yml
  06_nw_shell_install.yml
  07_ha_cluster_build.yml
  08_system_copy_export.yml
  09_transfer_to_gcs.yml
  10_system_copy_import.yml
  11_validate_cutover.yml
  12_azure_decommission.yml
  day2_operations.yml
  provision_azure_workloads.yml
)

REQUIRED_ROLES=(
  azure_discovery
  gcp_landing_zone
  gcp_sap_vm
  system_copy_export
  system_copy_import
  cutover
  day2_operations
  azure_workload_provision
  db2_shell_install
  db2_hadr_setup
)

echo "==> Checking playbooks"
for pb in "${REQUIRED_PLAYBOOKS[@]}"; do
  [[ -f "$COLLECTION/playbooks/$pb" ]] || { echo "MISSING playbook: $pb"; exit 1; }
  echo "  OK $pb"
done

echo "==> Checking roles"
for role in "${REQUIRED_ROLES[@]}"; do
  [[ -f "$COLLECTION/roles/$role/tasks/main.yml" ]] || { echo "MISSING role: $role"; exit 1; }
  echo "  OK $role"
done

echo "==> Checking execution environment"
[[ -f "$ROOT/execution-environment/execution-environment.yml" ]] || exit 1
[[ -f "$ROOT/execution-environment/requirements.yml" ]] || exit 1
echo "  OK execution-environment"

echo "==> Checking AAP workflow definition"
[[ -f "$ROOT/aap/workflow_job_template.yml" ]] || exit 1
echo "  OK workflow_job_template.yml"

echo ""
echo "All structure checks passed."
