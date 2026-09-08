#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "${test_dir}"' EXIT
asset="${test_dir}/one.msix"
printf 'test asset\n' > "${asset}"

curl() {
  local method="GET"
  local output=""
  local url=""
  local headers=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --request)
        method="$2"
        shift 2
        ;;
      --output)
        output="$2"
        shift 2
        ;;
      --write-out|--header|--data|--data-binary)
        if [[ "$1" == "--header" ]]; then
          headers="${headers} $2"
        fi
        shift 2
        ;;
      --silent|--show-error|--location)
        shift
        ;;
      *)
        url="$1"
        shift
        ;;
    esac
  done

  printf '%s\t%s\t%s\n' "${method}" "${url}" "${headers}" \
    >> "${MOCK_DIR}/calls"

  local status
  local response
  case "${method} ${url}" in
    "GET "*"/releases/tags/"*)
      case "${MOCK_SCENARIO}" in
        published)
          status=200
          response='{"id":1,"draft":false,"assets":[],"upload_url":"https://uploads.test/releases/1/assets{?name,label}"}'
          ;;
        draft)
          status=200
          response='{"id":1,"draft":true,"assets":[{"id":9,"name":"one.msix"}],"upload_url":"https://uploads.test/releases/1/assets{?name,label}"}'
          ;;
        missing)
          status=404
          response='{"message":"Not Found"}'
          ;;
      esac
      ;;
    "POST "*"/releases")
      status=201
      response='{"id":1,"draft":true,"assets":[],"upload_url":"https://uploads.test/releases/1/assets{?name,label}"}'
      ;;
    "DELETE "*"/assets/"*)
      status=204
      response=''
      ;;
    "POST "*"/assets?name="*)
      status=201
      response='{"id":2,"name":"one.msix"}'
      ;;
    "PATCH "*"/releases/1")
      status=200
      response='{"id":1,"draft":false}'
      ;;
    *)
      echo "Unexpected mock request: ${method} ${url}" >&2
      return 1
      ;;
  esac

  printf '%s' "${response}" > "${output}"
  printf '%s' "${status}"
}
export -f curl

run_publisher() {
  local provider="$1"
  local scenario="$2"
  local server_url="$3"
  local runtime="${4:-github}"
  local case_dir="${test_dir}/${provider}-${scenario}-${runtime}"
  mkdir -p "${case_dir}"

  MOCK_DIR="${case_dir}" MOCK_SCENARIO="${scenario}" \
    GITEA_ACTIONS="$([[ "${runtime}" == "gitea" ]] && printf true || printf false)" \
    CI_PROVIDER="${provider}" CI_SERVER_URL="${server_url}" \
    CI_REPOSITORY="acme/archive" CI_TOKEN="test-token" \
    bash "${repo_root}/scripts/publish-release.sh" \
      "codex-win-v1.2.3.4" "v1.2.3.4" "Test release" \
      "0123456789abcdef" "${asset}" \
      > "${case_dir}/output"
}

run_publisher github published "https://github.com"
[[ "$(wc -l < "${test_dir}/github-published-github/calls" | tr -d ' ')" == "1" ]]
rg -q 'already exists; skipping upload' "${test_dir}/github-published-github/output"

run_publisher github missing "https://github.com"
rg -Fq $'POST\thttps://api.github.com/repos/acme/archive/releases\t' \
  "${test_dir}/github-missing-github/calls"
rg -Fq 'Authorization: Bearer test-token' "${test_dir}/github-missing-github/calls"
rg -Fq $'POST\thttps://uploads.test/releases/1/assets?name=one.msix\t' \
  "${test_dir}/github-missing-github/calls"
rg -q 'Published release codex-win-v1.2.3.4' \
  "${test_dir}/github-missing-github/output"

run_publisher gitea draft "https://gitea.test"
rg -Fq $'GET\thttps://gitea.test/api/v1/repos/acme/archive/releases/tags/' \
  "${test_dir}/gitea-draft-github/calls"
rg -Fq 'Authorization: token test-token' "${test_dir}/gitea-draft-github/calls"
rg -Fq $'DELETE\thttps://gitea.test/api/v1/repos/acme/archive/releases/1/assets/9\t' \
  "${test_dir}/gitea-draft-github/calls"
rg -q 'Published release codex-win-v1.2.3.4' \
  "${test_dir}/gitea-draft-github/output"

run_publisher auto missing "https://gitea.test" gitea
rg -Fq $'POST\thttps://gitea.test/api/v1/repos/acme/archive/releases\t' \
  "${test_dir}/auto-missing-gitea/calls"
rg -Fq 'Authorization: token test-token' \
  "${test_dir}/auto-missing-gitea/calls"

echo "release publisher contract tests: passed"
