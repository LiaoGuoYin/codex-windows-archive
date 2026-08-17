# Codex Windows Installer Archive

This repository archives the official Windows MSIX packages distributed for the
Codex desktop app. A scheduled GitHub Actions workflow checks the x64 and Arm64
packages each day and publishes new versions as GitHub Releases.

This is a community-maintained project. It is not affiliated with or endorsed by
OpenAI.

## Download

Open the [Releases](https://github.com/NextSwift/CodexApp-Win-Bot/releases) page
and download `codex-installers-{version}.zip`. Each archive contains:

- Versioned x64 and Arm64 MSIX packages
- `SHA256SUMS` for integrity checks
- `manifest.tsv` with the package version and source URLs
- `README.txt` with verification instructions

Run this command inside the extracted archive to verify both packages:

```bash
sha256sum --check SHA256SUMS
```

## Archive workflow

The `Archive Codex Installers` workflow runs daily at 12:00 Asia/Shanghai
(04:00 UTC). It reads the version from each package's `AppxManifest.xml` and
publishes `codex-installers-{version}.zip` under the
`codex-win-v{version}` release tag.

If a published release already exists for that version, the workflow skips the
upload. If an upload leaves a draft release, the next run retries the bundle
before publishing it. Manual single-architecture runs use architecture-specific
release tags and asset names.

You can also run the workflow from the repository's **Actions** page and select
the target architecture.

## Run locally

The download script requires Bash, `curl`, `unzip`, and `sha256sum`:

```bash
bash ./scripts/download-codex-installers.sh [output-directory] [x64|arm64 ...]
```

On Windows, run the command in Git Bash instead of PowerShell. Each package has
a 30-minute download timeout.

## License

The automation code in this repository is licensed under the [MIT License](LICENSE).
Downloaded installer packages remain subject to their respective terms and are
not covered by this license.
