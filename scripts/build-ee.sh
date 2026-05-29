#!/usr/bin/env bash
# Build and push sap-migration-ee to the AAP internal registry.
# Requires: podman (or docker), .env populated, Automation Hub token set.
#
# Usage:
#   source scripts/load-env.sh
#   ./scripts/build-ee.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

# shellcheck disable=SC1090
source "${ROOT}/scripts/load-env.sh"

EE_NAME="${AAP_EE_NAME:-sap-migration-ee}"
EE_IMAGE="${AAP_EE_IMAGE:-34.205.23.227/demo/sap-migration-ee:latest}"
EE_BASE="${AAP_EE_BASE_IMAGE:-34.205.23.227/ee-minimal-rhel9:latest}"
EE_DIR="${ROOT}/execution-environment"
PLATFORM="${PODMAN_DEFAULT_PLATFORM:-linux/amd64}"

CONTAINER_CMD="${CONTAINER_CMD:-}"
if [[ -z "${CONTAINER_CMD}" ]]; then
  if command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD=podman
  elif command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD=docker
  else
    echo "ERROR: need podman or docker" >&2; exit 1
  fi
fi

if [[ -z "${ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN:-}" ]]; then
  echo "ERROR: set ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN in .env" >&2
  exit 1
fi

# ── Stage certified collections on laptop (Hub token) ─────────────────────────
_STAGING="${EE_DIR}/.collections-staging"
rm -rf "${_STAGING}"
mkdir -p "${_STAGING}"
echo "Staging collections from Automation Hub..."
export ANSIBLE_CONFIG="${ROOT}/execution-environment/ansible.cfg"

# Stage Hub-certified collections using env vars (no ansible.cfg patching needed)
export ANSIBLE_GALAXY_SERVER_LIST="automation_hub,release_galaxy"
export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_URL="https://console.redhat.com/api/automation-hub/content/published/"
export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_AUTH_URL="https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token"
export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN="${ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN}"
export ANSIBLE_GALAXY_SERVER_RELEASE_GALAXY_URL="https://galaxy.ansible.com/"
export ANSIBLE_GALAXY_SERVER_RELEASE_GALAXY_IGNORE_ERRORS=true
# Avoid picking up any ansible.cfg that might have stale URLs
unset ANSIBLE_CONFIG

_HUB_REQS="${EE_DIR}/.requirements-hub.yml"
cat > "${_HUB_REQS}" <<'EOF'
collections:
  - name: redhat.sap_install
  - name: sap.sap_operations
  - name: azure.azcollection
  - name: google.cloud
  - name: ansible.platform
  - name: community.general
  - name: community.sap_libs
EOF
ansible-galaxy collection install -r "${_HUB_REQS}" -p "${_STAGING}" --force
rm -f "${_HUB_REQS}" 2>/dev/null || true

# Bundle the local acme.sap_migration collection
cp -r "${ROOT}/collections/ansible_collections/acme" \
      "${_STAGING}/ansible_collections/acme"

echo "Staged collections:"
ansible-galaxy collection list -p "${_STAGING}" | grep -v "^#\|^$" | head -20
# (staging complete)

# ── Pull base image ───────────────────────────────────────────────────────────
REGISTRY="${EE_IMAGE%%/*}"
if [[ -n "${CONTROLLER_USERNAME:-}" && -n "${CONTROLLER_PASSWORD:-}" ]]; then
  echo "Logging in to ${REGISTRY}..."
  echo "${CONTROLLER_PASSWORD}" | \
    "${CONTAINER_CMD}" login "${REGISTRY}" -u "${CONTROLLER_USERNAME}" \
    --password-stdin --tls-verify=false 2>/dev/null \
    || echo "${CONTROLLER_PASSWORD}" | \
       "${CONTAINER_CMD}" login "${REGISTRY}" -u "${CONTROLLER_USERNAME}" --password-stdin
fi

echo "Pulling base image ${EE_BASE}..."
"${CONTAINER_CMD}" pull --tls-verify=false --platform "${PLATFORM}" "${EE_BASE}" 2>/dev/null \
  || "${CONTAINER_CMD}" pull --platform "${PLATFORM}" "${EE_BASE}"

# ── Build ─────────────────────────────────────────────────────────────────────
echo "Building ${EE_IMAGE} (platform ${PLATFORM})..."
"${CONTAINER_CMD}" build --no-cache \
  --platform "${PLATFORM}" \
  -f "${EE_DIR}/Containerfile.sap-migration-ee" \
  -t "${EE_IMAGE}" \
  "${EE_DIR}"

# ── Verify ────────────────────────────────────────────────────────────────────
echo "Verifying collections in built image..."
"${CONTAINER_CMD}" run --rm "${EE_IMAGE}" \
  ansible-galaxy collection list 2>/dev/null | grep -E "azure|google|sap|acme" || true

# ── Push ──────────────────────────────────────────────────────────────────────
echo "Pushing to ${REGISTRY}..."
"${CONTAINER_CMD}" push --tls-verify=false "${EE_IMAGE}" 2>/dev/null \
  || "${CONTAINER_CMD}" push "${EE_IMAGE}"

echo ""
echo "Done: ${EE_NAME} → ${EE_IMAGE}"
echo "Register in AAP: ./scripts/setup-aap.sh --tags execution_environment"
