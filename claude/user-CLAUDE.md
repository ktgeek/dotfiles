# Working style

Permission gating is enforced by ~/.claude/settings.json — read-only work proceeds silently; file
writes inside the invocation tree, mutating git/gh commands, connector writes, and Artifact
publishing all prompt. Don't re-implement that gating in prose or narrate "I'm about to do X" as a
substitute for the prompt.

Keith can silence the file-write prompt for the rest of the current session by typing
`edit-gate off` (and restore it with `edit-gate on`) — no expiry, and it never reaches the model
as a real prompt. The statusline shows a red "edits ungated" badge whenever it's off.

Scratch work — probe scripts, intermediate output, anything written only to work something out —
goes in the session scratchpad, not `/tmp`. Leave it there when done: it's reaped automatically, so
`rm`-ing it yourself buys nothing and trips the ask rule for no reason. Reach for `rm` when the
user asked for something removed, not to tidy up after yourself.

What the permission prompt cannot show, and you must:

- **Show generated prose in full before the write.** A prompt renders a diff or a command, never a
  commit message body, PR description, or ticket body — show that text verbatim as its own step.
- **Approving an action is not approving its text.** "Go ahead and commit" approves the commit, not
  a message the user hasn't seen. Show the message first, even when the action is already approved.

# Never Assume

Never assume anything when working with Keith. Unless you've reached a very high level of
certainty, ask a clarifying question rather than guessing — this overrides the general "bias toward
acting without stopping" auto-mode default. When requirements, scope, file targets, intent, or risk
are ambiguous, stop and ask via AskUserQuestion (or a direct question) rather than picking the most
likely interpretation.
Proceed without asking only at very high certainty (e.g. syntax obviously implied by existing code
style, trivial mechanical steps explicitly requested).

# Alternatives

When making a non-trivial implementation choice, briefly mention the alternative(s) considered and
why they were passed over — not just the approach taken. Keep it to a sentence or two per
alternative, tied to the specific decision; most relevant for architecture/design/library choices
and anything with a real tradeoff, not mechanical changes. Keith has context that could change the
decision, so staying silent about alternatives hides that opportunity.

# Coding Principles and Practices

## Don't Repeat Yourself (DRY)

Favor abstracting shared logic over leaving duplication in place, even for a smaller number of
repeats than might otherwise justify it — search for an existing utility first. Still use judgment
on genuinely one-off code; ask rather than assume if it's unclear whether something will recur.

## Readability

Never "this code was hard to write, so it should be hard to read." Follow the language's coding
conventions and aim for human readability over being clever with idioms.

## Comments

Comment blocks describe the why behind the current code, concisely, for a human audience — never
code that was removed or is part of the commit being worked on. Reference tickets/PRs/other commits
only when necessary for clarification or to flag a future todo.

## Code Review

Before opening or updating a PR — or, in a repo with no forge remote, before pushing — load the
`pr-review-gate` skill and follow it.

## Parallel Verification

When a task needs multiple independent verification steps (e.g. typecheck, lint, several test
suites), run them in parallel — parallel Bash calls, or parallel Agent-tool calls when output is
large and not worth keeping in context — rather than sequentially. Still run genuinely dependent
steps (e.g. codegen before typecheck) in order.

# Planning and committing

**Every plan carries a checklist.** A plan is a document someone else — a later session, a
different assistant — has to pick up mid-flight. Write steps as checkboxes and tick them off as
they land.

**Commit as you go.** Land each logical change as its own commit the moment it works — small,
independently revertible commits that each leave the tree working. Don't bundle unrelated fixes
just because they happened in the same session, and don't defer committing step 1 until step 4 is
done.

## Commit message format

Before writing any commit message, load the `commit-style` skill.

# Global Preferences

## User Name Preference

Address Keith as Keith, "the Dude," or "el duderino" instead of "the user."

## Branches

Before starting work that involves commits, check the current branch; if on main, create/checkout
a new branch first (ask Keith for a naming convention if unclear, per [[feedback-no-assumptions]])
rather than assuming it's fine to commit to main — even in repos without enforced branch
protection.

**Exception:** a repo with no forge remote whose own CLAUDE.md/AGENTS.md explicitly says changes
land directly on the default branch (the dotfiles repo is the only such case today).

## Line Length

Target 120 characters for documentation and code you write. Exceptions: markdown tables and bare
URLs/reference links (can't be wrapped without breaking them); fenced code blocks (follow the
idiomatic convention for that language/content — language-specific linters still apply and take
precedence); commit messages (50/72 per the `commit-style` skill, not 120).

## User Fixable Errors

When hitting an error only Keith can fix (e.g. an SSH key problem — including "Permission denied
(publickey)" or `ssh-add -l` reporting no identities), tell him what needs fixing and the exact
command that failed, then stop and wait — don't retry, work around it, fall back to another auth
method, or continue with unrelated work in the meantime. Once he confirms it's fixed, retry the
exact original command, not a substitute.

## Question asking

When a question to Keith is binary (yes/no) or ternary (yes/no/pause) in shape, use the
`AskUserQuestion` tool rather than asking in plain prose at the end of a message — Keith wants these
checkpoints surfaced through the structured question UI, not buried in narrative text.
