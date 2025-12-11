#!/usr/bin/env node

// Claude Code Plus CLI - Main entry point

import * as path from 'node:path';
import {
  info,
  success,
  error,
  warn,
  step,
  cmd,
  file,
  printBanner,
  printCompletion
} from './utils/colors.js';
import { exec, commandExists, getCommandVersion } from './utils/exec.js';
import {
  isChezmoiManaged,
  getClaudeDir,
  hasChezmoiModifications,
  applyChezmoiChanges,
  isOverrideDir
} from './utils/chezmoi.js';
import { ensureClaudeDir, setEnvVar, addPermissions } from './settings.js';
import { installHook, configureHookInSettings } from './hooks.js';
import { configureShellAlias, getSourceCommand } from './shell-alias.js';
import { isTTY, promptYesNo, promptText, promptInstallMode, InstallMode, cleanupStdin } from './prompts.js';
import { DEFAULT_PERMISSIONS } from './permissions.js';

// --- Argument Parsing ---

interface Args {
  help: boolean;
  yes: boolean;
}

function parseArgs(): Args {
  const args: Args = {
    help: false,
    yes: false
  };

  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      args.help = true;
    } else if (arg === '--yes' || arg === '-y') {
      args.yes = true;
    }
  }

  return args;
}

function printHelp(): void {
  console.log(`
Claude Code Plus Installer

Enhance Claude Code CLI with:
  - Auto-approve hook for piped/compound commands
  - Modern shell support (bash 4.4+)
  - Pre-approved safe command permissions

Usage:
  npx claude-code-plus [options]

Options:
  -h, --help   Show this help message
  -y, --yes    Non-interactive mode, accept all defaults

Examples:
  npx claude-code-plus      # Interactive installation
  npx claude-code-plus -y   # Non-interactive with defaults
`);
}

// --- Dependency Checking ---

const MIN_BASH_MAJOR = 4;
const MIN_BASH_MINOR = 4;

function isMacOS(): boolean {
  return process.platform === 'darwin';
}

function findModernBash(): string | null {
  // macOS: check Homebrew paths first since /bin/bash is ancient (3.2)
  // Linux: /bin/bash is usually modern enough
  const candidates = isMacOS()
    ? ['/opt/homebrew/bin/bash', '/usr/local/bin/bash', '/bin/bash']
    : ['/bin/bash', '/usr/bin/bash', '/usr/local/bin/bash'];

  for (const bashPath of candidates) {
    if (bashVersionOk(bashPath)) {
      return bashPath;
    }
  }

  return null;
}

function bashVersionOk(bashPath: string): boolean {
  const result = exec(`${bashPath} -c 'echo "\${BASH_VERSINFO[0]}.\${BASH_VERSINFO[1]}"'`);
  if (!result.success) {
    return false;
  }

  const [major, minor] = result.stdout.split('.').map(Number);
  return major > MIN_BASH_MAJOR || (major === MIN_BASH_MAJOR && minor >= MIN_BASH_MINOR);
}

/**
 * Resolve a shell name or path to a full path.
 * If input is a path (contains /), validates it exists.
 * Otherwise, uses `which` to find the shell.
 */
function resolveShellPath(input: string): string | null {
  if (input.includes('/')) {
    // It's a path, check if it exists
    const result = exec(`test -x "${input}" && echo "${input}"`);
    return result.success && result.stdout ? result.stdout : null;
  }

  // It's a shell name, use which to find it
  const result = exec(`which ${input}`);
  return result.success && result.stdout ? result.stdout : null;
}

type PackageManager = 'brew' | 'apt' | 'dnf' | 'pacman' | 'apk' | null;

function detectPackageManager(): PackageManager {
  if (commandExists('brew')) {
    return 'brew';
  }
  if (commandExists('apt')) {
    return 'apt';
  }
  if (commandExists('dnf')) {
    return 'dnf';
  }
  if (commandExists('pacman')) {
    return 'pacman';
  }
  if (commandExists('apk')) {
    return 'apk';
  }
  return null;
}

function getInstallCommand(pkgManager: PackageManager, pkg: string): string | null {
  switch (pkgManager) {
    case 'brew': return `brew install ${pkg}`;
    case 'apt': return `sudo apt install -y ${pkg}`;
    case 'dnf': return `sudo dnf install -y ${pkg}`;
    case 'pacman': return `sudo pacman -S --noconfirm ${pkg}`;
    case 'apk': return `sudo apk add ${pkg}`;
    default: return null;
  }
}

function getInstallHint(pkg: string): string {
  const pkgManager = detectPackageManager();
  if (pkgManager) {
    return getInstallCommand(pkgManager, pkg)!;
  }
  if (isMacOS()) {
    return `brew install ${pkg}`;
  }
  // Linux: suggest common package managers
  return `apt install ${pkg}  OR  dnf install ${pkg}  OR  pacman -S ${pkg}`;
}

function installPackage(pkg: string): boolean {
  const pkgManager = detectPackageManager();
  if (!pkgManager) {
    error('No supported package manager found');
    return false;
  }

  const installCmd = getInstallCommand(pkgManager, pkg);
  if (!installCmd) {
    return false;
  }

  info(`Installing ${pkg} with ${pkgManager}...`);
  const result = exec(installCmd);

  if (result.success) {
    success(`${pkg} installed successfully`);
    return true;
  } else {
    error(`Failed to install ${pkg}: ${result.stderr}`);
    return false;
  }
}

interface DependencyStatus {
  name: string;
  packageName: string;
  installed: boolean;
  version: string | null;
}

function checkAllDependencies(): DependencyStatus[] {
  const statuses: DependencyStatus[] = [];

  // Check bash
  const modernBash = findModernBash();
  if (modernBash) {
    const result = exec(`${modernBash} -c 'echo "\${BASH_VERSINFO[0]}.\${BASH_VERSINFO[1]}"'`);
    statuses.push({
      name: `bash (>= ${MIN_BASH_MAJOR}.${MIN_BASH_MINOR})`,
      packageName: 'bash',
      installed: true,
      version: result.stdout
    });
  } else {
    statuses.push({
      name: `bash (>= ${MIN_BASH_MAJOR}.${MIN_BASH_MINOR})`,
      packageName: 'bash',
      installed: false,
      version: null
    });
  }

  // Check jq
  const jqInstalled = commandExists('jq');
  statuses.push({
    name: 'jq',
    packageName: 'jq',
    installed: jqInstalled,
    version: jqInstalled ? getCommandVersion('jq')?.replace('jq-', '') || null : null
  });

  // Check shfmt
  const shfmtInstalled = commandExists('shfmt');
  statuses.push({
    name: 'shfmt',
    packageName: 'shfmt',
    installed: shfmtInstalled,
    version: shfmtInstalled ? getCommandVersion('shfmt') : null
  });

  return statuses;
}

function displayDependencyStatuses(statuses: DependencyStatus[]): void {
  for (const dep of statuses) {
    if (dep.installed) {
      success(`${dep.name} ${dep.version || ''}`);
    } else {
      error(`${dep.name} not found`);
    }
  }

  // Show macOS hint for bash if missing
  const bashMissing = statuses.some(dep => dep.packageName === 'bash' && !dep.installed);
  if (bashMissing && isMacOS()) {
    info('macOS ships with bash 3.2, which is too old');
  }
}

async function installMissingDependencies(
  statuses: DependencyStatus[],
  nonInteractive: boolean
): Promise<boolean> {
  const missing = statuses.filter(dep => !dep.installed);

  if (missing.length === 0) {
    return true;
  }

  const pkgManager = detectPackageManager();
  if (!pkgManager) {
    console.log('');
    info('No supported package manager found. Please install manually:');
    for (const dep of missing) {
      info(`  ${dep.name}: ${getInstallHint(dep.packageName)}`);
    }
    return false;
  }

  console.log('');

  // Install each missing dependency
  for (const dep of missing) {
    let shouldInstall = nonInteractive;

    if (!nonInteractive) {
      shouldInstall = await promptYesNo(`Install ${dep.packageName}?`);
    }

    if (shouldInstall) {
      const installed = installPackage(dep.packageName);
      if (!installed) {
        return false;
      }
    } else {
      info(`Skipping ${dep.packageName}. Install with: ${getInstallHint(dep.packageName)}`);
      return false;
    }
  }

  return true;
}

function checkDependencies(nonInteractive: boolean): Promise<boolean> {
  // Phase 1: Check all dependencies and display statuses
  const statuses = checkAllDependencies();
  displayDependencyStatuses(statuses);

  // Phase 2: If any missing, offer to install
  const allInstalled = statuses.every(dep => dep.installed);
  if (allInstalled) {
    return Promise.resolve(true);
  }

  return installMissingDependencies(statuses, nonInteractive);
}

// --- Installation Steps ---

function stepShell(shellPath: string): void {
  step('Configuring shell for Claude Code commands');

  const shellName = path.basename(shellPath);
  info(`Configuring Claude to use ${cmd(shellName)} (${file(shellPath)})`);

  ensureClaudeDir();

  // Set env.SHELL in settings.json
  setEnvVar('SHELL', shellPath);

  // Add shell alias to shell config files
  configureShellAlias(shellPath);

  success(`Claude Code will now run commands in ${shellName}`);
}

function stepHook(): void {
  step('Installing hook to auto-approve allowed commands');

  installHook();
  configureHookInSettings();
}

function stepPermissions(): void {
  step('Adding safe permissions');

  const added = addPermissions(DEFAULT_PERMISSIONS);

  if (added === 0) {
    success('All permissions already configured');
  } else {
    success(`Added ${added} safe command permissions`);
  }
}

// --- Main Flow ---

function runRecommendedInstall(shellPath: string): void {
  info('Installing with recommended settings...');
  console.log('');

  stepShell(shellPath);
  stepHook();
  stepPermissions();
}

async function runCustomInstall(defaultShellPath: string): Promise<void> {
  info('Custom installation...');
  console.log('');

  // Shell configuration
  const useModernBash = await promptYesNo(`Use modern ${cmd('bash')} (recommended for Claude Code)?`);

  if (useModernBash) {
    stepShell(defaultShellPath);
  } else {
    info(`Enter shell name or path (e.g., ${cmd('fish')}, ${file('/opt/homebrew/bin/zsh')})`);
    const shellInput = await promptText('Shell: ');

    if (!shellInput) {
      info('Skipping shell configuration');
    } else {
      const resolvedPath = resolveShellPath(shellInput);
      if (resolvedPath) {
        stepShell(resolvedPath);
      } else {
        error(`Could not find shell: ${shellInput}`);
        info('Skipping shell configuration');
      }
    }
  }

  if (await promptYesNo('Auto-approve piped commands that match allowed patterns?')) {
    stepHook();
  } else {
    info('Skipping hook installation');
  }

  if (await promptYesNo(`Pre-approve common safe commands (${cmd('ls')}, ${cmd('git status')}, ${cmd('grep')}, etc.)?`)) {
    stepPermissions();
  } else {
    info('Skipping permissions');
  }
}

function displayPath(p: string): string {
  const home = process.env.HOME;
  if (home && p.startsWith(home)) {
    return p.replace(home, '~');
  }
  return p;
}

async function handleChezmoiApply(nonInteractive: boolean): Promise<void> {
  // Skip chezmoi logic when using override directory (testing)
  if (isOverrideDir() || !hasChezmoiModifications()) {
    return;
  }

  console.log('');
  const chezmoiCmd = 'chezmoi apply ~/.claude';

  if (nonInteractive || (await promptYesNo(`Run ${cmd(chezmoiCmd)} now?`))) {
    if (applyChezmoiChanges()) {
      success('Chezmoi applied');
    } else {
      error('Failed to apply chezmoi changes');
    }
  } else {
    warn(`Remember to run ${cmd(chezmoiCmd)} before using Claude Code`);
  }
}

async function main(): Promise<void> {
  const args = parseArgs();

  if (args.help) {
    printHelp();
    process.exit(0);
  }

  // TTY detection for non-interactive fallback
  let nonInteractive = args.yes;
  if (!nonInteractive && !isTTY()) {
    nonInteractive = true;
    console.log('No TTY detected, running in non-interactive mode (recommended settings)');
  }

  // Detect chezmoi (skip message if using test override)
  if (!isOverrideDir() && isChezmoiManaged()) {
    info(`Detected chezmoi managing ${file('~/.claude')}`);
    info(`Installing to: ${file(getClaudeDir())}`);
  }

  printBanner();

  // Check dependencies
  step('Checking dependencies');
  if (!(await checkDependencies(nonInteractive))) {
    error('Missing required dependencies. See install hints above.');
    process.exit(1);
  }

  // Find modern bash for recommended install
  const modernBashPath = findModernBash();
  if (!modernBashPath) {
    error('Modern bash (4.4+) not found');
    info(`Install with: ${cmd(getInstallHint('bash'))}`);
    process.exit(1);
  }

  // Determine install mode
  let mode: InstallMode = 'recommended';
  if (!nonInteractive) {
    mode = await promptInstallMode();
  }

  // Run installation
  if (mode === 'recommended') {
    runRecommendedInstall(modernBashPath);
  } else {
    await runCustomInstall(modernBashPath);
  }

  // Completion
  printCompletion();
  success('Claude Code Plus is now configured!');
  console.log('');
  info(`Settings file: ${file(displayPath(path.join(getClaudeDir(), 'settings.json')))}`);

  await handleChezmoiApply(nonInteractive);

  console.log('');
  info(`Open a new terminal or run ${cmd(getSourceCommand())}, then run ${cmd('claude')} to start.`);
  console.log('');
  info(
    `Review ${file(displayPath(path.join(getClaudeDir(), 'settings.json')))} to remove any permissions you don't want auto-approved.`
  );

  // Allow process to exit by unreferencing stdin
  cleanupStdin();
}

main().catch((err) => {
  error(String(err));
  process.exit(1);
});
