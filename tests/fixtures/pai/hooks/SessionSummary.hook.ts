import { writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';

async function main() {
  try {
    const input = await Bun.stdin.text();
    const dir = join(process.env.PAI_DIR!, 'MEMORY');
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'SessionSummary'), input);
  } catch {}
}
main();
