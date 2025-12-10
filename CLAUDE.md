# Better Claude Code - Project Guide

This file helps Claude Code understand the project structure and development workflow.

## Project Overview

Better Claude Code is an installer that enhances Claude Code CLI. It addresses two main issues:

1. **Piped commands not auto-approved** ([#13340](https://github.com/anthropics/claude-code/issues/13340)) - Fixed via a PreToolUse hook
2. **Custom shell not respected** ([#7490](https://github.com/anthropics/claude-code/issues/7490)) - Fixed via settings.json env config

## Project Structure

```
better-claude/
├── install.sh           # Generated single-file installer (DO NOT EDIT DIRECTLY)
├── README.md            # User documentation
├── CLAUDE.md            # This file
├── test/
│   ├── test_helper.bash # Common test helpers and assertions
│   └── install.bats     # All installer tests
└── src/
    ├── bashly.yml       # Bashly CLI configuration (flags, args)
    ├── root_command.sh  # Main installer logic
    └── lib/             # Shared helper functions
        ├── colors.sh    # Terminal output helpers (info, success, error, etc.)
        ├── deps.sh      # Dependency checking and installation
        ├── settings.sh  # Claude settings.json manipulation + hook config
        ├── hook_script.sh # Generates the auto-approve-allowed-commands.sh hook content
        └── permissions.sh # Default safe Bash permissions list
```

## Development Workflow

### Building

This project uses [bashly](https://bashly.dev) to generate a single executable from modular source files.

```bash
# Generate the installer
/opt/homebrew/lib/ruby/gems/3.4.0/bin/bashly generate
# Or with Docker:
docker run --rm -v "$PWD:/app" dannyben/bashly generate

# Test the installer
./install.sh --help
./install.sh
```

### Code Style

- **Step-down style**: `main()` at the top, helper functions below in order of abstraction
- **Section comments**: Use `# --- Section Name ---` to group related functions
- **Error handling**: Use `|| true` after arithmetic operations like `((count++))` to avoid exit code issues with `set -e`
- **Private functions**: Prefix with `_` for functions not meant to be called externally

### Key Design Decisions

1. **Single file output**: The `install.sh` script is self-contained for easy `curl | bash` distribution
2. **Homebrew dependency**: We rely on Homebrew for macOS package management (prompts to install if missing)
3. **Modern bash default**: Defaults to Homebrew's bash 4.4+ instead of macOS's ancient bash 3.2
4. **Configurable paths**: `--claude-dir` flag allows installation to custom directories (for dotfiles managers)
5. **Hook filename prefix**: `--hook-prefix` flag adds a prefix to the hook filename (e.g., `executable_` for chezmoi)
6. **Separate file path vs settings path**: The hook file can have a prefix, but settings.json always references `$HOME/.claude/hooks/auto-approve-allowed-commands.sh` (the runtime path after dotfiles are applied)

### Testing

**IMPORTANT:** Always test against a `/tmp/` directory, never against the real `~/.claude`. This prevents accidentally corrupting your actual Claude Code configuration.

#### Automated Tests (bats)

This project uses [bats-core](https://github.com/bats-core/bats-core) for automated testing.

```bash
# Install bats-core (if not already installed)
brew install bats-core

# Run all tests
bats test/

# Run tests with verbose output
bats --verbose-run test/
```

Test file: `test/install.bats` - All installer tests (shell, hook, permissions, idempotency, etc.)

Each test creates a fresh temp directory (`$TEST_DIR`) and cleans it up after, so tests are isolated and safe.

#### Manual Testing

Use `CLAUDE_DIR_OVERRIDE` environment variable to test against a temp directory instead of your real `~/.claude`:

```bash
# Test with custom directory (ALWAYS use /tmp for testing)
CLAUDE_DIR_OVERRIDE=/tmp/test-claude ./install.sh -y

# Test with custom shell
CLAUDE_DIR_OVERRIDE=/tmp/test-claude ./install.sh -y --shell /bin/zsh

# Clean up after testing
rm -rf /tmp/test-claude
```

### Adding New Permissions

Edit `src/lib/permissions.sh` and add entries to the `DEFAULT_PERMISSIONS` array:

```bash
DEFAULT_PERMISSIONS=(
  # ... existing permissions ...
  "Bash(new-command:*)"
)
```

Then regenerate with bashly.

## Dependencies

**Build time:**
- bashly (Ruby gem or Docker)

**Runtime (installed automatically):**
- Homebrew
- bash 4.4+
- jq
- shfmt

## Code Migration Workflows

These workflows help you review changes more easily by leveraging git diffs.

### File Migration Workflow
**When moving code from one file to another, NEVER rewrite the code manually. Use `cp` command first, then modify.**

#### The Problem
When an LLM moves code from file A to file B by rewriting it, the user must review line-by-line to verify no unintended changes were made. This is time-consuming and error-prone because the entire file appears as "new" in git diff.

#### The Solution
Use a two-step workflow that leverages git as a verification tool:

**Step 1: Copy the file**
```bash
cp src/old-location/file.sh src/new-location/file.sh
```

**Step 2: Prompt user to stage so you can continue**
- Stop and inform the user the file has been copied
- Ask the user to stage the copied file with `git add` and let you know when to continue
- User verifies the copy is identical (git will show it as a new file with original content)
- User says "continue"

**Step 3: Modify the copied file**
- Now modify the new file to achieve the desired changes
- Git diff will show ONLY the modifications, not a complete rewrite
- User only needs to review the actual changes

### Code Snippet Migration Workflow
**When extracting/moving code snippets (>15 lines), NEVER manually copy the code. Use CLI tools for mechanical extraction.**

**Step 1: Extract using CLI tools**
```bash
# Append to end of existing file
sed -n '45,95p' src/old-file.sh >> src/target-file.sh

# Create brand new file with extracted code
sed -n '45,95p' src/old-file.sh > src/new-file.sh
```

**Step 2: Prompt user to stage so you can continue**
- Stop and inform the user the code has been extracted
- Ask the user to stage the changes with `git add` and let you know when to continue

**Step 3: Modify the extracted code**
- Now modify the extracted code (wrap in function, remove unwanted bits, etc.)
- Git diff shows only the actual modifications

#### When to Use These Approaches
- Moving code from one file to another
- Extracting functions (>15 lines)
- Refactoring large chunks of code
- Any code movement where verification is important

#### When NOT to Use These Approaches
- Writing completely new code (nothing to copy)
- Small extractions (<15 lines) - just use Edit tool
- Making small edits to existing files (use Edit tool)

## Related Issues

- [#13340](https://github.com/anthropics/claude-code/issues/13340) - Piped commands permission bug
- [#7490](https://github.com/anthropics/claude-code/issues/7490) - Custom shell not respected
