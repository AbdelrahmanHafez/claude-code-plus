import {
  isChezmoiManaged,
  getClaudeDir,
  getHookPrefix,
  isOverrideDir,
  trackChezmoiFile,
  getModifiedChezmoiFiles,
  hasChezmoiModifications
} from './chezmoi.js';

describe('chezmoi', function() {
  describe('isOverrideDir()', function() {
    const originalEnv = process.env.CLAUDE_DIR_OVERRIDE;

    afterEach(function() {
      if (originalEnv === undefined) {
        delete process.env.CLAUDE_DIR_OVERRIDE;
      } else {
        process.env.CLAUDE_DIR_OVERRIDE = originalEnv;
      }
    });

    it('returns true when CLAUDE_DIR_OVERRIDE is set', function() {
      // Arrange
      process.env.CLAUDE_DIR_OVERRIDE = '/tmp/test-claude';

      // Act
      const result = isOverrideDir();

      // Assert
      expect(result).toBe(true);
    });

    it('returns false when CLAUDE_DIR_OVERRIDE is not set', function() {
      // Arrange
      delete process.env.CLAUDE_DIR_OVERRIDE;

      // Act
      const result = isOverrideDir();

      // Assert
      expect(result).toBe(false);
    });

    it('returns false when CLAUDE_DIR_OVERRIDE is empty string', function() {
      // Arrange
      process.env.CLAUDE_DIR_OVERRIDE = '';

      // Act
      const result = isOverrideDir();

      // Assert
      expect(result).toBe(false);
    });
  });

  describe('getClaudeDir()', function() {
    const originalEnv = process.env.CLAUDE_DIR_OVERRIDE;

    afterEach(function() {
      if (originalEnv === undefined) {
        delete process.env.CLAUDE_DIR_OVERRIDE;
      } else {
        process.env.CLAUDE_DIR_OVERRIDE = originalEnv;
      }
    });

    it('returns override directory when CLAUDE_DIR_OVERRIDE is set', function() {
      // Arrange
      const overrideDir = '/tmp/test-claude-override';
      process.env.CLAUDE_DIR_OVERRIDE = overrideDir;

      // Act
      const result = getClaudeDir();

      // Assert
      expect(result).toBe(overrideDir);
    });

    it('returns ~/.claude when no override is set and chezmoi not managing', function() {
      // Arrange
      delete process.env.CLAUDE_DIR_OVERRIDE;

      // Act
      const result = getClaudeDir();

      // Assert
      // Either returns chezmoi source path or ~/.claude
      expect(result).toMatch(/\.claude|dotfiles/);
    });
  });

  describe('getHookPrefix()', function() {
    const originalEnv = process.env.CLAUDE_DIR_OVERRIDE;

    afterEach(function() {
      if (originalEnv === undefined) {
        delete process.env.CLAUDE_DIR_OVERRIDE;
      } else {
        process.env.CLAUDE_DIR_OVERRIDE = originalEnv;
      }
    });

    it('returns empty string when using override directory', function() {
      // Arrange
      process.env.CLAUDE_DIR_OVERRIDE = '/tmp/test-claude';

      // Act
      const result = getHookPrefix();

      // Assert
      expect(result).toBe('');
    });
  });

  describe('isChezmoiManaged()', function() {
    const originalEnv = process.env.CLAUDE_DIR_OVERRIDE;

    afterEach(function() {
      if (originalEnv === undefined) {
        delete process.env.CLAUDE_DIR_OVERRIDE;
      } else {
        process.env.CLAUDE_DIR_OVERRIDE = originalEnv;
      }
    });

    it('returns false when using override directory', function() {
      // Arrange
      process.env.CLAUDE_DIR_OVERRIDE = '/tmp/test-claude';

      // Act
      const result = isChezmoiManaged();

      // Assert
      expect(result).toBe(false);
    });
  });

  describe('file tracking', function() {
    describe('with override directory (no chezmoi)', function() {
      const originalEnv = process.env.CLAUDE_DIR_OVERRIDE;

      beforeEach(function() {
        process.env.CLAUDE_DIR_OVERRIDE = '/tmp/test-claude';
      });

      afterEach(function() {
        if (originalEnv === undefined) {
          delete process.env.CLAUDE_DIR_OVERRIDE;
        } else {
          process.env.CLAUDE_DIR_OVERRIDE = originalEnv;
        }
      });

      it('trackChezmoiFile tracks files regardless of chezmoi management status', function() {
        // Arrange
        // Shell configs can be chezmoi-managed even if ~/.claude isn't
        const initialCount = getModifiedChezmoiFiles().length;

        // Act
        trackChezmoiFile('/tmp/test-file.json');

        // Assert
        expect(getModifiedChezmoiFiles().length).toBe(initialCount + 1);
        expect(getModifiedChezmoiFiles()).toContain('/tmp/test-file.json');
      });

      it('hasChezmoiModifications returns true when files are tracked', function() {
        // Arrange
        trackChezmoiFile('/tmp/another-test-file.json');

        // Act & Assert
        expect(hasChezmoiModifications()).toBe(true);
      });
    });
  });
});
