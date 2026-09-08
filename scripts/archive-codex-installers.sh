#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="${OUTPUT_DIR:-archive}"
architecture="${ARCHITECTURES:-both}"

case "${architecture}" in
  both)
    architecture_args=()
    release_stem="codex-win"
    expected_packages=2
    ;;
  x64|arm64)
    architecture_args=("${architecture}")
    release_stem="codex-win-${architecture}"
    expected_packages=1
    ;;
  *)
    echo "Unsupported architecture selection: ${architecture}" >&2
    exit 2
    ;;
esac

bash "${script_dir}/download-codex-installers.sh" \
  "${output_dir}" "${architecture_args[@]}"

version="$(cut -f2 "${output_dir}/manifest.tsv" | sort -u)"
if [[ -z "${version}" || "${version}" == *$'\n'* ]]; then
  echo "Expected one package version, found: ${version}" >&2
  exit 1
fi
if [[ ! "${version}" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
  echo "Invalid package version: ${version}" >&2
  exit 1
fi

shopt -s nullglob
msix_assets=("${output_dir}"/*.msix)
shopt -u nullglob
if [[ ${#msix_assets[@]} -ne ${expected_packages} ]]; then
  echo "Expected ${expected_packages} MSIX package(s), found ${#msix_assets[@]}" >&2
  exit 1
fi

assets=(
  "${msix_assets[@]}"
  "${output_dir}/SHA256SUMS"
  "${output_dir}/manifest.tsv"
  "${output_dir}/README.txt"
)
for asset in "${assets[@]}"; do
  [[ -f "${asset}" ]] || {
    echo "Missing release asset: ${asset}" >&2
    exit 1
  }
done

tag="${release_stem}-v${version}"
title="v${version}"
body="Archived from the official Codex Windows installer URLs."

bash "${script_dir}/publish-release.sh" \
  "${tag}" "${title}" "${body}" "${CI_COMMIT_SHA:?CI_COMMIT_SHA is required}" \
  "${assets[@]}"
