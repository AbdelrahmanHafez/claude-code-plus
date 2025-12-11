# Claude Code Plus

[![npm version](https://img.shields.io/npm/v/claude-code-plus.svg)](https://www.npmjs.com/package/claude-code-plus)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Node.js Version](https://img.shields.io/node/v/claude-code-plus.svg)](https://nodejs.org)

Enhancements for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI that fix common pain points and add quality-of-life improvements.

## Quick Install

```bash
npx claude-code-plus -y
```

Or run interactively to customize what gets installed:

```bash
npx claude-code-plus
```

## Features

### Smart Piped Command Handling

**The problem:** Claude Code's permission system uses prefix matching. If you allow `Bash(ls:*)` and `Bash(grep:*)`, running `ls | grep foo` still prompts for permission because the full string doesn't match any single prefix.

**The solution:** A PreToolUse hook that parses piped commands using `shfmt`, checks each component individually against your allowed permissions, and auto-approves if all parts match.

> Related: [anthropics/claude-code#13340](https://github.com/anthropics/claude-code/issues/13340)

### Shell Configuration Fix

**The problem:** Claude Code ignores the `$SHELL` environment variable and always uses the system default shell (`/bin/zsh` on macOS). This means you lose access to your PATH, aliases, and shell-specific configuration.

**The solution:** A shell alias that wraps the `claude` command to set `SHELL` correctly, plus `env.SHELL` configuration in settings.json.

> Related: [anthropics/claude-code#7490](https://github.com/anthropics/claude-code/issues/7490)

### 850+ Safe Permissions

Pre-configured auto-approval for common read-only commands:

- **File & text:** `ls`, `cat`, `head`, `tail`, `grep`, `rg`, `fd`, `jq`, `yq`
- **Git:** `git status`, `git diff`, `git log`, `git branch`, `git show` (read-only)
- **GitHub CLI:** `gh pr list`, `gh issue view`, `gh repo view` (read-only)
- **Package managers:** `npm`, `yarn`, `pnpm`, `pip`, `cargo`, `gem`, `brew` (info commands)
- **Cloud CLIs:** `aws`, `az`, `gcloud` (list/describe/show)
- **DevOps:** `docker`, `kubectl`, `helm`, `terraform` (read-only)

See [src/permissions.ts](src/permissions.ts) for the complete list.

## Platform Support

| Platform | Status |
|----------|--------|
| macOS | Fully supported |
| Linux | Fully supported |
| Windows | Use [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install) |

## Requirements

- **Node.js 18+** (for npx)

The installer will automatically detect and offer to install missing dependencies:
- **bash 4.4+** (macOS ships with 3.2)
- **jq** (JSON processor)
- **shfmt** (shell parser)

<details>
<summary>Manual installation</summary>

**macOS:**
```bash
brew install bash jq shfmt
```

**Linux (Debian/Ubuntu):**
```bash
apt install bash jq shfmt
```

**Linux (Fedora/RHEL):**
```bash
dnf install bash jq shfmt
```

**Linux (Arch):**
```bash
pacman -S bash jq shfmt
```

</details>

## Usage

### Interactive Mode (Recommended)

```bash
npx claude-code-plus
```

Choose between:
1. **Recommended** - Installs everything with sensible defaults
2. **Custom** - Pick which features to install

### Non-Interactive Mode

```bash
npx claude-code-plus -y
```

### Custom Shell

In Custom mode, you can specify a different shell:
- A shell name (e.g., `zsh`) - resolved via `which`
- A full path (e.g., `/opt/homebrew/bin/zsh`)

> **Note:** Claude Code currently works reliably with **bash** and **zsh** only. Other shells may have limited compatibility.

## What Gets Installed

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Shell config, hook config, and permissions |
| `~/.claude/hooks/auto-approve-allowed-commands.sh` | Hook for piped command auto-approval |
| Shell configs (`.bashrc`, `.zshrc`, etc.) | Shell alias (workaround for shell bug) |

## Chezmoi Integration

The installer automatically detects if chezmoi manages your `~/.claude` directory:

- Writes to chezmoi's source directory
- Uses `executable_` prefix for hook files
- Prompts to run `chezmoi apply` at the end

No configuration needed.

## How the Hook Works

1. Claude Code invokes a Bash command
2. The PreToolUse hook intercepts it
3. `shfmt` parses the command into components
4. Each component is checked against allowed permissions
5. If ALL match, the command is auto-approved
6. Otherwise, normal permission prompting applies

### Supported Syntax

- Pipes: `cmd1 | cmd2 | cmd3`
- And/Or: `cmd1 && cmd2 || cmd3`
- Semicolons: `cmd1; cmd2`
- Subshells: `(cmd1; cmd2) | cmd3`
- Command substitution: `echo $(cmd1 | cmd2)`
- `bash -c` / `sh -c`: recursively expanded
- Loops: extracts inner commands

## Security

### Intentionally Excluded

The following are **not** included in default permissions because they can execute arbitrary code:

- `xargs` - runs commands from input
- `python -c`, `node -e`, `ruby -e` - inline code execution
- `eval`, `source` - execute arbitrary strings/files
- `find -exec` - runs commands on matched files

## Uninstall

```bash
# Remove the hook
rm ~/.claude/hooks/auto-approve-allowed-commands.sh

# Remove shell alias (look for "# Added by claude-code-plus" in your shell configs)

# Edit ~/.claude/settings.json to remove:
# - The hook config from .hooks.PreToolUse
# - Any unwanted permissions from .permissions.allow
```

## Contributing

Issues and PRs welcome!

## License

[MIT](LICENSE)
