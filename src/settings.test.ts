import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import {
  getSettings,
  saveSettings,
  setEnvVar,
  addPermission,
  hasPermission,
  addPermissions,
  addHook,
  hasHook,
  ensureClaudeDir
} from './settings.js';

describe('settings', function() {
  let testDir: string;
  const originalEnv = process.env.CLAUDE_DIR_OVERRIDE;

  beforeEach(function() {
    testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-test-'));
    process.env.CLAUDE_DIR_OVERRIDE = testDir;
  });

  afterEach(function() {
    fs.rmSync(testDir, { recursive: true, force: true });
    if (originalEnv === undefined) {
      delete process.env.CLAUDE_DIR_OVERRIDE;
    } else {
      process.env.CLAUDE_DIR_OVERRIDE = originalEnv;
    }
  });

  function createTestContext() {
    const settingsPath = path.join(testDir, 'settings.json');
    return { settingsPath, testDir };
  }

  describe('ensureClaudeDir()', function() {
    it('creates directory if it does not exist', function() {
      // Arrange
      const { testDir } = createTestContext();
      const newDir = path.join(testDir, 'subdir');
      process.env.CLAUDE_DIR_OVERRIDE = newDir;

      // Act
      ensureClaudeDir();

      // Assert
      expect(fs.existsSync(newDir)).toBe(true);
    });

    it('does nothing if directory already exists', function() {
      // Arrange
      const { testDir } = createTestContext();

      // Act & Assert - should not throw
      ensureClaudeDir();
      ensureClaudeDir();

      expect(fs.existsSync(testDir)).toBe(true);
    });
  });

  describe('getSettings()', function() {
    it('returns empty object when settings.json does not exist', function() {
      // Arrange - no settings file created

      // Act
      const settings = getSettings();

      // Assert
      expect(settings).toEqual({});
    });

    it('returns parsed settings when file exists', function() {
      // Arrange
      const { settingsPath } = createTestContext();
      const testSettings = { env: { SHELL: '/bin/bash' } };
      fs.writeFileSync(settingsPath, JSON.stringify(testSettings));

      // Act
      const settings = getSettings();

      // Assert
      expect(settings).toEqual(testSettings);
    });
  });

  describe('saveSettings()', function() {
    it('creates settings.json with provided content', function() {
      // Arrange
      const { settingsPath } = createTestContext();
      const testSettings = { env: { SHELL: '/bin/bash' } };

      // Act
      saveSettings(testSettings);

      // Assert
      const content = fs.readFileSync(settingsPath, 'utf-8');
      expect(JSON.parse(content)).toEqual(testSettings);
    });

    it('overwrites existing settings', function() {
      // Arrange
      const { settingsPath } = createTestContext();
      fs.writeFileSync(settingsPath, JSON.stringify({ old: 'value' }));

      // Act
      saveSettings({ new: 'value' });

      // Assert
      const content = fs.readFileSync(settingsPath, 'utf-8');
      expect(JSON.parse(content)).toEqual({ new: 'value' });
    });
  });

  describe('setEnvVar()', function() {
    it('sets environment variable in settings', function() {
      // Arrange
      createTestContext();

      // Act
      setEnvVar('SHELL', '/bin/bash');

      // Assert
      const settings = getSettings();
      expect(settings.env?.SHELL).toBe('/bin/bash');
    });

    it('preserves existing env vars when adding new one', function() {
      // Arrange
      createTestContext();
      setEnvVar('FIRST', 'first-value');

      // Act
      setEnvVar('SECOND', 'second-value');

      // Assert
      const settings = getSettings();
      expect(settings.env?.FIRST).toBe('first-value');
      expect(settings.env?.SECOND).toBe('second-value');
    });

    it('overwrites existing env var with same name', function() {
      // Arrange
      createTestContext();
      setEnvVar('SHELL', '/bin/zsh');

      // Act
      setEnvVar('SHELL', '/bin/bash');

      // Assert
      const settings = getSettings();
      expect(settings.env?.SHELL).toBe('/bin/bash');
    });
  });

  describe('addPermission()', function() {
    it('adds permission to empty settings', function() {
      // Arrange
      createTestContext();

      // Act
      const result = addPermission('Bash(ls:*)');

      // Assert
      expect(result).toBe(true);
      expect(hasPermission('Bash(ls:*)')).toBe(true);
    });

    it('returns false when permission already exists', function() {
      // Arrange
      createTestContext();
      addPermission('Bash(ls:*)');

      // Act
      const result = addPermission('Bash(ls:*)');

      // Assert
      expect(result).toBe(false);
    });

    it('adds multiple different permissions', function() {
      // Arrange
      createTestContext();

      // Act
      addPermission('Bash(ls:*)');
      addPermission('Bash(grep:*)');

      // Assert
      expect(hasPermission('Bash(ls:*)')).toBe(true);
      expect(hasPermission('Bash(grep:*)')).toBe(true);
    });
  });

  describe('hasPermission()', function() {
    it('returns false when no permissions exist', function() {
      // Arrange
      createTestContext();

      // Act
      const result = hasPermission('Bash(ls:*)');

      // Assert
      expect(result).toBe(false);
    });

    it('returns true when permission exists', function() {
      // Arrange
      createTestContext();
      addPermission('Bash(ls:*)');

      // Act
      const result = hasPermission('Bash(ls:*)');

      // Assert
      expect(result).toBe(true);
    });

    it('returns false for non-existent permission', function() {
      // Arrange
      createTestContext();
      addPermission('Bash(ls:*)');

      // Act
      const result = hasPermission('Bash(rm:*)');

      // Assert
      expect(result).toBe(false);
    });
  });

  describe('addPermissions()', function() {
    it('adds multiple permissions at once', function() {
      // Arrange
      createTestContext();
      const permissions = ['Bash(ls:*)', 'Bash(grep:*)', 'Bash(cat:*)'];

      // Act
      const count = addPermissions(permissions);

      // Assert
      expect(count).toBe(3);
      expect(hasPermission('Bash(ls:*)')).toBe(true);
      expect(hasPermission('Bash(grep:*)')).toBe(true);
      expect(hasPermission('Bash(cat:*)')).toBe(true);
    });

    it('returns count of actually added permissions (skips duplicates)', function() {
      // Arrange
      createTestContext();
      addPermission('Bash(ls:*)');

      // Act
      const count = addPermissions(['Bash(ls:*)', 'Bash(grep:*)', 'Bash(cat:*)']);

      // Assert
      expect(count).toBe(2); // ls was already there
    });

    it('returns 0 when all permissions already exist', function() {
      // Arrange
      createTestContext();
      addPermissions(['Bash(ls:*)', 'Bash(grep:*)']);

      // Act
      const count = addPermissions(['Bash(ls:*)', 'Bash(grep:*)']);

      // Assert
      expect(count).toBe(0);
    });
  });

  describe('addHook()', function() {
    it('adds hook to empty settings', function() {
      // Arrange
      createTestContext();
      const hookConfig = {
        matcher: 'Bash',
        hooks: [{ type: 'command' as const, command: '$HOME/.claude/hooks/my-hook.sh' }]
      };

      // Act
      const result = addHook(hookConfig);

      // Assert
      expect(result).toBe(true);
      expect(hasHook('$HOME/.claude/hooks/my-hook.sh')).toBe(true);
    });

    it('merges hooks with same matcher', function() {
      // Arrange
      createTestContext();
      addHook({ matcher: 'Bash', hooks: [{ type: 'command', command: 'hook1.sh' }] });

      // Act
      addHook({ matcher: 'Bash', hooks: [{ type: 'command', command: 'hook2.sh' }] });

      // Assert
      const settings = getSettings();
      const bashHook = settings.hooks?.PreToolUse?.find(hook => hook.matcher === 'Bash');
      expect(bashHook?.hooks.some(hook => hook.command === 'hook1.sh')).toBe(true);
      expect(bashHook?.hooks.some(hook => hook.command === 'hook2.sh')).toBe(true);
    });

    it('does not duplicate hook paths', function() {
      // Arrange
      createTestContext();
      addHook({ matcher: 'Bash', hooks: [{ type: 'command', command: 'hook1.sh' }] });

      // Act
      addHook({ matcher: 'Bash', hooks: [{ type: 'command', command: 'hook1.sh' }] });

      // Assert
      const settings = getSettings();
      const bashHook = settings.hooks?.PreToolUse?.find(hook => hook.matcher === 'Bash');
      expect(bashHook?.hooks.filter(hook => hook.command === 'hook1.sh').length).toBe(1);
    });

    it('adds separate entries for different matchers', function() {
      // Arrange
      createTestContext();
      addHook({ matcher: 'Bash', hooks: [{ type: 'command', command: 'bash-hook.sh' }] });

      // Act
      addHook({ matcher: 'Read', hooks: [{ type: 'command', command: 'read-hook.sh' }] });

      // Assert
      const settings = getSettings();
      expect(settings.hooks?.PreToolUse?.length).toBe(2);
      expect(hasHook('bash-hook.sh')).toBe(true);
      expect(hasHook('read-hook.sh')).toBe(true);
    });
  });

  describe('hasHook()', function() {
    it('returns false when no hooks exist', function() {
      // Arrange
      createTestContext();

      // Act
      const result = hasHook('some-hook.sh');

      // Assert
      expect(result).toBe(false);
    });

    it('returns true when hook exists', function() {
      // Arrange
      createTestContext();
      addHook({ matcher: 'Bash', hooks: [{ type: 'command', command: 'my-hook.sh' }] });

      // Act
      const result = hasHook('my-hook.sh');

      // Assert
      expect(result).toBe(true);
    });

    it('returns false for non-existent hook', function() {
      // Arrange
      createTestContext();
      addHook({ matcher: 'Bash', hooks: [{ type: 'command', command: 'existing-hook.sh' }] });

      // Act
      const result = hasHook('non-existent-hook.sh');

      // Assert
      expect(result).toBe(false);
    });
  });
});
