#!/usr/bin/env bash
# Provision all AAP objects for SAP Azure→GCP Migration
# Usage:
#   source scripts/load-env.sh
#   ./scripts/setup-aap.sh
#   ./scripts/setup-aap.sh --tags credentials,job_templates  # partial re-run
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

# shellcheck disable=SC1090
source "${ROOT}/scripts/load-env.sh"

COLLECTIONS_PATH="${ROOT}/env/lib/python3.14/site-packages/ansible_collections:${ROOT}/collections/ansible_collections"
export ANSIBLE_COLLECTIONS_PATH="${COLLECTIONS_PATH}:${ANSIBLE_COLLECTIONS_PATH:-}"

# Ensure ansible.controller is available (Hub — not on public Galaxy)
if ! ansible-galaxy collection list ansible.controller 2>/dev/null | grep -q 'ansible.controller '; then
  echo "Installing ansible.controller from Automation Hub..." >&2
  if [[ -z "${ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN:-}" ]]; then
    echo "Error: set ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN in .env" >&2
    exit 1
  fi
  ansible-galaxy collection install ansible.controller \
    -p "${ROOT}/collections/ansible_collections" \
    --server "https://console.redhat.com/api/automation-hub/"
fi

set +e
ansible-playbook "${ROOT}/aap/setup_controller.yml" \
  -i localhost, \
  -c local \
  "$@"
rc=$?
set -e

if [[ "${rc}" -ne 0 ]]; then
  echo "" >&2
  echo "AAP setup failed (exit ${rc})." >&2
  echo "  Check .env is populated and sourced (source scripts/load-env.sh)." >&2
  echo "  Partial re-run: ./scripts/setup-aap.sh --tags credentials" >&2
  exit "${rc}"
fi
