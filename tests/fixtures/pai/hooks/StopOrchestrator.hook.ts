import { writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';

async function readStdin(): Promise<any> { return JSON.parse(await Bun.stdin.text()); }

async function main() {
  const hookInput = await readStdin();
  const dir = join(process.env.PAI_DIR!, 'MEMORY');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'StopOrchestrator'), String(hookInput.session_id));
}
main();
