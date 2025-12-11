// Interactive prompts with TTY detection

import * as readline from 'node:readline';
import { bold, green, blue } from './utils/colors.js';

export function isTTY(): boolean {
  return process.stdin.isTTY === true;
}

/**
 * Read a single keypress without requiring Enter
 */
function readKey(): Promise<string> {
  return new Promise(function readKeyPromise(resolve) {
    const { stdin } = process;
    const wasRaw = stdin.isRaw;

    if (stdin.isTTY) {
      stdin.setRawMode(true);
    }
    stdin.resume();
    stdin.setEncoding('utf8');

    function onData(key: string): void {
      if (stdin.isTTY) {
        stdin.setRawMode(wasRaw ?? false);
      }
      stdin.pause();
      stdin.removeListener('data', onData);

      // Handle Ctrl+C
      if (key === '\u0003') {
        process.exit(130);
      }

      resolve(key);
    }

    stdin.once('data', onData);
  });
}

/**
 * Allow the process to exit by unreferencing stdin
 */
export function cleanupStdin(): void {
  if (typeof process.stdin.unref === 'function') {
    process.stdin.unref();
  }
}

export async function promptYesNo(question: string, defaultYes = true): Promise<boolean> {
  const hint = defaultYes ? '[Y/n]' : '[y/N]';
  process.stdout.write(`${question} ${hint} `);

  const key = await readKey();
  const keyLower = key.toLowerCase();

  // Print the key and newline
  if (keyLower === 'y' || keyLower === 'n') {
    console.log(key);
  } else {
    console.log('');
  }

  if (keyLower === 'y') {
    return true;
  }
  if (keyLower === 'n') {
    return false;
  }

  // Enter or any other key = default
  return defaultYes;
}

/**
 * Prompt for text input (requires Enter to submit)
 */
export function promptText(question: string): Promise<string> {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

export type InstallMode = 'recommended' | 'custom';

export async function promptInstallMode(): Promise<InstallMode> {
  console.log('');
  console.log(`${bold('Choose installation mode:')}`);
  console.log('');
  console.log(`  ${green('[1]')} ${bold('Recommended')} - Install everything with sensible defaults`);
  console.log('      - Claude Code runs commands in modern bash (4.4+)');
  console.log('      - Auto-approve hook for compound commands');
  console.log('      - Safe read-only command permissions');
  console.log('');
  console.log(`  ${blue('[2]')} ${bold('Custom')} - Choose what to install`);
  console.log('');

  while (true) {
    process.stdout.write('Enter choice [1/2]: ');
    const key = await readKey();

    if (key === '1' || key === '\r' || key === '\n') {
      console.log('1');
      return 'recommended';
    }
    if (key === '2') {
      console.log('2');
      return 'custom';
    }

    console.log('');
    console.log('Please enter 1 or 2');
  }
}
