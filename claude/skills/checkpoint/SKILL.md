---
name: checkpoint
description: Save a dense, machine-readable checkpoint of the whole session (constraints, decisions, code patterns, current state, next steps) to ./CHECKPOINT.md so a new conversation can resume exactly here.
disable-model-invocation: true
---

# Session checkpoint

Summarize everything done so far in this conversation in as much detail as possible, but compress it heavily into a
machine-readable format that you can still interpret perfectly. It does not need to be human-readable. Keep all key
constraints, decisions made, code patterns established, and current state data intact so work can pick up right where
it left off if Keith starts a new conversation. Do not lose the nuance.

Compress the form, never the content: use terse, structured notation (short keys, lists, abbreviations you can still
decode), but do not drop a constraint, decision, or caveat to save space.

## What to cover

- Goal and task framing, including how it evolved during the session
- Constraints and preferences Keith stated, verbatim where wording matters
- Decisions made and the reason for each, including alternatives considered and rejected
- Code patterns and conventions established or discovered
- Files touched or relevant, and the state of each
- Git state: branch, commits made, uncommitted work
- Open questions and anything awaiting Keith's answer
- Exact next steps
- Gotchas: failed approaches, errors hit, things that look right but are not

## Format marker

Start the file with the exact first line `# CHECKPOINT v1`, which `load-checkpoint` requires. Tag each constraint,
preference, and decision `[user]` if Keith stated it directly this session, or `[inferred]` if you derived it, so the
loader can tell his own instructions from your guesses.

## Secrets

The file is plaintext in the working directory. Never copy credentials into it: tokens, passwords, API keys, private
key contents, or secret values seen in command output, env dumps, or pasted config. Record that a secret exists and
where it comes from (e.g. "API token read from $FOO_TOKEN"), not its value. This overrides the "verbatim" and "do
not lose the nuance" rules above: if a quoted constraint contains a secret, redact the secret and keep the rest.

## Writing the file

Choose a target path: `CHECKPOINT.md` in the current working directory by default.

If the target already exists, ask Keith with `AskUserQuestion` whether to overwrite it. If he declines, ask again with
`AskUserQuestion`: cancel, or save under a filename he provides (he can type it through the "Other" option). Apply the
same existence check and overwrite question to whatever path he provides. Never overwrite without an explicit yes, and
`Read` an existing file before overwriting it, since the Write tool requires that.

## After writing

Report the absolute path of the file actually written, and a one-line resume instruction built from that same path,
e.g. `In a new session: /load-checkpoint "/abs/path/to/CHECKPOINT.md"`. Keep the quotes around the path so it
survives spaces.
