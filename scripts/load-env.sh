#!/usr/bin/env bash
# Load .env for SAP Azure→GCP migration scripts.
# Usage: source scripts/load-env.sh

_script="${BASH_SOURCE[0]:-$0}"
ROOT="$(cd "$(dirname "${_script}")/.." && pwd)"

ENV_FILE="${ROOT}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}" >&2
  echo "  cp ${ROOT}/.env.example ${ENV_FILE}" >&2
  return 1 2>/dev/null || exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

# Strip trailing slash from controller host
CONTROLLER_HOST="${CONTROLLER_HOST%/}"
export CONTROLLER_HOST

# Auto-disable SSL verify for IP-based controllers
if [[ "${AAP_VERIFY_SSL:-true}" == "true" && "${CONTROLLER_HOST}" =~ ^https?://[0-9]{1,3}(\.[0-9]{1,3}){3}(/|$) ]]; then
  echo "NOTE: ${CONTROLLER_HOST} is an IP — using AAP_VERIFY_SSL=false" >&2
  export AAP_VERIFY_SSL=false
fi
export CONTROLLER_VERIFY_SSL="${AAP_VERIFY_SSL:-false}"

# Expand GCP credential paths
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  GOOGLE_APPLICATION_CREDENTIALS="${GOOGLE_APPLICATION_CREDENTIALS/#\~/$HOME}"
  export GOOGLE_APPLICATION_CREDENTIALS
fi
if [[ -n "${GCP_SERVICE_ACCOUNT_FILE:-}" ]]; then
  GCP_SERVICE_ACCOUNT_FILE="${GCP_SERVICE_ACCOUNT_FILE/#\~/$HOME}"
  export GCP_SERVICE_ACCOUNT_FILE
fi
export GCP_AUTH_KIND="${GCP_AUTH_KIND:-application}"

# Expand SSH key path
if [[ -n "${SSH_PRIVATE_KEY_FILE:-}" ]]; then
  SSH_PRIVATE_KEY_FILE="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
  export SSH_PRIVATE_KEY_FILE
  if [[ -f "${SSH_PRIVATE_KEY_FILE}" ]]; then
    _key_mode="$(stat -f '%A' "${SSH_PRIVATE_KEY_FILE}" 2>/dev/null || stat -c '%a' "${SSH_PRIVATE_KEY_FILE}" 2>/dev/null)"
    if [[ "${_key_mode}" != "600" ]]; then
      echo "Warning: chmod 600 ${SSH_PRIVATE_KEY_FILE} (current: ${_key_mode})" >&2
    fi
  fi
fi

echo ""
echo "SAP Azure→GCP migration env:"
echo "  CONTROLLER_HOST=${CONTROLLER_HOST}"
echo "  CONTROLLER_OAUTH_TOKEN=${CONTROLLER_OAUTH_TOKEN:+set}"
echo "  AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID:+set}"
echo "  GCP_PROJECT=${GCP_PROJECT:-unset}"
echo "  GCP_AUTH_KIND=${GCP_AUTH_KIND:-application}"
echo "  GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS:+set}"
echo "  SAP_SID=${SAP_SID:-unset}"
echo ""
