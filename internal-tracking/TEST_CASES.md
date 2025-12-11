# Test Cases

This file documents test cases for the **installer**. For hook/command parsing test cases, see [HOOK_TEST_CASES.md](./HOOK_TEST_CASES.md).

---

## Installer Tests

### Dependencies command

| Test | Expected | Status |
|------|----------|--------|
| Shows success when all deps installed | Output contains "All dependencies are installed" | ? |
| Checks for Homebrew | Output mentions Homebrew | ? |
| Checks for bash version | Output mentions bash | ? |
| Checks for jq | Output mentions jq | ? |
| Checks for shfmt | Output mentions shfmt | ? |

### Shell command

| Test | Expected | Status |
|------|----------|--------|
| Creates settings.json | File exists | ? |
| Sets SHELL env in settings | `.env.SHELL` is set and not null | ? |
| Uses custom shell when specified | `--shell /bin/bash` sets that path | ? |
| Fails for non-existent shell | Non-zero exit, error message | ? |
| Reports already configured on second run | Output contains "already configured" | ? |
| Updates shell when changed | Second run with different shell updates value | ? |
| Accepts shell name instead of path | `--shell bash` resolves to full path | ? |
| Accepts shell path directly | `--shell /opt/homebrew/bin/bash` used as-is | ? |

### Hook command

| Test | Expected | Status |
|------|----------|--------|
| Creates hooks directory | Directory exists | ? |
| Creates hook file | File exists | ? |
| Hook file is executable | Has +x permission | ? |
| Hook file has correct shebang | First line is `#!/usr/bin/env bash` | ? |
| Hook file has CLAUDE_DIR baked in | Contains `CLAUDE_DIR="$TEST_DIR"` | ? |
| Creates hook with prefix | `-p executable_` creates prefixed file | ? |
| Prefixed hook is executable | Prefixed file has +x | ? |
| Configures hook in settings.json | `.hooks.PreToolUse` exists | ? |
| Settings reference non-prefixed path | Command path doesn't contain prefix | ? |
| Reports already configured on second run | Output contains "already" | ? |
| Preserves existing hooks | Other matchers (Read, Write) not deleted | ✓ |
| Appends to existing Bash matcher | Doesn't create duplicate entries | ✓ |

### Permissions command

| Test | Expected | Status |
|------|----------|--------|
| Creates settings.json | File exists | ? |
| Adds permissions array | `.permissions.allow` has items | ? |
| Includes basic commands | Contains `Bash(ls:*)`, `Bash(cat:*)`, etc. | ? |
| Includes git read-only commands | Contains `Bash(git status:*)`, etc. | ? |
| Includes jq | Contains `Bash(jq:*)` | ? |
| Reports already configured on second run | Output contains "already" | ? |
| Does not duplicate on second run | Array length unchanged | ? |
| Preserves existing permissions | Custom permissions not deleted | ? |

### All command

| Test | Expected | Status |
|------|----------|--------|
| Creates settings.json | File exists | ? |
| Creates hooks directory | Directory exists | ? |
| Creates hook file | File exists | ? |
| Hook file is executable | Has +x permission | ? |
| Configures shell | `.env.SHELL` is set | ? |
| Configures hook in settings | `.hooks.PreToolUse` exists | ? |
| Adds permissions | `.permissions.allow` has items | ? |
| Shows completion message | Output contains "Installation Complete" | ? |
| Second run succeeds (idempotent) | Exit code 0 | ? |
| Respects custom directory | `-d /tmp/custom` uses that path | ? |
| Respects hook prefix | `-p executable_` creates prefixed file | ? |

### Input validation

| Test | Expected | Status |
|------|----------|--------|
| Y/n prompt accepts Y | Proceeds | ? |
| Y/n prompt accepts y | Proceeds | ? |
| Y/n prompt accepts N | Declines | ? |
| Y/n prompt accepts n | Declines | ? |
| Y/n prompt rejects other input | Re-prompts | ? |
| Y/n prompt rejects empty input | Re-prompts (not treated as Y) | ? |

---

## Hook Configuration

### Multiple Bash matchers in PreToolUse

**Question:** Does Claude Code handle multiple PreToolUse entries with the same matcher?

**Test:** Configure settings.json with two Bash matcher entries and verify both hooks run.

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "hook1.sh" }] },
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "hook2.sh" }] }
    ]
  }
}
```

**Expected:** Both hooks execute for Bash commands.

**Alternative:** Should we merge into a single Bash matcher instead?

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "hook1.sh" },
          { "type": "command", "command": "hook2.sh" }
        ]
      }
    ]
  }
}
```

---

### Hook path formats

**Question:** What path formats does Claude Code support for hook commands?

| Format | Example | Test Result |
|--------|---------|-------------|
| `$HOME` expansion | `$HOME/.claude/hooks/auto-approve-allowed-commands.sh` | ? |
| Tilde expansion | `~/.claude/hooks/auto-approve-allowed-commands.sh` | ? |
| Relative to settings.json | `./hooks/auto-approve-allowed-commands.sh` | ? |
| Relative to home | `.claude/hooks/auto-approve-allowed-commands.sh` | ? |
| Absolute path | `/Users/hafez/.claude/hooks/auto-approve-allowed-commands.sh` | ? |

---

## Parity Tests

Compare behavior between:
1. Original `~/dotfiles/dot_claude/hooks/executable_auto-approve-allowed-commands.sh`
2. Generated hook from this installer

Results must match exactly for all test cases in [HOOK_TEST_CASES.md](./HOOK_TEST_CASES.md).
