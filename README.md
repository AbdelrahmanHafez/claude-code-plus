# Better Claude Code

> **EXPERIMENTAL** - This project is in early development. Use at your own risk.

Enhancements for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

## Quick Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AbdelrahmanHafez/better-claude-code/main/install.sh)"
```

## What This Does

### 1. Smart Piped Command Handling (Issue [#13340](https://github.com/anthropics/claude-code/issues/13340))

**The limitation:** Claude Code's permission system uses prefix matching on the entire command string. If you allow `Bash(ls:*)` and `Bash(grep:*)`, running `ls | grep foo` still prompts for permission because the full string doesn't start with an allowed prefix.

**What we add:** A PreToolUse hook that parses piped commands using `shfmt`, checks each component individually against your allowed permissions, and auto-approves if all parts match.

### 2. Shell Configuration for Commands (Issue [#7490](https://github.com/anthropics/claude-code/issues/7490))

**The limitation:** Claude Code ignores the `$SHELL` environment variable and always uses the system default shell (`/bin/zsh` on macOS) when executing Bash tool commands. Even launching with `SHELL=/opt/homebrew/bin/fish claude` doesn't help. This means you lose access to your PATH, aliases, and shell-specific configuration.

**What we add:** A shell alias that wraps the `claude` command to set `SHELL` in a way that Claude Code respects, plus configures `env.SHELL` in settings.json for when the upstream fix lands.

## Requirements

- macOS (Linux support planned)

The installer will automatically install these dependencies if missing (via Homebrew):
- **Homebrew** itself (prompts to install if missing)
- `bash` 4.4+ (required by the hook script; macOS ships with 3.2)
- `jq` (JSON processor)
- `shfmt` (shell parser)

## Usage

### Interactive Installation (Recommended)

Simply run:

```bash
./install.sh
```

You'll be prompted to choose between:
1. **Recommended** - Installs everything with sensible defaults
2. **Custom** - Choose which features to install

### Non-Interactive Installation

For scripting or automation:

```bash
./install.sh -y
```

This installs everything with defaults (modern bash, hook, permissions).

### Specifying a Shell

By default, the installer uses Homebrew's modern bash. To use a different shell:

```bash
./install.sh --shell /opt/homebrew/bin/fish
./install.sh -s /bin/zsh
```

### Help

```bash
./install.sh --help
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
| `~/.bashrc`, `~/.zshrc`, `~/.config/fish/config.fish` | Shell alias added (workaround for shell bug) |

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

See [src/lib/permissions.sh](src/lib/permissions.sh) for the full list.

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
# Look for lines after "# Added by better-claude-code for shell alias"

# Edit ~/.claude/settings.json to:
# - Remove the hook config from .hooks.PreToolUse
# - Remove any unwanted permissions from .permissions.allow
# (or just delete ~/.claude/settings.json to reset everything)
```

## Contributing

Issues and PRs welcome!

## License

MIT
