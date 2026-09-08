#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:-archive}"
shift || true
architectures=("$@")
if [[ ${#architectures[@]} -eq 0 ]]; then
  architectures=(x64 arm64)
fi

for command in curl unzip sha256sum; do
  command -v "${command}" >/dev/null || {
    echo "Missing required command: ${command}" >&2
    exit 1
  }
done

mkdir -p "${output_dir}"
: > "${output_dir}/SHA256SUMS"
: > "${output_dir}/manifest.tsv"

for arch in "${architectures[@]}"; do
  case "${arch}" in
    x64|arm64)
      url="https://persistent.oaistatic.com/codex-app-prod/ChatGPT-${arch}.msix"
      ;;
    *)
      echo "Unsupported architecture: ${arch} (use x64 or arm64)" >&2
      exit 2
      ;;
  esac

  package="${output_dir}/.ChatGPT-${arch}.msix.download"
  if ! curl --fail --location --retry 3 --retry-delay 5 \
    --connect-timeout 30 --max-time 1800 \
    "${url}" --output "${package}"; then
    rm -f "${package}"
    exit 1
  fi

  version="$(unzip -p "${package}" AppxManifest.xml \
    | sed -n 's/.*Identity[^>]*Version="\([^"]*\)".*/\1/p' \
    | head -n 1)"
  [[ -n "${version}" ]] || {
    echo "Unable to read package version from ${package}" >&2
    rm -f "${package}"
    exit 1
  }
  if [[ ! "${version}" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
    echo "Invalid package version in ${package}: ${version}" >&2
    rm -f "${package}"
    exit 1
  fi

  archived="ChatGPT-${arch}-${version}.msix"
  mv "${package}" "${output_dir}/${archived}"
  (
    cd "${output_dir}"
    sha256sum "${archived}" >> SHA256SUMS
  )
  printf '%s\t%s\t%s\n' "${arch}" "${version}" "${url}" \
    >> "${output_dir}/manifest.tsv"
done

cat > "${output_dir}/README.txt" <<'EOF'
These MSIX packages were downloaded from the official Codex installer URLs.
Verify SHA-256 with: sha256sum --check SHA256SUMS
EOF

echo "Downloaded ${#architectures[@]} package(s) into ${output_dir}"
