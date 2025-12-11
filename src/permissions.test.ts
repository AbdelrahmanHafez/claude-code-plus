import { DEFAULT_PERMISSIONS } from './permissions.js';

describe('permissions', function() {
  describe('DEFAULT_PERMISSIONS', function() {
    it('is a non-empty array', function() {
      // Assert
      expect(Array.isArray(DEFAULT_PERMISSIONS)).toBe(true);
      expect(DEFAULT_PERMISSIONS.length).toBeGreaterThan(0);
    });

    it('contains over 800 permission entries', function() {
      // Assert
      expect(DEFAULT_PERMISSIONS.length).toBeGreaterThan(800);
    });

    it('all entries are valid permission patterns', function() {
      // Arrange
      // Permissions can be Bash(cmd:*), Bash(cmd), Glob, Grep, Read, etc.
      const validPatterns = [
        /^Bash\(.+\)$/, // Bash permissions
        /^Glob$/, // Glob tool
        /^Grep$/, // Grep tool
        /^Read\(.+\)$/, // Read with path
        /^Read$/, // Read tool
        /^WebFetch$/, // WebFetch tool
        /^WebSearch$/, // WebSearch tool
        /^mcp__.+$/ // MCP tools
      ];

      // Act & Assert
      for (const permission of DEFAULT_PERMISSIONS) {
        const matches = validPatterns.some(pattern => pattern.test(permission));
        expect(matches).toBe(true);
      }
    });

    it('contains common safe commands', function() {
      // Assert
      expect(DEFAULT_PERMISSIONS).toContain('Bash(ls:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(cat:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(grep:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(echo:*)');
    });

    it('contains git read-only commands', function() {
      // Assert
      expect(DEFAULT_PERMISSIONS).toContain('Bash(git status:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(git diff:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(git log:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(git branch:*)');
    });

    it('contains GitHub CLI read-only commands', function() {
      // Assert
      expect(DEFAULT_PERMISSIONS).toContain('Bash(gh pr list:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(gh issue list:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(gh repo view:*)');
    });

    it('contains npm/node commands', function() {
      // Assert
      expect(DEFAULT_PERMISSIONS).toContain('Bash(node --version:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(npm list:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(npm --version)');
    });

    it('contains python commands', function() {
      // Assert
      expect(DEFAULT_PERMISSIONS).toContain('Bash(python --version:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(python3 --version:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(pip list:*)');
    });

    it('contains docker read-only commands', function() {
      // Assert
      expect(DEFAULT_PERMISSIONS).toContain('Bash(docker ps:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(docker images:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(docker --version:*)');
    });

    it('contains kubectl read-only commands', function() {
      // Assert
      expect(DEFAULT_PERMISSIONS).toContain('Bash(kubectl get:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(kubectl describe:*)');
      expect(DEFAULT_PERMISSIONS).toContain('Bash(kubectl version:*)');
    });

    it('does not contain dangerous commands', function() {
      // Assert - these should NOT be in default permissions
      const dangerousPatterns = [
        'Bash(rm:*)',
        'Bash(rm -rf:*)',
        'Bash(sudo:*)',
        'Bash(chmod:*)',
        'Bash(chown:*)',
        'Bash(eval:*)',
        'Bash(xargs:*)'
      ];

      for (const dangerous of dangerousPatterns) {
        expect(DEFAULT_PERMISSIONS).not.toContain(dangerous);
      }
    });

    it('does not contain code execution commands', function() {
      // Assert - inline code execution should not be auto-approved
      const codeExecPatterns = [
        'Bash(python -c:*)',
        'Bash(node -e:*)',
        'Bash(ruby -e:*)',
        'Bash(perl -e:*)'
      ];

      for (const codeExec of codeExecPatterns) {
        expect(DEFAULT_PERMISSIONS).not.toContain(codeExec);
      }
    });

    it('has no duplicate entries', function() {
      // Arrange
      const seen = new Set<string>();
      const duplicates: string[] = [];

      // Act
      for (const permission of DEFAULT_PERMISSIONS) {
        if (seen.has(permission)) {
          duplicates.push(permission);
        }
        seen.add(permission);
      }

      // Assert
      expect(duplicates).toEqual([]);
    });

    it('all entries are non-empty strings', function() {
      // Act & Assert
      for (const permission of DEFAULT_PERMISSIONS) {
        expect(typeof permission).toBe('string');
        expect(permission.length).toBeGreaterThan(0);
      }
    });
  });
});
