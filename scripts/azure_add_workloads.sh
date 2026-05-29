#!/usr/bin/env bash
# Provision SAP-shaped RHEL workloads on Azure for migration workflow testing.
#
# Requirements:
#   - ansible-playbook, azure.azcollection installed
#   - Azure login: az login (or service principal env vars)
#   - SSH public key at ~/.ssh/id_rsa.pub (or set AZURE_SSH_PUB_FILE)
#
# Examples (default: 1 VM only, min quota profile):
#   ./scripts/azure_add_workloads.sh -g sap-migration-dev -s DEV
#   ./scripts/azure_add_workloads.sh -g sap-migration-dev -s DEV -l westus2
#   ./scripts/azure_add_workloads.sh -g sap-migration-dev --destroy
#   ./scripts/azure_add_workloads.sh -g sap-migration-dev --destroy --delete-resource-group

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COLLECTION_ROOT="${ROOT}/collections/ansible_collections"
PLAYBOOK="${COLLECTION_ROOT}/acme/sap_migration/playbooks/provision_azure_workloads.yml"

RESOURCE_GROUP=""
SAP_SID="DEV"
LOCATION="westus2"
PREFIX="sap-migration"
DATABASE_TYPE="db2"
QUOTA_PROFILE="min"
VM_SIZE=""
ACTION="provision"
DELETE_RG="false"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  echo ""
  echo "Options:"
  echo "  -g, --resource-group   Azure resource group (required)"
  echo "  -s, --sid              SAP system ID for tags (default: DEV)"
  echo "  -l, --location         Azure region (default: westus2; use if eastus has SkuNotAvailable)"
  echo "  -p, --prefix           VM name prefix (default: sap-migration)"
  echo "  -d, --database         db2 | hana (default: db2)"
  echo "  --min-quota            1 VM only (default)"
  echo "  --low-quota            2 VMs: db2 + ASCS"
  echo "  --vm-size SIZE         Override VM size (e.g. Standard_B2ats_v2)"
  echo "  --sap                  Full SAP-shaped sizes (needs ~32 vCPUs in region)"
  echo "  --destroy              Remove workloads (and optionally RG)"
  echo "  --delete-resource-group  With --destroy, delete the entire RG"
  echo "  -h, --help             Show help"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    -s|--sid) SAP_SID="$2"; shift 2 ;;
    -l|--location) LOCATION="$2"; shift 2 ;;
    -p|--prefix) PREFIX="$2"; shift 2 ;;
    -d|--database) DATABASE_TYPE="$2"; shift 2 ;;
    --vm-size) VM_SIZE="$2"; shift 2 ;;
    --min-quota) QUOTA_PROFILE="min"; shift ;;
    --low-quota) QUOTA_PROFILE="low"; shift ;;
    --sap) QUOTA_PROFILE="sap"; shift ;;
    --destroy) ACTION="destroy"; shift ;;
    --delete-resource-group) DELETE_RG="true"; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

if [[ -z "${RESOURCE_GROUP}" ]]; then
  echo "Error: --resource-group is required" >&2
  usage 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook not found in PATH" >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Warning: Azure CLI (az) not found — ensure Azure credentials are configured for Ansible" >&2
fi

export ANSIBLE_COLLECTIONS_PATH="${COLLECTION_ROOT}${ANSIBLE_COLLECTIONS_PATH:+:${ANSIBLE_COLLECTIONS_PATH}}"

EXTRA_VARS=(
  -e "azure_resource_group=${RESOURCE_GROUP}"
  -e "azure_workload_resource_group=${RESOURCE_GROUP}"
  -e "azure_location=${LOCATION}"
  -e "azure_workload_location=${LOCATION}"
  -e "sap_sid=${SAP_SID}"
  -e "migration_name=${PREFIX}"
  -e "azure_workload_prefix=${PREFIX}"
  -e "azure_workload_action=${ACTION}"
  -e "azure_workload_delete_resource_group=${DELETE_RG}"
  -e "sap_database_type=${DATABASE_TYPE}"
  -e "azure_workload_quota_profile=${QUOTA_PROFILE}"
)
if [[ -n "${VM_SIZE}" ]]; then
  EXTRA_VARS+=(
    -e "azure_workload_vm_size_min=${VM_SIZE}"
    -e "azure_workload_vm_size_low=${VM_SIZE}"
    -e "azure_workload_vm_size_fallback=[\"${VM_SIZE}\"]"
  )
fi

# Hint when reusing an eastus RG (common capacity exhaustion on trial subs)
if [[ -n "${RESOURCE_GROUP}" ]] && command -v az >/dev/null 2>&1; then
  EXISTING_LOC="$(az group show -n "${RESOURCE_GROUP}" --query location -o tsv 2>/dev/null || true)"
  if [[ "${EXISTING_LOC}" == "eastus" && "${LOCATION}" != "eastus" ]]; then
    echo "==> Note: RG ${RESOURCE_GROUP} is in eastus; -l ${LOCATION} is ignored. If deploy fails, use:"
    echo "    ./scripts/azure_add_workloads.sh -g sap-migration-west -l westus2 -s ${SAP_SID}"
  fi
fi

echo "==> Action: ${ACTION}"
echo "==> Resource group: ${RESOURCE_GROUP}"
echo "==> Region: ${LOCATION}"
echo "==> SAP SID tag: ${SAP_SID}"
echo "==> Database type: ${DATABASE_TYPE}"
echo "==> Quota profile: ${QUOTA_PROFILE} (min = 1 VM; use --low-quota or --sap for more)"
if [[ -n "${VM_SIZE}" ]]; then
  echo "==> VM size override: ${VM_SIZE}"
fi
echo "==> Playbook: ${PLAYBOOK}"

ansible-playbook "${PLAYBOOK}" "${EXTRA_VARS[@]}"

echo "==> Done."
if [[ "${ACTION}" == "provision" ]]; then
  echo "    Run discovery: ansible-playbook .../01_azure_discovery.yml -e azure_resource_group=${RESOURCE_GROUP}"
fi
