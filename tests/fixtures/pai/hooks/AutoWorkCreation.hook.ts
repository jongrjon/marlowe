import { writeFileSync, mkdirSync } from 'fs';
import {
  join,
} from 'path';

interface HookInput { session_id: string; prompt?: string }

async function readStdinWithTimeout(): Promise<string> { return await Bun.stdin.text(); }

async function main() {
  try {
    const input = await readStdinWithTimeout();
    const data: HookInput = JSON.parse(input);
    const dir = join(process.env.PAI_DIR!, 'MEMORY');
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'AutoWorkCreation'), data.prompt || '');
  } catch {}
}
main();
