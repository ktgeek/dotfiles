---
name: claude-code-payload
description: How this repo ports Claude Code working-style memory, permission-gating settings, and user-level skills to other machines via install-claude — claude/user-CLAUDE.md, claude/settings-gating.json, claude/skills/, bin/claude-merge-settings, and the `gh api` write-gating hook. Load before editing anything under claude/, bin/claude-merge-settings, or the install-claude Makefile target.
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
  `permissions.ask`, `statusLine`, `hooks.<event>` (today: just `PreToolUse`),
  `autoMode.soft_deny`. **This one is merged into `~/.claude/settings.json` in place, never
  symlinked** — unlike `CLAUDE.md`, Claude Code itself rewrites `settings.json` (model/theme
  changes via `/config`, every "Yes, and don't ask again" permission approval), and there's no
  include/`extends`/fragment mechanism for settings files to lean on instead. `bin/claude-merge-settings`
  does the merge: `permissions.ask` is replaced wholesale, so a rule deleted from the fragment
  actually disappears on every machine. `hooks.<event>` replacement is per hook *event*, looping
  over whichever events the fragment's own `.hooks` object uses (not hardcoded to `PreToolUse`,
  so a fragment can use any event), and within each
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
  already-relinked-or-removed hook can't linger in `settings.json`. The same rule applies to
  events and matchers the fragment *no longer* claims: before merging, the script prunes every
  managed command from the whole target `.hooks` and drops any group or event that pruning left
  empty, so removing a hook (or a whole event) from the fragment removes it from `settings.json`
  on the next `make install-claude` instead of leaving a command pointing at a deleted script.
  Non-managed commands under unclaimed events and matchers are left untouched. Everything else in
  `settings.json` (`model`, `tui`, `permissions.allow`/`deny`, `autoMode.environment`) is left
  alone. `autoMode.soft_deny` is merged **additively**: a machine may have its own local prose
  rules there (non-portable, machine-specific lines the fragment deliberately leaves out), so the
  script computes `target - fragment` as "extras" too. The flip side: a rule removed from the
  fragment lingers on every machine as an extra until it's answered `d`elete (or `--drop-extra` is
  given), unlike `permissions.ask`, which disappears on its own. `statusLine` is
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
- `claude/hooks/*.sh` are `PreToolUse` hooks, symlinked to `~/.claude/hooks/`
  via a glob in `install-claude` (so a new hook file needs no Makefile edit — only its
  `settings-gating.json` entry). Before that glob runs, `install-claude` first sweeps
  `~/.claude/hooks/` for any dangling symlink and removes it — the glob itself only adds or
  overwrites, so a hook later renamed or removed from the repo would otherwise leave a stale
  symlink behind forever on a machine that already ran the target; the sweep means a removal
  needs no Makefile edit either. The fragment's hook entries reference each script as
  `"$HOME/.claude/hooks/<name>.sh"`: hook commands run through a shell so `$HOME` expands, there's
  no user-level equivalent of project hooks' `$CLAUDE_PROJECT_DIR`, and anchoring on `$HOME` keeps
  the reference correct regardless of where this repo was cloned. Being real symlinked files, not
  JSON-embedded text, means editing a hook's *behavior* takes effect on every machine immediately
  with no re-merge — only changes to the permission lists themselves (which entries exist, and
  their `matcher`s) need `make install-claude` re-run.
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
    argument: a quoted heredoc delimiter disables all shell
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
  (confirmed by testing, not just reading docs) and silently renders "invalid template text".
  Segment settings go under `"options"`, not the deprecated `"properties"` key (see the
  `zsh-config` skill), same as the zsh theme.
  The prompt-cache segment (hit-ratio gauge; just a light-on-grey "cold" once the cache TTL
  lapses, since the ratio is stale by then) is guarded on `.PromptCache`, which is nil until the
  first API response and absent on Claude Code < 2.1.251, so it stays hidden there. The guard
  does not cover an oh-my-posh older than 31.5.0: the field doesn't exist, so the segment renders
  "invalid template text" instead of hiding. Keep the binary at ≥ 31.5.0 on every host.
- `claude/statusline.sh` — the `statusLine.command` fragment entry points here rather than at an
  inline shell one-liner. It pipes the statusline JSON from stdin into
  `oh-my-posh claude --config .../statusline.omp.json`, behind a "hard dependency, degrade
  gracefully if the binary is missing" guard (`command -v oh-my-posh || exit 0`) — relevant because
  `install-claude` is opt-in and separate from `install-mac`/`install-linux`, so a machine could
  run one without the other. It stays a script rather than reverting to an inline command because
  `install-claude` only sweeps dangling symlinks under `hooks/` and `skills/`, so removing the file
  would leave a stale `~/.claude/statusline.sh` link behind. Symlinked to `~/.claude/statusline.sh`
  by `install-claude`, right next to the theme file.
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
  surfaces every session regardless of which project's memory is loaded. The exception is a
  user-invoked command skill (e.g. `checkpoint`), which sets `disable-model-invocation: true`
  in its frontmatter: Claude never triggers it, it stays out of the model's skill listing, and
  it gets no pointer in `user-CLAUDE.md` because there is no trigger condition to point at. That
  is deliberate, not a missing pointer. New slash commands go here as `claude/skills/<name>/`,
  not a separate `commands/` directory — Claude Code has merged custom commands into skills,
  so `install-claude` has no `commands/` install path. `checkpoint` and `load-checkpoint` are a
  pair: the first writes `CHECKPOINT.md` (or a chosen path) starting with the `# CHECKPOINT v1`
  marker and prints a quoted `/load-checkpoint "<abs path>"` resume line; the second requires
  that marker and treats the file as untrusted data. The first also tags constraints and
  decisions `[user]` or `[inferred]`, which the second shows in its recap. Changing the marker,
  the tag vocabulary, the resume-line format, or the default filename means editing both.
