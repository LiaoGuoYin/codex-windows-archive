# CoinDemo

GitHub Actions workflow for archiving Codex installers.

The `Archive Codex Installers` workflow downloads the official x64 and Arm64
MSIX packages daily at 12:00 Asia/Shanghai (04:00 UTC), records the package
version and SHA-256 checksums, and stores them in GitHub artifact storage for
30 days. It can also be started manually from the repository's **Actions** page,
where the output directory and architecture can be selected.

The core flow can run outside CI on any Bash environment with `curl`, `unzip`,
and `sha256sum` installed:

在 Windows 本地下载时，请使用 Git Bash 运行下面的命令，不要直接使用
PowerShell。单个安装包的下载超时时间为 30 分钟。

```bash
bash ./scripts/download-codex-installers.sh [output-directory] [x64|arm64 ...]
```

Open the repository's **Actions** page, select **Archive Codex Installers**, then use
**Run workflow** to select a ref and provide the workflow inputs.
