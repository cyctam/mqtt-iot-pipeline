const RESET = '\x1b[0m';
const GRAY = '\x1b[90m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const RED = '\x1b[31m';

function ts(): string {
  return new Date().toISOString();
}

export const logger = {
  info(msg: string) {
    console.log(`${ts()} ${GREEN}INFO${RESET}  ${msg}`);
  },
  warn(msg: string) {
    console.log(`${ts()} ${YELLOW}WARN${RESET}  ${msg}`);
  },
  error(msg: string) {
    console.log(`${ts()} ${RED}ERROR${RESET} ${msg}`);
  },
  api(msg: string) {
    console.log(`${ts()} ${GREEN}INFO${RESET}  ${msg}`);
  },
  mqtt(msg: string) {
    console.log(`${ts()} ${GREEN}INFO${RESET}  ${msg}`);
  },
  startup(msg: string) {
    console.log(`${msg}`);
  },
};

export function formatMethod(method: string): string {
  return method.toUpperCase().padEnd(6, ' ');
}