import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import {
  getHookFilepath,
  ensureHooksDir,
  getHookScriptContent,
  installHook,
  configureHookInSettings
} from './hooks.js';
import { getSettings } from './settings.js';

describe('hooks', function() {
  let testDir: string;
  const originalEnv = process.env.CLAUDE_DIR_OVERRIDE;

  beforeEach(function() {
    testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-hooks-test-'));
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
    const hooksDir = path.join(testDir, 'hooks');
    const hookFilename = 'auto-approve-allowed-commands.sh';
    return { hooksDir, hookFilename, testDir };
  }

  describe('getHookFilepath()', function() {
    it('returns path in hooks directory', function() {
      // Arrange
      createTestContext();

      // Act
      const filepath = getHookFilepath();

      // Assert
      expect(filepath).toContain('hooks');
      expect(filepath).toContain('auto-approve-allowed-commands.sh');
    });

    it('returns path under test directory when override is set', function() {
      // Arrange
      const { testDir } = createTestContext();

      // Act
      const filepath = getHookFilepath();

      // Assert
      expect(filepath.startsWith(testDir)).toBe(true);
    });
  });

  describe('ensureHooksDir()', function() {
    it('creates hooks directory if it does not exist', function() {
      // Arrange
      const { hooksDir } = createTestContext();
      expect(fs.existsSync(hooksDir)).toBe(false);

      // Act
      ensureHooksDir();

      // Assert
      expect(fs.existsSync(hooksDir)).toBe(true);
    });

    it('does nothing if hooks directory already exists', function() {
      // Arrange
      const { hooksDir } = createTestContext();
      fs.mkdirSync(hooksDir, { recursive: true });

      // Act & Assert - should not throw
      ensureHooksDir();

      expect(fs.existsSync(hooksDir)).toBe(true);
    });
  });

  describe('getHookScriptContent()', function() {
    it('returns non-empty script content', function() {
      // Act
      const content = getHookScriptContent();

      // Assert
      expect(content).toBeTruthy();
      expect(content.length).toBeGreaterThan(100);
    });

    it('returns script with shebang', function() {
      // Act
      const content = getHookScriptContent();

      // Assert
      expect(content.startsWith('#!/usr/bin/env bash')).toBe(true);
    });

    it('contains expected hook functionality markers', function() {
      // Act
      const content = getHookScriptContent();

      // Assert
      expect(content).toContain('shfmt');
      expect(content).toContain('jq');
      expect(content).toContain('PreToolUse');
    });
  });

  describe('installHook()', function() {
    it('creates hook file with correct content', function() {
      // Arrange
      createTestContext();
      const hookPath = getHookFilepath();

      // Act
      installHook();

      // Assert
      expect(fs.existsSync(hookPath)).toBe(true);
      const content = fs.readFileSync(hookPath, 'utf-8');
      expect(content.startsWith('#!/usr/bin/env bash')).toBe(true);
    });

    it('creates hook file with executable permissions', function() {
      // Arrange
      createTestContext();
      const hookPath = getHookFilepath();

      // Act
      installHook();

      // Assert
      const stats = fs.statSync(hookPath);
      const mode = stats.mode & 0o777;
      expect(mode & 0o111).toBeGreaterThan(0); // At least one execute bit set
    });

    it('overwrites existing hook file', function() {
      // Arrange
      createTestContext();
      const hookPath = getHookFilepath();
      ensureHooksDir();
      fs.writeFileSync(hookPath, 'old content');

      // Act
      installHook();

      // Assert
      const content = fs.readFileSync(hookPath, 'utf-8');
      expect(content).not.toBe('old content');
      expect(content.startsWith('#!/usr/bin/env bash')).toBe(true);
    });
  });

  describe('configureHookInSettings()', function() {
    it('adds hook configuration to settings.json', function() {
      // Arrange
      createTestContext();

      // Act
      configureHookInSettings();

      // Assert
      const settings = getSettings();
      expect(settings.hooks?.PreToolUse).toBeDefined();
      expect(settings.hooks?.PreToolUse?.length).toBeGreaterThan(0);
    });

    it('configures hook with Bash matcher', function() {
      // Arrange
      createTestContext();

      // Act
      configureHookInSettings();

      // Assert
      const settings = getSettings();
      const bashHook = settings.hooks?.PreToolUse?.find(hook => hook.matcher === 'Bash');
      expect(bashHook).toBeDefined();
    });

    it('does not duplicate hook if already configured', function() {
      // Arrange
      createTestContext();
      configureHookInSettings();
      const settingsBefore = getSettings();
      const hookCountBefore = settingsBefore.hooks?.PreToolUse?.length || 0;

      // Act
      configureHookInSettings();

      // Assert
      const settingsAfter = getSettings();
      expect(settingsAfter.hooks?.PreToolUse?.length).toBe(hookCountBefore);
    });
  });
});
