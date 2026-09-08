# Codex Windows Installer Archive

This repository archives the official Windows MSIX packages distributed for the
Codex desktop app. A shared workflow runs on GitHub Actions and Gitea Actions,
checks the x64 and Arm64 packages each day, and publishes new versions as
Releases.

This is a community-maintained project. It is not affiliated with or endorsed by
OpenAI.

## Download

Open the Releases page on the GitHub or Gitea repository where the workflow
runs. The [GitHub Releases](https://github.com/NextSwift/codex-windows-archive/releases)
page is the public archive for this repository. Each release provides these
assets:

- Versioned x64 and Arm64 MSIX packages
- `SHA256SUMS` for integrity checks
- `manifest.tsv` with the package version and source URLs
- `README.txt` with verification instructions

Run this command in the directory containing the downloaded release assets to
verify both packages:

```bash
sha256sum --check SHA256SUMS
```

## Archive workflow

The workflow in `.github/workflows/` runs daily at 12:00 Asia/Shanghai (04:00
UTC). GitHub and Gitea call the same provider-neutral archive script. The script
reads the version from each package's `AppxManifest.xml` and uploads the x64 and
Arm64 MSIX packages as separate assets under the
`codex-win-v{version}` release tag. The checksum, manifest, and verification
instructions are published alongside the packages.

If a published release already exists for that version, the workflow skips the
upload. If an upload leaves a draft release, the next run retries the assets
before publishing it. Manual single-architecture runs use architecture-specific
release tags and asset names.

You can also run the workflow from the repository's **Actions** page and select
the target architecture.

## CI support

GitHub Actions uses the built-in `GITHUB_TOKEN` with `contents: write`. No
repository secret is required.

The initial Gitea Actions integration targets Gitea 1.26 or newer. Gitea's
default workflow directory configuration discovers `.github/workflows/`; an
administrator who overrides `WORKFLOW_DIRS` must keep that directory enabled.
It also expects:

- Repository Actions enabled
- An `ubuntu-latest` runner with Bash, `curl`, `jq`, `unzip`, and `sha256sum`
- The built-in job token allowed to write repository contents and Releases
- A Release attachment size limit large enough for each MSIX package

Gitea administrators can map `ubuntu-latest` to a different runner image, but
that image must provide the listed commands. If both hosting services run the
schedule, each one publishes to its own repository's Releases.
Gitea currently ignores the workflow `concurrency` setting, so avoid starting a
manual run while the scheduled run is still active.

The shared archive entry point receives provider details through environment
variables:

```text
CI_PROVIDER=auto|github|gitea
CI_SERVER_URL=https://host.example
CI_REPOSITORY=owner/repository
CI_COMMIT_SHA=<commit>
CI_TOKEN=<job-token>
OUTPUT_DIR=archive
ARCHITECTURES=both|x64|arm64
```

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
