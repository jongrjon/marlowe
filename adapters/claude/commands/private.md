---
description: Start (or end) a private session backed by the encrypted Marlowe vault
argument-hint: "[end]"
allowed-tools: Bash(marlowe vault:*), Read, Edit, Write
---

<!-- installed by marlowe (adapters/claude/commands/private.md); edits here are overwritten -->

This session is private. A hook has already registered it, so PAI capture is off.
Claude Code's own transcript, prompt history and paste cache for it are archived
into ~/.private (encrypted) and removed when the session ends. If the terminal is
closed instead, the next session does the same cleanup.

Argument: `$ARGUMENTS`

## If the argument is `end`
1. Update the vault state file (path from `marlowe vault status`, or the one you
   opened earlier). Rewrite **Now** and **Open threads / next steps** to match where
   things stand, and add one dated line to the top of **Log**.
2. Run `marlowe vault seal`.
3. Reply in one line: sealed, plus anything left open. The session stays private
   until it exits.

## Otherwise (start)
1. Run `marlowe vault open`. A passphrase dialog opens on the user's screen. If it
   fails because no dialog can open (SSH, no display), ask the user to run
   `! marlowe vault open` themselves, then carry on.
2. Read the `state:` path it prints. That file is the whole carried-over context.
3. Give a short catch-up (where things stand, what's open) and ask where to pick
   up. If `$ARGUMENTS` already says, start there instead.

## Rules for the whole session
- **Keep the state file current.** Edit it as soon as a decision, new fact or next
  step comes up, not just at the end. The Stop hook encrypts it after every reply,
  so an edit is saved within one turn.
- Keep it under ~100 lines, made of conclusions. Condense old log lines. Other
  people's private disclosures stay out of it: summarise what they mean for the
  user, nothing more.
- Never run `marlowe remember`, `draft` or `add` here (they refuse anyway). Never
  write private content anywhere except the state file's RAM directory.
- Need older detail? `ls ~/.private` lists the archives. Opening one goes through the
  user (`! gpg -d …`), and it is decrypted into `/dev/shm`, never `/tmp`.
