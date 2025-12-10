# Better Claude Code

Fixes and enhancements for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/AbdelrahmanHafez/better-claude-code/main/install | bash
```

Or clone and run locally:

```bash
git clone https://github.com/AbdelrahmanHafez/better-claude-code.git
cd better-claude-code
./install all
```

## What This Fixes

### 1. Piped Commands Not Auto-Approved (Issue [#13340](https://github.com/anthropics/claude-code/issues/13340))

**Problem:** Claude Code's permission system uses prefix matching on the entire command string. If you allow `Bash(ls:*)` and `Bash(grep:*)`, running `ls | grep foo` still prompts for permission because the full string doesn't start with an allowed prefix.

**Solution:** A PreToolUse hook that parses piped commands using `shfmt`, checks each component individually against your allowed permissions, and auto-approves if all parts match.

### 2. Custom Shell Not Respected (Issue [#7490](https://github.com/anthropics/claude-code/issues/7490))

**Problem:** Claude Code ignores the `$SHELL` environment variable and always uses the system default shell (`/bin/zsh` on macOS). This breaks PATH, aliases, and environment for Fish/Bash users.

**Solution:** Sets the `SHELL` environment variable in Claude's settings, which Claude Code does respect.

## Requirements

- macOS (Linux support planned)

The installer will automatically install these dependencies if missing (via Homebrew):
- **Homebrew** itself (prompts to install if missing)
- `bash` 4.4+ (macOS ships with 3.2)
- `jq` (JSON processor)
- `shfmt` (shell parser)

## Usage

### Full Installation (Recommended)

```bash
./install all
```

This will:
1. Check and install dependencies (including Homebrew if needed)
2. Configure your preferred shell
3. Install the auto-approve-allowed-commands hook
4. Add safe command permissions

### Individual Commands

```bash
# Check/install dependencies only
./install dependencies

# Configure shell (auto-detects from $SHELL)
./install shell

# Or specify a shell explicitly
./install shell --shell /opt/homebrew/bin/fish

# Install the piped-commands hook
./install hook

# Add safe read-only command permissions
./install permissions
```

### Custom .claude Directory

For users with dotfiles managers (chezmoi, etc.), you can specify a custom directory:

```bash
# Install to a custom location
./install --claude-dir ~/dotfiles/dot_claude all

# Short form
./install -d ~/dotfiles/dot_claude all

# Works with all subcommands
./install -d ~/my-claude-config hook
./install -d ~/my-claude-config permissions
```

The hook script will be configured to read settings from your custom directory.

### Hook Filename Prefix (for chezmoi)

If you use chezmoi and need the hook file to have a prefix (e.g., `executable_` to make it automatically executable):

```bash
# Creates: ~/dotfiles/dot_claude/hooks/executable_auto-approve-allowed-commands.sh
./install -d ~/dotfiles/dot_claude -p executable_ all

# Or long form
./install --claude-dir ~/dotfiles/dot_claude --hook-prefix executable_ all
```

The settings.json will still reference `$HOME/.claude/hooks/auto-approve-allowed-commands.sh` (the path after chezmoi applies the dotfiles).

### Help

```bash
./install --help
./install <command> --help
```

## What Gets Installed

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Updated with shell config, hook config, and permissions |
| `~/.claude/hooks/auto-approve-allowed-commands.sh` | The hook script that enables piped command auto-approval |

(Paths change if using `--claude-dir`)

## Safe Permissions Added

The `permissions` command adds auto-approval for ~80 read-only commands:

- **File inspection:** `ls`, `cat`, `head`, `tail`, `file`, `stat`, `wc`
- **Search:** `find`, `fd`, `grep`, `rg`, `awk`, `sed`
- **Text processing:** `sort`, `uniq`, `cut`, `tr`, `jq`
- **Git (read-only):** `git status`, `git diff`, `git log`, `git branch`, `git fetch`
- **System info:** `date`, `whoami`, `uname`, `env`, `ps`

See [src/lib/permissions.sh](src/lib/permissions.sh) for the full list.

## How the Hook Works

1. Claude Code calls a Bash command
2. The PreToolUse hook intercepts it
3. The hook parses the command using `shfmt` to extract individual commands
4. Each command is checked against your allowed permissions
5. If ALL components match allowed prefixes, the command is auto-approved
6. Otherwise, falls through to normal permission prompting

This means `ls -la | grep foo | head -5` gets auto-approved when you have `Bash(ls:*)`, `Bash(grep:*)`, and `Bash(head:*)` in your permissions.

### Supported Shell Syntax

The parser handles:
- Pipes: `cmd1 | cmd2 | cmd3`
- And/Or: `cmd1 && cmd2 || cmd3`
- Semicolons: `cmd1; cmd2`
- Subshells: `(cmd1; cmd2) | cmd3`
- Command substitution: `echo $(cmd1 | cmd2)`
- `bash -c` / `sh -c`: recursively expanded

## Uninstall

```bash
# Remove the hook
rm ~/.claude/hooks/auto-approve-allowed-commands.sh

# Optionally, remove the hook config from settings.json
# (or just delete ~/.claude/settings.json to reset everything)
```

## Contributing

Issues and PRs welcome!

## License

MIT
