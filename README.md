# Claude Code Plus

> **EXPERIMENTAL** - This project is in early development. Use at your own risk.

Enhancements for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

## Quick Install

```bash
npx claude-code-plus -y
```

Or run interactively to customize what gets installed:

```bash
npx claude-code-plus
```

## What This Does

### 1. Smart Piped Command Handling (Issue [#13340](https://github.com/anthropics/claude-code/issues/13340))

**The limitation:** Claude Code's permission system uses prefix matching on the entire command string. If you allow `Bash(ls:*)` and `Bash(grep:*)`, running `ls | grep foo` still prompts for permission because the full string doesn't start with an allowed prefix.

**What we add:** A PreToolUse hook that parses piped commands using `shfmt`, checks each component individually against your allowed permissions, and auto-approves if all parts match.

### 2. Shell Configuration for Commands (Issue [#7490](https://github.com/anthropics/claude-code/issues/7490))

**The limitation:** Claude Code ignores the `$SHELL` environment variable and always uses the system default shell (`/bin/zsh` on macOS) when executing Bash tool commands. Even launching with `SHELL=/opt/homebrew/bin/bash claude` doesn't help. This means you lose access to your PATH, aliases, and shell-specific configuration.

**What we add:** A shell alias that wraps the `claude` command to set `SHELL` in a way that Claude Code respects, plus configures `env.SHELL` in settings.json for when the upstream fix lands.

## Platform Support

| Platform | Status |
|----------|--------|
| macOS | Fully supported |
| Linux | Fully supported |
| Windows | Use [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install) |

**Windows users:** Install WSL2 and run the installer from within your WSL environment. The hook script requires bash, jq, and shfmt which are Unix tools.

## Requirements

**Required:**
- **Node.js 18+** (for running the installer via npx)

**Auto-installed if missing:**
- **bash 4.4+** (required by the hook script; macOS ships with 3.2)
- **jq** (JSON processor)
- **shfmt** (shell parser)

> The installer will automatically detect missing dependencies and offer to install them using your system's package manager (Homebrew, apt, dnf, pacman, or apk).

<details>
<summary>Manual installation (if needed)</summary>

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

### Interactive Installation (Recommended)

Simply run:

```bash
npx claude-code-plus
```

You'll be prompted to choose between:
1. **Recommended** - Installs everything with sensible defaults
2. **Custom** - Choose which features to install

### Non-Interactive Installation

For scripting or automation:

```bash
npx claude-code-plus -y
```

This installs everything with defaults (modern bash, hook, permissions).

### Custom Shell

In the **Custom** installation mode, you can choose to use a different shell instead of modern bash. When prompted, enter either:
- A shell name (e.g., `zsh`) - will be resolved using `which`
- A full path (e.g., `/opt/homebrew/bin/zsh`)

> **⚠️ Shell Compatibility:** Claude Code currently only works reliably with **bash** and **zsh**. Other shells like fish, nushell, etc. are not yet supported due to upstream limitations in how Claude Code spawns shell processes. If you choose a non-bash/zsh shell, you can verify it's working by running `!echo $SHELL` inside Claude Code (the `!` prefix runs commands in Claude's configured shell).

### Help

```bash
npx claude-code-plus --help
```

## Chezmoi Integration

The installer **automatically detects** if chezmoi manages your `~/.claude` directory:

- Writes to chezmoi's source directory instead of `~/.claude` directly
- Uses `executable_` prefix for hook files
- Detects chezmoi-managed shell config files (`.bashrc`, `.zshrc`, etc.)
- Prompts to run `chezmoi apply` at the end

No special flags needed - it just works!

## What Gets Installed

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Updated with shell config, hook config, and permissions |
| `~/.claude/hooks/auto-approve-allowed-commands.sh` | The hook script that enables piped command auto-approval |
| `~/.bashrc`, `~/.bash_profile`, `~/.zshrc`, `~/.config/fish/config.fish` | Shell alias added (workaround for shell bug). Note: fish config is modified for future compatibility, but fish is not yet supported by Claude Code. |

## Safe Permissions Added

The installer adds auto-approval for 850+ permission entries covering 350+ commands:

- **File & text:** `ls`, `cat`, `head`, `tail`, `file`, `stat`, `wc`, `find`, `fd`, `grep`, `rg`, `awk`, `sed`, `sort`, `uniq`, `cut`, `tr`, `jq`, `yq`
- **Git:** `git status`, `git diff`, `git log`, `git branch`, `git fetch`, `git show`, `git blame`, etc. (read-only)
- **GitHub CLI:** `gh pr list`, `gh issue view`, `gh repo view`, `gh run list`, etc. (read-only)
- **System info:** `date`, `whoami`, `uname`, `env`, `ps`, `df`, `du`, `top`, `uptime`
- **Languages:** `node`, `python`, `ruby`, `go`, `rust`, `java`, `php`, `elixir`, `haskell`, `scala`, `kotlin`, `lua`, `R`, etc. (version/info commands)
- **Package managers:** `npm`, `yarn`, `pnpm`, `bun`, `pip`, `poetry`, `cargo`, `gem`, `bundle`, `composer`, `maven`, `gradle`, `brew`, `conda` (read-only)
- **Cloud CLIs:** `aws`, `az`, `gcloud` (read-only: `list`, `describe`, `show`)
- **DevOps:** `docker`, `kubectl`, `helm`, `terraform`, `ansible`, `vagrant`, `pulumi` (read-only)
- **Databases:** `psql`, `mysql`, `sqlite3`, `mongo`, `redis-cli` (read-only)
- **Editors/tools:** `code`, `vim`, `nvim`, `bat`, `delta`, `fzf`, `tmux` (read-only)

See [src/permissions.ts](src/permissions.ts) for the full list.

## How the Hook Works

1. Claude Code calls a Bash command
2. The PreToolUse hook intercepts it
3. The hook parses the command using `shfmt` to extract individual commands
4. Each command is checked against your allowed permissions
5. If ALL components match allowed prefixes, the command is auto-approved
6. Otherwise, falls through to normal permission prompting

This means `ls -la | grep foo | head -5` gets auto-approved when you have `Bash(ls:*)`, `Bash(grep:*)`, and `Bash(head:*)` in your permissions.

The hook reads permissions from:
- **Global:** `~/.claude/settings.json`
- **Project:** `.claude/settings.json` and `.claude/settings.local.json`

### Supported Shell Syntax

The parser handles:
- Pipes: `cmd1 | cmd2 | cmd3`
- And/Or: `cmd1 && cmd2 || cmd3`
- Semicolons: `cmd1; cmd2`
- Subshells: `(cmd1; cmd2) | cmd3`
- Command substitution: `echo $(cmd1 | cmd2)`
- `bash -c` / `sh -c`: recursively expanded
- For/while loops: extracts inner commands

## Security Notes

### Intentionally Excluded Permissions

The following are **not** included in default permissions because they can execute arbitrary code:

- `xargs` - runs commands from input
- `python -c`, `node -e`, `ruby -e` - inline code execution
- `eval`, `source` - execute arbitrary strings/files
- `find -exec` - runs commands on matched files

If you add these manually, understand the risks.

## Uninstall

```bash
# Remove the hook
rm ~/.claude/hooks/auto-approve-allowed-commands.sh

# Remove the shell alias from your shell config files
# Look for lines after "# Added by claude-code-plus for shell alias"

# Edit ~/.claude/settings.json to:
# - Remove the hook config from .hooks.PreToolUse
# - Remove any unwanted permissions from .permissions.allow
# (or just delete ~/.claude/settings.json to reset everything)
```

## Contributing

Issues and PRs welcome!

## License

MIT
