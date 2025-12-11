import {
  setEnvVarInSettings,
  addPermissionToSettings,
  hasPermissionInSettings,
  addPermissionsToSettings,
  addHookToSettings,
  hasHookInSettings,
  ClaudeSettings,
  HookConfig
} from './settings.js';

// --- Test Helpers ---

function createEmptySettings(): ClaudeSettings {
  return {};
}

function createSettingsWithEnv(env: Record<string, string>): ClaudeSettings {
  return { env };
}

function createSettingsWithPermissions(allow: string[]): ClaudeSettings {
  return { permissions: { allow } };
}

function createBashHookConfig(command: string): HookConfig {
  return {
    matcher: 'Bash',
    hooks: [{ type: 'command', command }]
  };
}

function createSettingsWithBashHook(command: string): ClaudeSettings {
  return {
    hooks: {
      PreToolUse: [
        { matcher: 'Bash', hooks: [{ type: 'command', command }] }
      ]
    }
  };
}

// --- Tests ---

describe('setEnvVarInSettings()', function() {
  it('sets environment variable in empty settings', function() {
    // Arrange
    const settings = createEmptySettings();

    // Act
    const result = setEnvVarInSettings(settings, 'SHELL', '/bin/bash');

    // Assert
    expect(result.env?.SHELL).toBe('/bin/bash');
  });

  it('preserves existing env vars when adding new one', function() {
    // Arrange
    const settings = createSettingsWithEnv({ FIRST: 'first-value' });

    // Act
    const result = setEnvVarInSettings(settings, 'SECOND', 'second-value');

    // Assert
    expect(result.env?.FIRST).toBe('first-value');
    expect(result.env?.SECOND).toBe('second-value');
  });

  it('overwrites existing env var with same name', function() {
    // Arrange
    const settings = createSettingsWithEnv({ SHELL: '/bin/zsh' });

    // Act
    const result = setEnvVarInSettings(settings, 'SHELL', '/bin/bash');

    // Assert
    expect(result.env?.SHELL).toBe('/bin/bash');
  });

  it('preserves other settings properties', function() {
    // Arrange
    const settings: ClaudeSettings = { permissions: { allow: ['Bash(ls:*)'] } };

    // Act
    const result = setEnvVarInSettings(settings, 'SHELL', '/bin/bash');

    // Assert
    expect(result.permissions?.allow).toContain('Bash(ls:*)');
    expect(result.env?.SHELL).toBe('/bin/bash');
  });
});

describe('addPermissionToSettings()', function() {
  it('adds permission to empty settings', function() {
    // Arrange
    const settings = createEmptySettings();

    // Act
    const result = addPermissionToSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result.added).toBe(true);
    expect(result.settings.permissions?.allow).toContain('Bash(ls:*)');
  });

  it('returns added=false when permission already exists', function() {
    // Arrange
    const settings = createSettingsWithPermissions(['Bash(ls:*)']);

    // Act
    const result = addPermissionToSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result.added).toBe(false);
    expect(result.settings).toBe(settings); // Same reference, unchanged
  });

  it('creates permissions object when settings has no permissions key', function() {
    // Arrange
    const settings: ClaudeSettings = { env: { FOO: 'bar' } };

    // Act
    const result = addPermissionToSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result.added).toBe(true);
    expect(result.settings.permissions?.allow).toContain('Bash(ls:*)');
    expect(result.settings.env?.FOO).toBe('bar');
  });

  it('creates allow array when permissions exists but allow is missing', function() {
    // Arrange
    const settings: ClaudeSettings = { permissions: { deny: ['Bash(rm:*)'] } };

    // Act
    const result = addPermissionToSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result.added).toBe(true);
    expect(result.settings.permissions?.allow).toContain('Bash(ls:*)');
    expect(result.settings.permissions?.deny).toContain('Bash(rm:*)');
  });

  it('appends to existing allow array', function() {
    // Arrange
    const settings = createSettingsWithPermissions(['Bash(existing:*)']);

    // Act
    const result = addPermissionToSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result.added).toBe(true);
    expect(result.settings.permissions?.allow).toContain('Bash(existing:*)');
    expect(result.settings.permissions?.allow).toContain('Bash(ls:*)');
  });

  it('handles permissions with empty allow array', function() {
    // Arrange
    const settings: ClaudeSettings = { permissions: { allow: [] } };

    // Act
    const result = addPermissionToSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result.added).toBe(true);
    expect(result.settings.permissions?.allow).toEqual(['Bash(ls:*)']);
  });
});

describe('hasPermissionInSettings()', function() {
  it('returns false when no permissions exist', function() {
    // Arrange
    const settings = createEmptySettings();

    // Act
    const result = hasPermissionInSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result).toBe(false);
  });

  it('returns true when permission exists', function() {
    // Arrange
    const settings = createSettingsWithPermissions(['Bash(ls:*)']);

    // Act
    const result = hasPermissionInSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result).toBe(true);
  });

  it('returns false for non-existent permission', function() {
    // Arrange
    const settings = createSettingsWithPermissions(['Bash(ls:*)']);

    // Act
    const result = hasPermissionInSettings(settings, 'Bash(rm:*)');

    // Assert
    expect(result).toBe(false);
  });

  it('returns false when permissions exists but allow is missing', function() {
    // Arrange
    const settings: ClaudeSettings = { permissions: { deny: ['Bash(rm:*)'] } };

    // Act
    const result = hasPermissionInSettings(settings, 'Bash(ls:*)');

    // Assert
    expect(result).toBe(false);
  });
});

describe('addPermissionsToSettings()', function() {
  it('adds multiple permissions at once', function() {
    // Arrange
    const settings = createEmptySettings();
    const permissions = ['Bash(ls:*)', 'Bash(grep:*)', 'Bash(cat:*)'];

    // Act
    const result = addPermissionsToSettings(settings, permissions);

    // Assert
    expect(result.added).toBe(3);
    expect(result.settings.permissions?.allow).toContain('Bash(ls:*)');
    expect(result.settings.permissions?.allow).toContain('Bash(grep:*)');
    expect(result.settings.permissions?.allow).toContain('Bash(cat:*)');
  });

  it('returns count of actually added permissions (skips duplicates)', function() {
    // Arrange
    const settings = createSettingsWithPermissions(['Bash(ls:*)']);

    // Act
    const result = addPermissionsToSettings(settings, ['Bash(ls:*)', 'Bash(grep:*)', 'Bash(cat:*)']);

    // Assert
    expect(result.added).toBe(2);
  });

  it('returns 0 when all permissions already exist', function() {
    // Arrange
    const settings = createSettingsWithPermissions(['Bash(ls:*)', 'Bash(grep:*)']);

    // Act
    const result = addPermissionsToSettings(settings, ['Bash(ls:*)', 'Bash(grep:*)']);

    // Assert
    expect(result.added).toBe(0);
    expect(result.settings).toBe(settings); // Same reference, unchanged
  });

  it('preserves existing permissions when adding new ones', function() {
    // Arrange
    const settings = createSettingsWithPermissions(['Bash(existing:*)']);

    // Act
    const result = addPermissionsToSettings(settings, ['Bash(new:*)']);

    // Assert
    expect(result.settings.permissions?.allow).toContain('Bash(existing:*)');
    expect(result.settings.permissions?.allow).toContain('Bash(new:*)');
  });
});

describe('addHookToSettings()', function() {
  it('adds hook to empty settings', function() {
    // Arrange
    const settings = createEmptySettings();
    const hookConfig = createBashHookConfig('my-hook.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    expect(result.hooks?.PreToolUse?.length).toBe(1);
    expect(hasHookInSettings(result, 'my-hook.sh')).toBe(true);
  });

  it('merges hooks with same matcher', function() {
    // Arrange
    const settings = createSettingsWithBashHook('hook1.sh');
    const hookConfig = createBashHookConfig('hook2.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    const bashHook = result.hooks?.PreToolUse?.find(hook => hook.matcher === 'Bash');
    expect(bashHook?.hooks.some(hook => hook.command === 'hook1.sh')).toBe(true);
    expect(bashHook?.hooks.some(hook => hook.command === 'hook2.sh')).toBe(true);
  });

  it('does not duplicate hook paths', function() {
    // Arrange
    const settings = createSettingsWithBashHook('hook1.sh');
    const hookConfig = createBashHookConfig('hook1.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    const bashHook = result.hooks?.PreToolUse?.find(hook => hook.matcher === 'Bash');
    expect(bashHook?.hooks.filter(hook => hook.command === 'hook1.sh').length).toBe(1);
  });

  it('adds separate entries for different matchers', function() {
    // Arrange
    const settings = createSettingsWithBashHook('bash-hook.sh');
    const hookConfig: HookConfig = {
      matcher: 'Read',
      hooks: [{ type: 'command', command: 'read-hook.sh' }]
    };

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    expect(result.hooks?.PreToolUse?.length).toBe(2);
    expect(hasHookInSettings(result, 'bash-hook.sh')).toBe(true);
    expect(hasHookInSettings(result, 'read-hook.sh')).toBe(true);
  });

  it('creates hooks object when settings has no hooks key', function() {
    // Arrange
    const settings: ClaudeSettings = { env: { FOO: 'bar' } };
    const hookConfig = createBashHookConfig('my-hook.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    expect(result.hooks).toBeDefined();
    expect(result.hooks?.PreToolUse).toBeDefined();
    expect(hasHookInSettings(result, 'my-hook.sh')).toBe(true);
    expect(result.env?.FOO).toBe('bar');
  });

  it('creates PreToolUse array when hooks exists but PreToolUse is missing', function() {
    // Arrange
    const settings: ClaudeSettings = { hooks: { PostToolUse: [] } };
    const hookConfig = createBashHookConfig('my-hook.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    expect(result.hooks?.PreToolUse).toBeDefined();
    expect(result.hooks?.PreToolUse?.length).toBe(1);
    expect(hasHookInSettings(result, 'my-hook.sh')).toBe(true);
  });

  it('handles hooks with empty PreToolUse array', function() {
    // Arrange
    const settings: ClaudeSettings = { hooks: { PreToolUse: [] } };
    const hookConfig = createBashHookConfig('my-hook.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    expect(result.hooks?.PreToolUse?.length).toBe(1);
    expect(result.hooks?.PreToolUse?.[0].matcher).toBe('Bash');
    expect(hasHookInSettings(result, 'my-hook.sh')).toBe(true);
  });

  it('handles PreToolUse with entries but no Bash matcher', function() {
    // Arrange
    const settings: ClaudeSettings = {
      hooks: {
        PreToolUse: [
          { matcher: 'Read', hooks: [{ type: 'command', command: 'read-hook.sh' }] }
        ]
      }
    };
    const hookConfig = createBashHookConfig('bash-hook.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    expect(result.hooks?.PreToolUse?.length).toBe(2);
    expect(hasHookInSettings(result, 'read-hook.sh')).toBe(true);
    expect(hasHookInSettings(result, 'bash-hook.sh')).toBe(true);
  });

  it('handles Bash matcher with empty hooks array', function() {
    // Arrange
    const settings: ClaudeSettings = {
      hooks: {
        PreToolUse: [{ matcher: 'Bash', hooks: [] }]
      }
    };
    const hookConfig = createBashHookConfig('my-hook.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    const bashHook = result.hooks?.PreToolUse?.find(hook => hook.matcher === 'Bash');
    expect(bashHook?.hooks.length).toBe(1);
    expect(bashHook?.hooks[0].command).toBe('my-hook.sh');
  });

  it('appends to existing Bash matcher hooks', function() {
    // Arrange
    const settings = createSettingsWithBashHook('existing-hook.sh');
    const hookConfig = createBashHookConfig('new-hook.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    const bashHook = result.hooks?.PreToolUse?.find(hook => hook.matcher === 'Bash');
    expect(bashHook?.hooks.length).toBe(2);
    expect(bashHook?.hooks.some(hook => hook.command === 'existing-hook.sh')).toBe(true);
    expect(bashHook?.hooks.some(hook => hook.command === 'new-hook.sh')).toBe(true);
  });

  it('preserves other hook types when adding PreToolUse', function() {
    // Arrange
    const settings: ClaudeSettings = {
      hooks: {
        PostToolUse: [{ matcher: 'Bash', hooks: [{ type: 'command', command: 'post-hook.sh' }] }]
      }
    };
    const hookConfig = createBashHookConfig('pre-hook.sh');

    // Act
    const result = addHookToSettings(settings, hookConfig);

    // Assert
    expect(result.hooks?.PostToolUse).toBeDefined();
    expect(result.hooks?.PreToolUse).toBeDefined();
  });
});

describe('hasHookInSettings()', function() {
  it('returns false when no hooks exist', function() {
    // Arrange
    const settings = createEmptySettings();

    // Act
    const result = hasHookInSettings(settings, 'some-hook.sh');

    // Assert
    expect(result).toBe(false);
  });

  it('returns true when hook exists', function() {
    // Arrange
    const settings = createSettingsWithBashHook('my-hook.sh');

    // Act
    const result = hasHookInSettings(settings, 'my-hook.sh');

    // Assert
    expect(result).toBe(true);
  });

  it('returns false for non-existent hook', function() {
    // Arrange
    const settings = createSettingsWithBashHook('existing-hook.sh');

    // Act
    const result = hasHookInSettings(settings, 'non-existent-hook.sh');

    // Assert
    expect(result).toBe(false);
  });

  it('returns false when hooks exists but PreToolUse is missing', function() {
    // Arrange
    const settings: ClaudeSettings = { hooks: { PostToolUse: [] } };

    // Act
    const result = hasHookInSettings(settings, 'some-hook.sh');

    // Assert
    expect(result).toBe(false);
  });

  it('returns false when PreToolUse is empty', function() {
    // Arrange
    const settings: ClaudeSettings = { hooks: { PreToolUse: [] } };

    // Act
    const result = hasHookInSettings(settings, 'some-hook.sh');

    // Assert
    expect(result).toBe(false);
  });
});
