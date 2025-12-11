# Test Files Review Checklist

Review each test file for correctness and coverage.

## Test Helper
- [ ] `test/hook/hook_test_helper.bash` - Helper functions for all hook tests

## Parsing Tests (Command Extraction)
- [x] `test/hook/parsing_basic.bats` - Pipes, chaining, comments, multi-line (53 tests)
- [x] `test/hook/parsing_special_chars.bats` - Colons, quoted strings (38 tests)
- [ ] `test/hook/parsing_string_safety.bats` - String content safety (26 tests)
- [ ] `test/hook/parsing_control_flow.bats` - Subshells, loops, conditionals (31 tests)
- [ ] `test/hook/parsing_bash_c.bats` - bash -c recursive unwrapping (23 tests)
- [ ] `test/hook/parsing_env_redirect.bats` - Environment variables, redirections (30 tests)
- [ ] `test/hook/parsing_builtins.bats` - Builtins, functions, paths (48 tests)
- [ ] `test/hook/parsing_xargs_find.bats` - xargs and find -exec (34 tests)

## Permission Tests
- [ ] `test/hook/permission_matching.bats` - Prefix matching edge cases (29 tests)

## Integration Tests
- [ ] `test/hook/real_world.bats` - Complex real-world commands (58 tests)
- [ ] `test/hook/security.bats` - Dangerous command blocking (27 tests)
- [ ] `test/hook/edge_cases.bats` - Malformed input, shfmt behaviors (48 tests)

## Related Documents
- [ ] `HOOK_TEST_CASES.md` - Test case specifications
- [ ] `HOOK_SECURITY_REPORT.md` - Security findings and recommendations
