import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { configureShellAlias, getSourceCommand } from './shell-alias.js';

describe('shell-alias', function() {
  let testDir: string;
  const originalHome = process.env.HOME;
  const originalShell = process.env.SHELL;

  beforeEach(function() {
    testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-shell-test-'));
    process.env.HOME = testDir;
  });

  afterEach(function() {
    fs.rmSync(testDir, { recursive: true, force: true });
    process.env.HOME = originalHome;
    process.env.SHELL = originalShell;
  });

  function createTestContext(options: { shells?: string[] } = {}) {
    const shells = options.shells || ['bash', 'zsh'];
    const configFiles: Record<string, string> = {};

    if (shells.includes('bash')) {
      const bashrc = path.join(testDir, '.bashrc');
      fs.writeFileSync(bashrc, '# existing bashrc content\n');
      configFiles.bashrc = bashrc;
    }

    if (shells.includes('zsh')) {
      const zshrc = path.join(testDir, '.zshrc');
      fs.writeFileSync(zshrc, '# existing zshrc content\n');
      configFiles.zshrc = zshrc;
    }

    if (shells.includes('fish')) {
      const fishDir = path.join(testDir, '.config', 'fish');
      fs.mkdirSync(fishDir, { recursive: true });
      const fishConfig = path.join(fishDir, 'config.fish');
      fs.writeFileSync(fishConfig, '# existing fish config\n');
      configFiles.fish = fishConfig;
    }

    return { testDir, configFiles };
  }

  describe('configureShellAlias()', function() {
    it('adds alias to existing .bashrc', function() {
      // Arrange
      const { configFiles } = createTestContext({ shells: ['bash'] });
      const shellPath = '/opt/homebrew/bin/bash';

      // Act
      configureShellAlias(shellPath);

      // Assert
      const content = fs.readFileSync(configFiles.bashrc, 'utf-8');
      expect(content).toContain('# Added by claude-code-plus');
      expect(content).toContain(`SHELL="${shellPath}"`);
      expect(content).toContain('command claude');
    });

    it('adds alias to existing .zshrc', function() {
      // Arrange
      const { configFiles } = createTestContext({ shells: ['zsh'] });
      const shellPath = '/opt/homebrew/bin/bash';

      // Act
      configureShellAlias(shellPath);

      // Assert
      const content = fs.readFileSync(configFiles.zshrc, 'utf-8');
      expect(content).toContain('# Added by claude-code-plus');
      expect(content).toContain(`SHELL="${shellPath}"`);
    });

    it('adds fish function to existing config.fish', function() {
      // Arrange
      const { configFiles } = createTestContext({ shells: ['fish'] });
      const shellPath = '/opt/homebrew/bin/bash';

      // Act
      configureShellAlias(shellPath);

      // Assert
      const content = fs.readFileSync(configFiles.fish, 'utf-8');
      expect(content).toContain('# Added by claude-code-plus');
      expect(content).toContain('function claude');
      expect(content).toContain(`SHELL="${shellPath}"`);
      expect(content).toContain('$argv');
    });

    it('does not modify non-existent config files', function() {
      // Arrange
      createTestContext({ shells: [] }); // No shell configs created
      const shellPath = '/opt/homebrew/bin/bash';

      // Act
      configureShellAlias(shellPath);

      // Assert - no error thrown, and no files created
      expect(fs.existsSync(path.join(testDir, '.bashrc'))).toBe(false);
      expect(fs.existsSync(path.join(testDir, '.zshrc'))).toBe(false);
    });

    it('does not duplicate alias if already present with same shell', function() {
      // Arrange
      const { configFiles } = createTestContext({ shells: ['bash'] });
      const shellPath = '/opt/homebrew/bin/bash';
      configureShellAlias(shellPath);
      const contentBefore = fs.readFileSync(configFiles.bashrc, 'utf-8');
      const markerCount = (contentBefore.match(/# Added by claude-code-plus/g) || []).length;

      // Act
      configureShellAlias(shellPath);

      // Assert
      const contentAfter = fs.readFileSync(configFiles.bashrc, 'utf-8');
      const markerCountAfter = (contentAfter.match(/# Added by claude-code-plus/g) || []).length;
      expect(markerCountAfter).toBe(markerCount);
    });

    it('updates alias when shell path changes', function() {
      // Arrange
      const { configFiles } = createTestContext({ shells: ['bash'] });
      const oldShellPath = '/opt/homebrew/bin/bash';
      const newShellPath = '/usr/local/bin/fish';
      configureShellAlias(oldShellPath);

      // Act
      configureShellAlias(newShellPath);

      // Assert
      const content = fs.readFileSync(configFiles.bashrc, 'utf-8');
      expect(content).toContain(`SHELL="${newShellPath}"`);
      expect(content).not.toContain(`SHELL="${oldShellPath}"`);
      // Should only have one marker (replaced, not duplicated)
      const markerCount = (content.match(/# Added by claude-code-plus/g) || []).length;
      expect(markerCount).toBe(1);
    });

    it('adds aliases to multiple shell configs', function() {
      // Arrange
      const { configFiles } = createTestContext({ shells: ['bash', 'zsh', 'fish'] });
      const shellPath = '/bin/bash';

      // Act
      configureShellAlias(shellPath);

      // Assert
      expect(fs.readFileSync(configFiles.bashrc, 'utf-8')).toContain('# Added by claude-code-plus');
      expect(fs.readFileSync(configFiles.zshrc, 'utf-8')).toContain('# Added by claude-code-plus');
      expect(fs.readFileSync(configFiles.fish, 'utf-8')).toContain('# Added by claude-code-plus');
    });

    it('preserves existing content in config files', function() {
      // Arrange
      const { configFiles } = createTestContext({ shells: ['bash'] });
      const originalContent = '# existing bashrc content\n';
      const shellPath = '/bin/bash';

      // Act
      configureShellAlias(shellPath);

      // Assert
      const content = fs.readFileSync(configFiles.bashrc, 'utf-8');
      expect(content).toContain(originalContent.trim());
    });
  });

  describe('getSourceCommand()', function() {
    it('returns fish source command when SHELL is fish', function() {
      // Arrange
      process.env.SHELL = '/usr/bin/fish';

      // Act
      const result = getSourceCommand();

      // Assert
      expect(result).toBe('source ~/.config/fish/config.fish');
    });

    it('returns zsh source command when SHELL is zsh', function() {
      // Arrange
      process.env.SHELL = '/bin/zsh';

      // Act
      const result = getSourceCommand();

      // Assert
      expect(result).toBe('source ~/.zshrc');
    });

    it('returns bash source command when SHELL is bash', function() {
      // Arrange
      process.env.SHELL = '/bin/bash';

      // Act
      const result = getSourceCommand();

      // Assert
      expect(result).toBe('source ~/.bashrc');
    });

    it('returns bash source command as default', function() {
      // Arrange
      process.env.SHELL = '/some/unknown/shell';

      // Act
      const result = getSourceCommand();

      // Assert
      expect(result).toBe('source ~/.bashrc');
    });

    it('returns bash source command when SHELL is not set', function() {
      // Arrange
      delete process.env.SHELL;

      // Act
      const result = getSourceCommand();

      // Assert
      expect(result).toBe('source ~/.bashrc');
    });
  });
});
