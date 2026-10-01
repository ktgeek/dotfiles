---
name: claude-code-payload
description: How this repo ports Claude Code working-style memory, permission-gating settings, and user-level skills to other machines via install-claude — claude/user-CLAUDE.md, claude/settings-gating.json, claude/skills/, bin/claude-merge-settings, the write-scope hook, and the per-session edit-gate toggle. Load before editing anything under claude/, bin/claude-merge-settings, or the install-claude Makefile target.
---

# Claude Code config

`claude/` (no leading dot, deliberately — a leading-dot `.claude/CLAUDE.md` at the repo root
would itself be auto-loaded by Claude Code as this repo's own project memory) ports this
machine's Claude Code working-style memory and permission-gating settings to any other machine
running this repo, via the opt-in `install-claude` Makefile target — not part of
`all`/`install-mac`/`install-linux`, matching `install-ssh`'s precedent, and for the same
reason: it can fail outright (see below), which must never happen inside a routine `make`. For
the same reason, the payload memory file itself is named `user-CLAUDE.md`, not `CLAUDE.md`:
**any** `CLAUDE.md` file anywhere in the tree is auto-loaded as nested project memory under its
own directory, so a plain `claude/CLAUDE.md` would double as (wrong) guidance for work done
under `claude/`, on top of being the payload these files exist to install elsewhere.

- `claude/user-CLAUDE.md` → symlinked to `~/.claude/CLAUDE.md`, same as every other dotfile
  here. This is safe specifically because Claude Code documents `CLAUDE.md` as symlink-friendly
  and never writes to it itself (auto-memory is separate, under
  `~/.claude/projects/<project>/memory/`). `install-claude` **fails if `~/.claude/CLAUDE.md`
  already exists** and isn't already a symlink into this repo's `claude/` directory — it must
  never silently clobber someone's existing working-style notes. No-ops once already linked at
  the current path; if it's linked to an older path inside this repo's `claude/` (e.g. from
  before a payload rename), it re-points the symlink instead of failing, so the target stays
  safe to re-run.
- `claude/settings-gating.json` — only the keys this repo owns from `~/.claude/settings.json`:
  `permissions.ask`, `statusLine`, `hooks.<event>` (today: `PreToolUse` and `UserPromptSubmit`),
  `autoMode.soft_deny`. **This one is merged into `~/.claude/settings.json` in place, never
  symlinked** — unlike `CLAUDE.md`, Claude Code itself rewrites `settings.json` (model/theme
  changes via `/config`, every "Yes, and don't ask again" permission approval), and there's no
  include/`extends`/fragment mechanism for settings files to lean on instead. `bin/claude-merge-settings`
  does the merge: `permissions.ask` is replaced wholesale, so a rule deleted from the fragment
  actually disappears on every machine. `hooks.<event>` replacement is per hook *event*, looping
  over whichever events the fragment's own `.hooks` object uses (not hardcoded to `PreToolUse` —
  the edit-gate toggle below needed `UserPromptSubmit` merged the identical way), and within each
  event, per hook *command* rather than per matcher group: a target command the fragment also
  supplies (ours) is replaced silently, and any other command sitting under a matcher the
  fragment claims is an "extra", prompted the same way a `soft_deny` extra is; a kept extra is
  spliced into the fragment's own group for that matcher, never written out as a second group
  sharing the same matcher string. An event's groups that have no `.matcher` at all (e.g.
  `UserPromptSubmit`, which isn't tool-scoped) are treated as matcher `""` throughout, so the
  same per-event logic applies unchanged. "Ours" isn't exact command-string equality, though —
  it's whether the command points into this repo's managed hooks directory (`$HOME/.claude/hooks/`,
  per `claude/hooks/*.sh`'s argument-free-path convention below): a target command there is always
  superseded by the fragment's current entry for that matcher, never offered as a keep/drop extra,
  even if its exact text has since changed (e.g. a renamed script) — so a stale reference to an
  already-relinked-or-removed hook can't linger in `settings.json`. An event the fragment doesn't
  use at all is left completely untouched on the target, matchers and all. Everything else in
  `settings.json` (`model`, `tui`, `permissions.allow`/`deny`, `autoMode.environment`) is left
  alone. `autoMode.soft_deny` is merged **additively**: a machine may have its own local prose
  rules there (this one has a work-repo-specific line, deliberately excluded from the fragment as
  non-portable), so the script computes `target - fragment` as "extras" too. `statusLine` is
  replaced wholesale, the same treatment as `permissions.ask` — there's no fragment/include
  mechanism for settings.json to lean on there either, and no legitimate reason for a machine to
  want a different statusline than the one this repo ships. Both extras categories share one
  prompting function — `[K]eep` (default) or `d`elete per extra, reading and writing `/dev/tty`
  directly rather than stdin/stdout, so it behaves the same whether invoked from an interactive
  shell or through `make`. `--keep-extra`/`--drop-extra` skip the prompt for scripted use, for
  both categories at once; with neither flag and no `/dev/tty` available at all, extras are kept
  and named on stderr rather than the script hanging or silently discarding local config. No
  answer is ever remembered — a kept extra is still an extra next run and gets asked about again,
  since this target is opt-in and rare enough that the periodic review is the point, not friction
  to route around. The merge writes atomically (temp file + `mv`) after `jq` has validated the
  result, backs up the previous file to `settings.json.bak` first, and skips writing entirely
  when the merge result is byte-identical to what's already there.
- `claude/hooks/*.sh` are `PreToolUse`/`UserPromptSubmit` hooks, symlinked to `~/.claude/hooks/`
  via a glob in `install-claude` (so a new hook file needs no Makefile edit — only its
  `settings-gating.json` entry). Before that glob runs, `install-claude` first sweeps
  `~/.claude/hooks/` for any dangling symlink and removes it — the glob itself only adds or
  overwrites, so a hook later renamed or removed from the repo would otherwise leave a stale
  symlink behind forever on a machine that already ran the target; the sweep means a removal
  needs no Makefile edit either. `write-scope-ask.sh`, the write-scope hook, was extracted out of
  what used to be an escaped jq one-liner embedded directly in `settings.json` — unreadable and
  uncommentable there. The fragment's hook entries reference each script as
  `"$HOME/.claude/hooks/<name>.sh"`: hook commands run through a shell so `$HOME` expands, there's
  no user-level equivalent of project hooks' `$CLAUDE_PROJECT_DIR`, and anchoring on `$HOME` keeps
  the reference correct regardless of where this repo was cloned. Being real symlinked files, not
  JSON-embedded text, means editing a hook's *behavior* takes effect on every machine immediately
  with no re-merge — only changes to the permission lists themselves (which entries exist, and
  their `matcher`s) need `make install-claude` re-run.
  - **The per-session edit-gate toggle** (`edit-gate-common.sh`, `edit-gate-toggle.sh`) lets
    Keith silence `write-scope-ask.sh`'s prompt for the rest of the *current* session by typing
    `edit-gate off` as a whole prompt (`edit-gate on` restores it; bare `edit-gate` reports
    state) — added because Shift+Tab to acceptEdits also leaves auto mode, which isn't what he
    wants. `edit-gate-toggle.sh` is a `UserPromptSubmit` hook: it recognizes those three exact
    prompts (whitespace-trimmed, read from the event's `.prompt` field — **not** `.user_input`,
    which doesn't exist on this event; an earlier draft read the wrong field and the whole
    toggle silently did nothing until a code review caught it against the real hook schema) and
    intercepts them with a top-level `{"decision":"block", "reason":...}` — note this event's
    block schema is *not* the `hookSpecificOutput`/`permissionDecision` shape `PreToolUse` uses;
    the two events have genuinely different output contracts. Anything else it sees passes
    through untouched. The toggle state is a per-session sentinel file,
    `$HOME/.local/state/claude-edit-gate/<session_id>` (path built by `edit_gate_sentinel` in
    `edit-gate-common.sh`, sourced — not executed — by all three scripts below). It deliberately
    lives outside `~/.claude`: `write-scope-ask.sh` already lets writes under `~/.claude` through
    silently, so a sentinel there would let the model flip its own gate off unnoticed via an
    ordinary Write call. Two things close that off instead: `write-scope-ask.sh` always asks on
    any write *into* the sentinel directory regardless of gate state, and
    `settings-gating.json`'s `autoMode.soft_deny` list has a matching line for the Bash side. No
    expiry and no `SessionEnd` cleanup — session IDs are unique, so a sentinel left behind by an
    ended session is inert, and skipping cleanup means one fewer event for
    `bin/claude-merge-settings` to merge. A session only sees this hook once its hooks are
    (re)loaded — starting fresh or `/resume`ing — after a `make install-claude` that added it.
    `write-scope-ask.sh` and `statusline.sh` (below) both need "is THIS session's gate open", not
    just the sentinel path, so that check is centralized too: `edit_gate_is_open` in
    `edit-gate-common.sh` extracts `.session_id` from the hook's own input JSON and fails CLOSED
    (gate treated as not-open) on a missing/empty one — it does NOT fall through to
    `edit_gate_sentinel("")`, which resolves to the sentinel *directory* itself and, once that
    directory exists (permanently, by design, after the first `edit-gate off` anywhere), would
    read as "open" for every session forever. That collapse was a real, empirically-reproduced
    bug in an earlier draft, caught the same review pass as the `.prompt` field above — both
    scripts had their own duplicate copy of the session_id extraction, and only one of the two
    got an empty-guard. One shared helper instead of N duplicated checks. `write-scope-ask.sh`
    also reads `.tool_input.notebook_path` as a fallback to `.tool_input.file_path`, since
    NotebookEdit (one of the three tools this hook's matcher covers) uses that key instead.
- `claude/hooks/gh-api-write-ask.sh` gates `gh api` the way `permissions.ask` prefix rules
  can't. Gotchas worth knowing before touching either:
  - **`Bash(x:*)` requires a following space** — it's exactly `Bash(x *)`, not a raw prefix.
    `Bash(gh api -X:*)` therefore misses `gh api -XPOST …` and `Bash(gh api --method:*)` misses
    `gh api --method=POST …`. Argument-adjacent patterns like that need to drop the colon
    (`Bash(gh api -X*)`) or, if the split isn't expressible as a prefix at all, be done in a
    hook instead.
  - **`gh api`'s read/write split isn't in the command prefix.** Per `gh api --help`, the
    default method is `GET` normally but **`POST` if any parameters were added** — so
    `gh api repos/o/r/issues -f title=x` is a write with no `-X`/`--method` anywhere, and the
    same `-f` flag that makes a REST call a write is neutral on a `graphql` endpoint, which is
    *always* a POST — there, only the operation type inside the query document (`query` vs
    `mutation`) says which it is. No permission-rule prefix can encode either distinction, so
    the hook parses the actual command text and fails closed: anything it can't positively
    prove is a read gets `ask`, rather than risk a write it didn't recognize slipping through
    silently.
  - **Regex-based quote handling cannot be made sound — parsing has to track quote state.**
    An apostrophe inside an unrelated double-quoted argument (e.g. `-q "it's ok"`) is
    indistinguishable from a real delimiting quote to anything that isn't tracking which
    quote state it's currently in, so a regex-driven strip of `'...'` spans pairs it with a
    *later* real closing quote and deletes everything between them, injected shell operators
    included — and a raw `|` split has the identical failure mode for a literal pipe character
    inside a quoted value. The hook is one `jq` filter: a character-by-character state machine
    (`explode`/`implode` over codepoints) that tracks single-/double-quote state properly and
    produces a real `argv`, plus a flag table transcribed from `gh api --help` so a flag's
    *value* token is never mistaken for the endpoint (`gh api graphql -f query=…` is not an
    endpoint named `query=…`). This sidesteps the BSD-vs-GNU grep/sed divergence entirely — `jq`
    behaves identically on macOS and Linux — while staying one process per invocation. The jq
    program is embedded via a **quoted heredoc** (`<<'JQEOF'`), not a `jq -c '...'` single-quoted
    argument the way `write-scope-ask.sh` does it: a quoted heredoc delimiter disables all shell
    expansion of the body, so the filter's own comments can use apostrophes freely and jq's
    `$name` variable syntax is never mistaken for a shell variable. If `jq` itself is missing,
    the hook falls back to a crude `grep`-only "does this look like `gh api`" check and asks
    unconditionally when it matches — `jq` is otherwise a hard dependency and there is no
    longer a blanket `permissions.ask` rule behind this hook to fail back to.
  - **A bare, unquoted newline is a real POSIX-sh statement separator, same as `;`** — it is
    *not* ordinary whitespace, even though it looks like it inside a Bash-tool command string
    that happens to span multiple lines. Folding it into the tokenizer's whitespace class
    silently defeats the "ask on any unquoted operator" invariant: two `gh api` calls on
    separate lines then merge into one token stream, and an explicit `-X GET` on the first can
    mask a real, unqualified write on the second. The newline case has to be checked *before*
    the whitespace case, not lumped into it.
  - **Detecting "does this command literally say `gh api`" is not the same question as "does
    this command invoke `gh api`."** `bash -c 'gh api ... -f ...'`, `sh -c '...'`, and
    `eval "..."` all contain the raw text `gh api` while never producing `gh` and `api` as
    separate, adjacent tokens in the *outer* command's own argv — the whole inner invocation is
    one opaque quoted string as far as outer tokenization is concerned, and nothing this hook
    can see distinguishes a wrapped write from wrapped, harmless prose mentioning `gh api`.
    Rather than enumerate every wrapping form (an open-ended list — `sh -c`, `eval`, `xargs`,
    aliases, functions, …), the hook applies one rule where the raw pre-filter matches but real
    tokenization cannot pin down a literal, adjacent `gh`/`api` pair: ask, don't assume it was
    benign prose. This closes the whole wrapper class in one place instead of chasing each form.
  - **Process substitution (`<(...)`/`>(...)`) executes as a side effect of the shell parsing
    the command line, whether or not `gh api` itself ever reads the resulting file descriptor**
    — so it needs the same "stop and ask" treatment as `` ` `` / `$(...)`, not just those two.
  - **A bare `&` is not always the backgrounding/chain operator.** It is also half of the
    redirection-duplication syntax (`2>&1`, `>&2`, `&>out`), which is pure I/O plumbing with no
    code-execution implication — asking on every occurrence of that idiom would defeat "stay
    silent for reads" for one of the most common shell constructs there is. Telling them apart
    needs one character of lookback as well as lookahead (is a `>` immediately before or after).
- `claude/statusline.omp.json` — the oh-my-posh theme for Claude Code's `statusLine`, symlinked to
  `~/.claude/statusline.omp.json` by `install-claude` (a plain single-file symlink, not the
  CLAUDE.md special-case above — there's no double-load hazard for a theme file). Styled to match
  `.zsh/kgarner.omp.json` (same schema version, powerline style, numeric 256-color palette,
  `path`/`git` segments copied verbatim for visual consistency between the two prompts), but built
  from oh-my-posh's native `claude` segment type instead of `jq`/shell scripting — it reads the
  same JSON Claude Code feeds any statusline command, and multiple `claude`-type segments can be
  mixed freely in one theme since they all read from the same session-cached data. Threshold-colored
  segments (5-hour rate limit gauge, context-window gauge) compare oh-my-posh's `Percentage`-typed
  fields directly (`{{ if ge .FiveHourUsage 90 }}`) rather than via `toInt`/`.String` — `toInt` on a
  segment's own `.String` output isn't a valid template function in this oh-my-posh version
  (confirmed by testing, not just reading docs) and silently renders "invalid template text". The
  second line's leading `text`-type segment renders a red "edits ungated" badge from
  `{{ .Env.CLAUDE_EDIT_GATE }}`, hidden (as every other conditional segment in this theme is) by
  templating to an empty string when the edit gate is on — oh-my-posh doesn't draw a segment
  whose template renders empty.
- `claude/statusline.sh` — the actual `statusLine.command` fragment entry now points here rather
  than at an inline shell one-liner, because the edit-gate badge above needs `CLAUDE_EDIT_GATE`
  set from the *session's own* sentinel file, and an oh-my-posh `claude`/`text` segment has no way
  to test file existence or read an arbitrary path itself. This script reads the same statusline
  JSON from stdin and exports `CLAUDE_EDIT_GATE=off` when `edit_gate_is_open` (sourced from
  `edit-gate-common.sh` — see the fail-closed note on it above) says this session's gate is open,
  then re-emits the same JSON unchanged to `oh-my-posh claude --config .../statusline.omp.json`.
  It keeps the
  same "hard dependency, degrade gracefully if the binary is missing" guard
  (`command -v oh-my-posh || exit 0`) the old inline command used — still relevant because
  `install-claude` is opt-in and separate from `install-mac`/`install-linux`, so a machine could
  run one without the other. Symlinked to `~/.claude/statusline.sh` by `install-claude`, right
  next to the theme file.
- `jq` is a hard runtime dependency of the hooks and the merge script alike, and is now in both
  `install-homebrew-packages` and `install-linux-packages` (previously present on this
  particular machine only because recent macOS happens to ship it).
- `claude/skills/<name>/SKILL.md` are user-level skills — conditional guidance that would
  otherwise sit always-on in `user-CLAUDE.md` — symlinked as whole directories (not their
  `SKILL.md` alone, so a skill can grow supporting files later) to `~/.claude/skills/` by
  `install-claude`, the same glob-plus-stale-sweep pattern as `claude/hooks/*.sh` above: a
  renamed or removed skill directory would otherwise leave a dangling symlink behind forever,
  since the glob only adds or overwrites. The glob is looped rather than a bare
  `ln -sfn claude/skills/*/ ...` so an empty `claude/skills/` (no skills yet) doesn't pass `ln`
  a literal, unmatched glob string. Each extracted section leaves a one-line pointer behind in
  `user-CLAUDE.md` naming the skill and its trigger condition — the skill's own frontmatter
  `description` restates that trigger, since that's what the *listing* (not the pointer prose)
  surfaces every session regardless of which project's memory is loaded.
