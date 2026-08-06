#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:-archive}"
shift || true
architectures=("$@")
if [[ ${#architectures[@]} -eq 0 ]]; then
  architectures=(x64 arm64)
fi

declare -A urls=(
  [x64]="https://persistent.oaistatic.com/codex-app-prod/ChatGPT-x64.msix"
  [arm64]="https://persistent.oaistatic.com/codex-app-prod/ChatGPT-arm64.msix"
)

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
  [[ -n "${urls[$arch]:-}" ]] || {
    echo "Unsupported architecture: ${arch} (use x64 or arm64)" >&2
    exit 2
  }

  package="ChatGPT-${arch}.msix"
  curl --fail --location --retry 3 --retry-delay 5 \
    --connect-timeout 30 --max-time 1800 \
    "${urls[$arch]}" --output "${package}"

  version="$(unzip -p "${package}" AppxManifest.xml \
    | sed -n 's/.*Identity[^>]*Version="\([^"]*\)".*/\1/p' \
    | head -n 1)"
  [[ -n "${version}" ]] || {
    echo "Unable to read package version from ${package}" >&2
    exit 1
  }

  archived="ChatGPT-${arch}-${version}.msix"
  mv "${package}" "${output_dir}/${archived}"
  sha256sum "${output_dir}/${archived}" >> "${output_dir}/SHA256SUMS"
  printf '%s\t%s\t%s\n' "${arch}" "${version}" "${urls[$arch]}" \
    >> "${output_dir}/manifest.tsv"
done

cat > "${output_dir}/README.txt" <<'EOF'
These MSIX packages were downloaded from the official Codex installer URLs.
Verify SHA-256 with: sha256sum --check SHA256SUMS
EOF

echo "Downloaded ${#architectures[@]} package(s) into ${output_dir}"
