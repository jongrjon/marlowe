import { writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';

interface SecurityEvent { session_id: string; command: string }

function logSecurityEvent(event: SecurityEvent): void {
  const dir = join(process.env.PAI_DIR!, 'MEMORY');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'SecurityValidator'), event.command);
}

async function main(): Promise<void> {
  const input = JSON.parse(await Bun.stdin.text());
  logSecurityEvent({ session_id: input.session_id, command: 'x' });
  console.log(JSON.stringify({ continue: true }));
}
main();
