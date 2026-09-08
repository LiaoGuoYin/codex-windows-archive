#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 TAG TITLE BODY TARGET ASSET..." >&2
  exit 2
fi

tag="$1"
title="$2"
body="$3"
target="$4"
shift 4
assets=("$@")

: "${CI_SERVER_URL:?CI_SERVER_URL is required}"
: "${CI_REPOSITORY:?CI_REPOSITORY is required}"
: "${CI_TOKEN:?CI_TOKEN is required}"

ci_provider="${CI_PROVIDER:-auto}"
if [[ "${ci_provider}" == "auto" ]]; then
  if [[ "${GITEA_ACTIONS:-}" == "true" ]]; then
    ci_provider="gitea"
  else
    ci_provider="github"
  fi
fi

[[ "${CI_REPOSITORY}" =~ ^[^/]+/[^/]+$ ]] || {
  echo "CI_REPOSITORY must use OWNER/REPO format" >&2
  exit 2
}
for command in curl jq mktemp; do
  command -v "${command}" >/dev/null || {
    echo "Missing required command: ${command}" >&2
    exit 1
  }
done
for asset in "${assets[@]}"; do
  [[ -f "${asset}" ]] || {
    echo "Missing release asset: ${asset}" >&2
    exit 1
  }
done

http_body_file="$(mktemp)"
trap 'rm -f "${http_body_file}"' EXIT
http_status=""

http_request() {
  local method="$1"
  local url="$2"
  shift 2
  http_status="$(curl --silent --show-error --location \
    --request "${method}" --output "${http_body_file}" \
    --write-out '%{http_code}' "$@" "${url}")"
}

require_status() {
  local expected="$1"
  local operation="$2"
  if [[ "${http_status}" != "${expected}" ]]; then
    echo "${operation} failed with HTTP ${http_status}" >&2
    jq -c . "${http_body_file}" >&2 2>/dev/null || sed -n '1,20p' "${http_body_file}" >&2
    exit 1
  fi
}

urlencode() {
  jq -nr --arg value "$1" '$value | @uri'
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${ci_provider}" in
  github|gitea)
    # Provider files implement the shared publish_release contract.
    source "${script_dir}/providers/${ci_provider}.sh"
    ;;
  *)
    echo "Unsupported CI provider: ${ci_provider}" >&2
    exit 2
    ;;
esac

publish_release "${tag}" "${title}" "${body}" "${target}" "${assets[@]}"
