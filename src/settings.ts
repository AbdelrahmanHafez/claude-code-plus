// Claude Code settings.json manipulation

import * as fs from 'node:fs';
import * as path from 'node:path';
import { getClaudeDir, trackChezmoiFile } from './utils/chezmoi.js';
import { info, file } from './utils/colors.js';

// --- Types ---

export interface HookEntry {
  type: 'command';
  command: string;
}

export interface MatcherHook {
  matcher: string;
  hooks: HookEntry[];
}

export interface ClaudeSettings {
  env?: {
    SHELL?: string;
    [key: string]: string | undefined;
  };
  hooks?: {
    PreToolUse?: MatcherHook[];
    [key: string]: unknown;
  };
  permissions?: {
    allow?: string[];
    deny?: string[];
  };
  [key: string]: unknown;
}

export interface HookConfig {
  matcher: string;
  hooks: HookEntry[];
}

// --- Pure transformation functions (no I/O) ---

export function setEnvVarInSettings(settings: ClaudeSettings, name: string, value: string): ClaudeSettings {
  return {
    ...settings,
    env: {
      ...settings.env,
      [name]: value
    }
  };
}

export function addPermissionToSettings(
  settings: ClaudeSettings,
  permission: string
): { settings: ClaudeSettings; added: boolean } {
  const currentAllow = settings.permissions?.allow ?? [];

  if (currentAllow.includes(permission)) {
    return { settings, added: false };
  }

  return {
    settings: {
      ...settings,
      permissions: {
        ...settings.permissions,
        allow: [...currentAllow, permission]
      }
    },
    added: true
  };
}

export function hasPermissionInSettings(settings: ClaudeSettings, permission: string): boolean {
  return settings.permissions?.allow?.includes(permission) ?? false;
}

export function addPermissionsToSettings(
  settings: ClaudeSettings,
  permissions: string[]
): { settings: ClaudeSettings; added: number } {
  const currentAllow = settings.permissions?.allow ?? [];
  const newPermissions = permissions.filter(p => !currentAllow.includes(p));

  if (newPermissions.length === 0) {
    return { settings, added: 0 };
  }

  return {
    settings: {
      ...settings,
      permissions: {
        ...settings.permissions,
        allow: [...currentAllow, ...newPermissions]
      }
    },
    added: newPermissions.length
  };
}

export function addHookToSettings(settings: ClaudeSettings, hookConfig: HookConfig): ClaudeSettings {
  const currentPreToolUse = settings.hooks?.PreToolUse ?? [];
  const existingIndex = currentPreToolUse.findIndex(
    (matcherHook) => matcherHook.matcher === hookConfig.matcher
  );

  let newPreToolUse: MatcherHook[];

  if (existingIndex >= 0) {
    // Merge hooks arrays (check by command path)
    const existing = currentPreToolUse[existingIndex];
    const newHooks = hookConfig.hooks.filter(
      (hookEntry) => !existing.hooks.some((hook) => hook.command === hookEntry.command)
    );
    newPreToolUse = [
      ...currentPreToolUse.slice(0, existingIndex),
      { ...existing, hooks: [...existing.hooks, ...newHooks] },
      ...currentPreToolUse.slice(existingIndex + 1)
    ];
  } else {
    newPreToolUse = [...currentPreToolUse, hookConfig];
  }

  return {
    ...settings,
    hooks: {
      ...settings.hooks,
      PreToolUse: newPreToolUse
    }
  };
}

export function hasHookInSettings(settings: ClaudeSettings, hookPath: string): boolean {
  if (!settings.hooks?.PreToolUse) {
    return false;
  }
  return settings.hooks.PreToolUse.some((matcherHook) =>
    matcherHook.hooks.some((hookEntry) => hookEntry.command === hookPath)
  );
}

// --- I/O functions ---

function getSettingsPath(): string {
  return path.join(getClaudeDir(), 'settings.json');
}

export function ensureClaudeDir(): void {
  const claudeDir = getClaudeDir();
  if (!fs.existsSync(claudeDir)) {
    fs.mkdirSync(claudeDir, { recursive: true });
    info(`Created ${file(claudeDir)}`);
  }
}

export function getSettings(): ClaudeSettings {
  const settingsPath = getSettingsPath();
  if (!fs.existsSync(settingsPath)) {
    return {};
  }
  const content = fs.readFileSync(settingsPath, 'utf-8');
  return JSON.parse(content) as ClaudeSettings;
}

export function saveSettings(settings: ClaudeSettings): void {
  ensureClaudeDir();
  const settingsPath = getSettingsPath();
  fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`);
  trackChezmoiFile(settingsPath);
}

// --- High-level I/O wrappers (for CLI usage) ---

export function setEnvVar(name: string, value: string): void {
  const settings = getSettings();
  const newSettings = setEnvVarInSettings(settings, name, value);
  saveSettings(newSettings);
}

export function addPermission(permission: string): boolean {
  const settings = getSettings();
  const result = addPermissionToSettings(settings, permission);
  if (result.added) {
    saveSettings(result.settings);
  }
  return result.added;
}

export function hasPermission(permission: string): boolean {
  return hasPermissionInSettings(getSettings(), permission);
}

export function addPermissions(permissions: string[]): number {
  const settings = getSettings();
  const result = addPermissionsToSettings(settings, permissions);
  if (result.added > 0) {
    saveSettings(result.settings);
  }
  return result.added;
}

export function addHook(hookConfig: HookConfig): boolean {
  const settings = getSettings();
  const newSettings = addHookToSettings(settings, hookConfig);
  saveSettings(newSettings);
  return true;
}

export function hasHook(hookPath: string): boolean {
  return hasHookInSettings(getSettings(), hookPath);
}
