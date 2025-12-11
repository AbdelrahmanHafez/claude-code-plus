// Terminal output helpers with ANSI color codes

const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';
const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const BLUE = '\x1b[34m';
const MAGENTA = '\x1b[35m';
const CYAN = '\x1b[36m';
const BRIGHT_GREEN = '\x1b[92m';
const BRIGHT_CYAN = '\x1b[96m';

export function info(message: string): void {
  console.log(`${BLUE}ℹ${RESET} ${message}`);
}

export function success(message: string): void {
  console.log(`${GREEN}✓${RESET} ${message}`);
}

export function error(message: string): void {
  console.log(`${RED}✗${RESET} ${message}`);
}

export function warn(message: string): void {
  console.log(`${YELLOW}⚠${RESET} ${message}`);
}

export function step(message: string): void {
  console.log(`\n${CYAN}→${RESET} ${message}`);
}

export function cmd(command: string): string {
  return `${YELLOW}${command}${RESET}`;
}

export function file(path: string): string {
  return `${MAGENTA}${path}${RESET}`;
}

export function bold(text: string): string {
  return `${BOLD}${text}${RESET}`;
}

export function green(text: string): string {
  return `${GREEN}${text}${RESET}`;
}

export function blue(text: string): string {
  return `${BLUE}${text}${RESET}`;
}

export function printBanner(): void {
  console.log('');
  console.log(`${BRIGHT_GREEN}${BOLD}╔════════════════════════════════════════════╗${RESET}`);
  console.log(`${BRIGHT_GREEN}${BOLD}║${RESET}        ${BRIGHT_CYAN}${BOLD}Claude Code Plus Installer${RESET}          ${BRIGHT_GREEN}${BOLD}║${RESET}`);
  console.log(`${BRIGHT_GREEN}${BOLD}╚════════════════════════════════════════════╝${RESET}`);
  console.log('');
}

export function printCompletion(): void {
  console.log('');
  console.log(`${GREEN}╔════════════════════════════════════════════╗${RESET}`);
  console.log(`${GREEN}║${RESET}${BOLD}            Installation Complete!          ${RESET}${GREEN}║${RESET}`);
  console.log(`${GREEN}╚════════════════════════════════════════════╝${RESET}`);
  console.log('');
}
