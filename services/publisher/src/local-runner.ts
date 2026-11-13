import { handler } from './publisher';

const message = process.argv[2] || 'hello from publisher';
const total = Number(process.argv[3]) || 20;
const intervalMs = Number(process.argv[4]) || 1000;

const RESET = '\x1b[0m';
const GRAY = '\x1b[90m';
const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const BLUE = '\x1b[34m';

const PREFIX = `${BLUE}[publisher]${RESET}   ${GRAY}|${RESET}`;

function ts(): string {
  return new Date().toISOString();
}

const log = {
  info: (msg: string) => console.log(`${PREFIX} ${ts()} ${GREEN}INFO${RESET}  ${msg}`),
  error: (msg: string) => console.log(`${PREFIX} ${ts()} ${RED}ERROR${RESET} ${msg}`),
};

(async () => {
  log.info(`Starting publish cycle total=${total} interval=${intervalMs}ms`);

  for (let i = 1; i <= total; i++) {
    try {
      await handler({ message, seq: i, sentAt: Date.now() }, {} as any);
      log.info(`Published seq=${i}/${total}`);
    } catch (err: any) {
      log.error(`Publish failed seq=${i}/${total} error=${err.message}`);
    }

    if (i < total) {
      await new Promise((r) => setTimeout(r, intervalMs));
    }
  }

  log.info('All messages dispatched');
  process.exit(0);
})();
