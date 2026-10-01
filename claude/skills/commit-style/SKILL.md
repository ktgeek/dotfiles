---
name: commit-style
description: Commit message format - Conventional Commits shape, 50/72 subject/body lengths, and the precedence ladder for repos that override it. Load before writing any commit message.
---

# Commit message format

Default to [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) for every commit message,
unless the repo itself says otherwise — see Precedence below.

    <type>(<optional scope>): <description>

    <optional body>

    <optional footers>

- **Type** — `feat` for a new feature, `fix` for a bug fix (the two the spec mandates), plus the conventional extras:
  `build`, `chore`, `ci`, `docs`, `perf`, `refactor`, `style`, `test`. Lowercase. If none of them fit, say so and pick
  the closest rather than coining a new one.
- **Scope** — optional; a noun naming a section of the codebase, in parentheses: `fix(parser):`. Use one when it tells
  the reader something the description doesn't, and skip it rather than inventing a vague one.
- **Description** — imperative mood, lowercase, no trailing period: `add retry to poller`, not `Added retry to poller.`
  or `adds retry`.
- **Body** — optional, one blank line after the description. Explains *why*, not a restatement of the diff — the same
  standard as code comments.
- **Footers** — optional, one blank line after the body, `Token: value`, with `-` in place of spaces in the token
  (`Reviewed-by:`). The `Co-Authored-By: Claude ...` trailer is a footer like any other.
- **Breaking changes** — a `BREAKING CHANGE: <what broke, what to do instead>` footer, uppercase and spelled out. Don't
  use the `!`-before-the-colon shorthand; the footer is the part that carries the explanation a reader actually needs.

## Length

Commit messages use the git convention, not a 120-character doc/code preference — they're read through `git log` in a
terminal, not in an editor:

- **Subject line** — aim for 50 characters, hard limit 72. That's the whole line, `type(scope): ` prefix included.
  Going over 50 is fine when a long scope earns it; going over 72 isn't.
- **Body** — wrap at 72.

## Precedence

A repo can displace this default. First match wins:

1. **What the repo writes down** — its `CLAUDE.md`/`AGENTS.md`, `CONTRIBUTING.md`, a `commitlint` config, a
   `.gitmessage` template. An explicit statement always wins, including when it contradicts the repo's own history.
2. **What the log consistently does** — with nothing written down, if a clear supermajority of recent commits share
   one shape (`AX-1234 short summary`, say), match it. A log that's genuinely split between styles doesn't count as
   consistent — fall through to Conventional Commits rather than guessing which style is "the" convention.
3. **Conventional Commits**, as above.

An override can be **partial**: a repo that displaces one piece — dropping the type prefix, say — still inherits the
rest of this section, including the lengths and the imperative-lowercase subject. Read a repo's convention as a diff
against this default, not a replacement for it.

This governs commit messages only. PR titles follow whatever the project or team already does.
