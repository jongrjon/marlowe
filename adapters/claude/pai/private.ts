/**
 * private.ts - Private-session guard. Installed by marlowe (`marlowe vault pai-patch`);
 * overwritten on every patch run, so don't edit it here.
 *
 * A session is private when its id is listed in the Marlowe vault marker
 * ($MARLOWE_HOME/.vault-open, one "<session_id>\t<pid>\t<started>\t<transcript>" per line),
 * or when the prompt itself starts with /private (UserPromptSubmit hooks run
 * in parallel, so the first /private prompt arrives before the marker exists).
 *
 * Capture hooks call this first and exit without writing or running inference.
 */

import { readFileSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

const MARKER = join(process.env.MARLOWE_HOME || join(homedir(), '.marlowe'), '.vault-open');

export function privateSessionIds(): Set<string> {
  try {
    return new Set(
      readFileSync(MARKER, 'utf-8')
        .split('\n')
        .map(l => l.trim().split(/\s+/)[0])
        .filter(Boolean)
    );
  } catch {
    return new Set();
  }
}

export function isPrivateSessionId(sessionId?: string): boolean {
  return !!sessionId && privateSessionIds().has(sessionId);
}

/** Accepts the parsed hook input or the raw stdin string. Never throws. */
export function isPrivate(input: unknown): boolean {
  try {
    let data: any = input;
    if (typeof data === 'string') data = JSON.parse(data);
    if (!data || typeof data !== 'object') return false;
    const prompt = String(data.prompt || data.user_prompt || '').trimStart();
    if (/^\/private\b/.test(prompt)) return true;
    return isPrivateSessionId(data.session_id);
  } catch {
    return false;
  }
}
