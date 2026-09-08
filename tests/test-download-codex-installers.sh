#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "${test_dir}"' EXIT
mkdir -p "${test_dir}/bin"

cat > "${test_dir}/bin/mock-command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$(basename "$0")" in
  curl)
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--output" ]]; then
        printf 'mock package\n' > "$2"
        exit 0
      fi
      shift
    done
    ;;
  unzip)
    printf '<Identity Version="%s" />\n' "${MOCK_VERSION}"
    ;;
  sha256sum)
    printf '0000000000000000000000000000000000000000000000000000000000000000  %s\n' "$1"
    ;;
esac
EOF
chmod +x "${test_dir}/bin/mock-command"
ln -s mock-command "${test_dir}/bin/curl"
ln -s mock-command "${test_dir}/bin/unzip"
ln -s mock-command "${test_dir}/bin/sha256sum"

PATH="${test_dir}/bin:${PATH}" MOCK_VERSION="1.2.3.4" \
  bash "${repo_root}/scripts/download-codex-installers.sh" \
    "${test_dir}/valid" x64 > "${test_dir}/valid-output"
[[ -f "${test_dir}/valid/ChatGPT-x64-1.2.3.4.msix" ]]
rg -q $'^x64\t1\.2\.3\.4\t' "${test_dir}/valid/manifest.tsv"
rg -q '  ChatGPT-x64-1\.2\.3\.4\.msix$' "${test_dir}/valid/SHA256SUMS"
! rg -q "${test_dir}" "${test_dir}/valid/SHA256SUMS"

if PATH="${test_dir}/bin:${PATH}" MOCK_VERSION="../../outside" \
  bash "${repo_root}/scripts/download-codex-installers.sh" \
    "${test_dir}/invalid" x64 > "${test_dir}/invalid-output" 2>&1; then
  echo "Invalid package version unexpectedly succeeded" >&2
  exit 1
fi
rg -q 'Invalid package version' "${test_dir}/invalid-output"
[[ ! -e "${test_dir}/outside.msix" ]]
[[ ! -e "${test_dir}/invalid/.ChatGPT-x64.msix.download" ]]

echo "download script tests: passed"
