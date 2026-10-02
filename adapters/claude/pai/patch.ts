#!/usr/bin/env bun
/**
 * marlowe vault pai-patch — make PAI's capture hooks skip private sessions.
 *
 *   bun patch.ts            patch (idempotent; backs up originals first)
 *   bun patch.ts --check    report only; exit 1 if anything is unpatched
 *   bun patch.ts --quiet    print only problems
 *
 * Insertion points are found by pattern, not exact text, so minor PAI changes
 * don't break it. Each patched file is transpile-checked; on failure the
 * original is restored. Marker comment: "private-session patch".
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'fs';
import { join, dirname } from 'path';
import { homedir } from 'os';
import { spawnSync } from 'child_process';

const MARK = 'private-session patch';
const args = new Set(process.argv.slice(2));
const CHECK = args.has('--check');
const QUIET = args.has('--quiet');

const PAI = process.env.PAI_DIR || join(homedir(), '.claude');
const HOOKS = join(PAI, 'hooks');
const HERE = dirname(new URL(import.meta.url).pathname);

// Hooks that write captures or run inference on the user's words.
const TARGETS = [
  'AutoWorkCreation', 'FormatReminder', 'UpdateTabTitle',
  'ImplicitSentimentCapture', 'ExplicitRatingCapture',
  'WorkCompletionLearning', 'SessionSummary', 'AgentOutputCapture',
  'StopOrchestrator', 'RelationshipMemory', 'SoulEvolution',
  'SecurityValidator',
];
const INFERENCE = join(PAI, 'skills/PAI/Tools/Inference.ts');
const IMPORT = "import { isPrivate, isPrivateSessionId } from './lib/private';";

const log = (s: string) => { if (!QUIET) console.log(s); };
const warn = (s: string) => console.log(s);

function addImport(src: string): string {
  const lines = src.split('\n');
  let last = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^import\s/.test(lines[i])) {
      let j = i;
      while (j < lines.length && !/;\s*(\/\/.*)?$/.test(lines[j])) j++;
      last = j; i = j;
    }
  }
  lines.splice(last + 1, 0, IMPORT);
  return lines.join('\n');
}

function guardHook(name: string, src: string): string | null {
  if (name === 'SecurityValidator') {
    // Keep validating/blocking; only skip the MEMORY/SECURITY log.
    const re = /(function logSecurityEvent\s*\(\s*(\w+)[^)]*\)\s*(?::\s*\w+\s*)?\{\n)/;
    const m = src.match(re);
    if (!m) return null;
    return src.replace(re, `$1  if (isPrivateSessionId((${m[2]} as any)?.session_id)) return;  // ${MARK}\n`);
  }
  const main = src.search(/async function main\s*\(/);
  if (main < 0) return null;
  const head = src.slice(0, main), body = src.slice(main);
  const rules: RegExp[] = [
    // const data: HookInput = JSON.parse(input);
    /^([ \t]*)const (\w+)(?:\s*:\s*[\w<>\[\]]+)?\s*=\s*JSON\.parse\(\s*\w+\s*\)\s*(?:as\s+\w+\s*)?;[^\n]*\n/m,
    // const hookInput = await readStdin();   (object or string; isPrivate takes both)
    /^([ \t]*)const (\w+)(?:\s*:\s*[\w<>\[\]| ]+)?\s*=\s*await\s+readStdin\w*\([^)]*\)\s*;[^\n]*\n/m,
    // const input = await Bun.stdin.text();
    /^([ \t]*)const (\w+)\s*=\s*await\s+Bun\.stdin\.text\(\)\s*;[^\n]*\n/m,
  ];
  for (const re of rules) {
    const m = body.match(re);
    if (!m) continue;
    const [line, indent, v] = m;
    return head + body.replace(line, `${line}${indent}if (isPrivate(${v})) process.exit(0);  // ${MARK}\n`);
  }
  return null;
}

function transpiles(file: string): boolean {
  const r = spawnSync('bun', ['build', '--no-bundle', '--target=bun', file], { stdio: 'ignore' });
  return r.status === 0;
}

let backupDir = '';
function backup(file: string) {
  if (!backupDir) {
    backupDir = join(PAI, `hooks.bak-marlowe-${new Date().toISOString().slice(0, 10)}`);
    mkdirSync(backupDir, { recursive: true });
  }
  const dst = join(backupDir, file.slice(PAI.length + 1).replace(/\//g, '__'));
  if (!existsSync(dst)) copyFileSync(file, dst);
}

function patchFile(file: string, label: string, transform: (s: string) => string | null): 'ok' | 'patched' | 'missing' | 'failed' {
  if (!existsSync(file)) return 'missing';
  const src = readFileSync(file, 'utf-8');
  if (src.includes(MARK)) return 'ok';
  if (CHECK) return 'failed';
  const out = transform(src);
  if (!out) { warn(`  ! ${label}: no known insertion point — left unpatched`); return 'failed'; }
  backup(file);
  writeFileSync(file, out);
  if (!transpiles(file)) {
    writeFileSync(file, src);
    warn(`  ! ${label}: patched file didn't compile — original restored`);
    return 'failed';
  }
  return 'patched';
}

if (!existsSync(HOOKS)) { log('no PAI hooks found — nothing to patch'); process.exit(0); }

// 1. The guard library (always refreshed when it differs).
const libSrc = readFileSync(join(HERE, 'private.ts'), 'utf-8');
const libDst = join(HOOKS, 'lib/private.ts');
const libCurrent = existsSync(libDst) ? readFileSync(libDst, 'utf-8') : '';
let libState = libCurrent === libSrc ? 'ok' : 'stale';
if (libState === 'stale' && !CHECK) {
  mkdirSync(dirname(libDst), { recursive: true });
  writeFileSync(libDst, libSrc);
  libState = 'patched';
}

// 2. Hooks.
const results: Record<string, string> = { 'lib/private.ts': libState };
for (const name of TARGETS) {
  const file = join(HOOKS, `${name}.hook.ts`);
  results[name] = patchFile(file, name, src => {
    const g = guardHook(name, src);
    return g ? addImport(g) : null;
  });
}

// 3. Inference: stop `claude --print` leaving a transcript per call (all sessions).
results['Inference.ts'] = patchFile(INFERENCE, 'Inference.ts', src => {
  const re = /^([ \t]*)'--print',[^\n]*\n/m;
  const m = src.match(re);
  if (!m) return null;
  return src.replace(re, `${m[0]}${m[1]}'--no-session-persistence',  // ${MARK}: no transcript per call\n`);
});

// 4. Note for whoever upgrades PAI next.
if (!CHECK) {
  writeFileSync(join(HOOKS, 'PRIVATE-PATCH.md'), `# Private-session patch (managed by marlowe)

Applied by \`marlowe vault pai-patch\` — also run by \`marlowe apply claude\` and
re-checked at every SessionStart, so a PAI upgrade that overwrites hooks gets
re-patched automatically. Find patched lines: \`grep -rn '${MARK}' ${HOOKS} ${dirname(INFERENCE)}\`.
Originals: \`${PAI}/hooks.bak-marlowe-<date>/\`.

Capture hooks exit early for sessions listed in \`~/.marlowe/.vault-open\` (or a
prompt starting with /private). SecurityValidator still blocks; it only skips its
log. Inference.ts passes --no-session-persistence for every session.
`);
}

const bad = Object.entries(results).filter(([, s]) => s === 'failed' || s === 'stale');
for (const [k, s] of Object.entries(results)) {
  if (s === 'missing') continue;
  log(`  ${s === 'ok' ? '✓' : s === 'patched' ? '+' : '!'} ${k}${s === 'patched' ? ' (patched)' : s === 'ok' ? '' : ` (${CHECK ? 'unpatched' : s})`}`);
}
process.exit(bad.length ? 1 : 0);
