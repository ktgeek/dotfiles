#!/bin/sh
# PreToolUse hook (Bash): ask before any `gh api` call that may mutate GitHub state, while
# leaving read-only calls silent. `gh api` has no argument shape that a permission-rule prefix
# can carve into read/write halves (see claude-code-payload skill for why), so this tokenizes
# the actual command text — properly, respecting shell quoting — instead of pattern-matching it.
#
# Fails closed throughout: anything this cannot positively prove is a read gets "ask", including
# a gh api mention this cannot resolve to a direct, literal invocation (it may be wrapped in
# bash -c/sh -c/eval or similar) and a real, unquoted shell operator of any kind. An occasional
# unnecessary prompt on an exotic form is the accepted cost; a write slipping through unrecognized
# is not. Emits nothing (-> no decision, falls through to the normal permission flow) for anything
# else, including every command that isn't a `gh api` call.
#
# jq is a hard dependency of this repo's whole Claude Code payload (already required by
# write-scope-ask.sh and bin/claude-merge-settings), but this hook is now the *only* gate on
# `gh api` — there's no longer a blanket permissions.ask rule backing it up — so if jq is ever
# missing, fail closed with a crude text search rather than silently letting every call through.
if ! command -v jq >/dev/null 2>&1; then
  input=$(cat)
  if printf '%s' "$input" \
      | grep -Eq '(^|[^A-Za-z0-9_])gh[[:space:]]+api([^A-Za-z0-9_]|$)'; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask",'
    printf '"permissionDecisionReason":"gh api call found but jq is unavailable to classify it safely"}}'
  fi
  exit 0
fi

# The jq program is read via a quoted heredoc (not embedded as a `jq -c '...'` single-quoted
# argument, as write-scope-ask.sh does) so it can use apostrophes in its own comments/messages
# and jq's `$name` variable syntax freely — a quoted delimiter ('JQEOF') disables all shell
# expansion of the body, so none of that is reinterpreted before jq ever sees it.
program=$(cat <<'JQEOF'
def CP_SQ: 39; def CP_DQ: 34; def CP_BS: 92; def CP_BQ: 96; def CP_DOLLAR: 36;
def CP_LP: 40; def CP_LT: 60; def CP_GT: 62; def CP_SEMI: 59; def CP_AMP: 38; def CP_PIPE: 124;
def CP_NL: 10; def CP_SP: 32; def CP_TAB: 9; def CP_CR: 13;

# Deliberately excludes CP_NL: a bare unquoted newline is a real POSIX-sh statement separator
# (same as ";"), not ordinary whitespace, and needs to reach the dedicated newline branch below.
def is_ws: . == CP_SP or . == CP_TAB or . == CP_CR;

# A quote-aware, character-by-character tokenizer: shell quoting can only be gotten right by
# tracking quote state as you scan, since e.g. an apostrophe inside a double-quoted argument
# and the quote characters that actually delimit a value are indistinguishable to anything that
# isn't tracking which state it's in. Stops at the first real (unquoted) shell operator and
# reports why, or at a real top-level `|` and reports what comes after it separately, so the
# classifier below only ever sees an honestly-tokenized argv.
def tokenize:
  . as $s
  | ($s | explode) as $cs
  | ($cs | length) as $n
  | (reduce range(0; $n) as $i
      ( {argv: [], cur: [], state: "n", esc: false, stopped: false, opReason: null, pipeRest: null}
      ; if .stopped then .
        else
          ($cs[$i]) as $c
          | ($cs[$i-1] // -1) as $c0
          | ($cs[$i+1] // -1) as $c2
          | if .esc then
              .cur += [$c] | .esc = false
            elif .state == "sq" and $c == CP_SQ then
              .state = "n"
            elif .state == "sq" then
              .cur += [$c]
            elif .state == "dq" and $c == CP_DQ then
              .state = "n"
            elif .state == "dq" and $c == CP_BS then
              .esc = true
            elif .state == "dq" and $c == CP_BQ then
              # Backtick and $( remain live even inside double quotes in real shell semantics.
              .stopped = true | .opReason = "command substitution (backtick) inside a double-quoted value"
            elif .state == "dq" and $c == CP_DOLLAR and $c2 == CP_LP then
              .stopped = true | .opReason = "command substitution ($() inside a double-quoted value"
            elif .state == "dq" then
              .cur += [$c]
            elif $c == CP_SQ then
              .state = "sq"
            elif $c == CP_DQ then
              .state = "dq"
            elif $c == CP_BS then
              .esc = true
            elif ($c|is_ws) then
              (if (.cur|length) > 0 then .argv += [(.cur|implode)] | .cur = [] else . end)
            elif $c == CP_BQ then
              .stopped = true | .opReason = "command substitution (backtick)"
            elif $c == CP_DOLLAR and $c2 == CP_LP then
              .stopped = true | .opReason = "command substitution ($()"
            elif $c == CP_LT and $c2 == CP_LP then
              .stopped = true | .opReason = "process substitution (<()"
            elif $c == CP_GT and $c2 == CP_LP then
              .stopped = true | .opReason = "process substitution (>()"
            elif $c == CP_LT and $c2 == CP_LT then
              .stopped = true | .opReason = "heredoc (<<)"
            elif $c == CP_SEMI then
              .stopped = true | .opReason = "statement separator (;)"
            elif $c == CP_NL then
              .stopped = true | .opReason = "bare newline outside any quoted value"
            elif $c == CP_AMP and ($c0 == CP_GT or $c2 == CP_GT) then
              # Part of a redirection operator (2>&1, >&2, &>out, &>>out), not background/chain
              # syntax — inert for our purposes, so it stays literal text rather than stopping.
              .cur += [$c]
            elif $c == CP_AMP then
              .stopped = true | .opReason = "background/chain operator (&)"
            elif $c == CP_PIPE and $c2 == CP_PIPE then
              .stopped = true | .opReason = "chain operator (||)"
            elif $c == CP_PIPE then
              # A single pipe is handled separately below (the common `gh api ... | jq ...`
              # idiom), so this only records where the primary segment ends.
              .stopped = true | .pipeRest = ($cs[($i+1):] | implode)
            else
              .cur += [$c]
            end
        end
      )
    )
  | (if (.cur|length) > 0 then .argv += [(.cur|implode)] else . end)
  | {argv, opReason, pipeRest}
  ;

# Word-boundary "gh api" match on raw, quote-unaware text: used as a cheap pre-filter (over-
# detection is harmless, it only routes into the real tokenizer below; under-detection would
# let a write through with no gate at all) and to check what is on the far side of a real pipe,
# where full tokenization is not attempted.
def looks_like_gh_api:
  test("(^|[^A-Za-z0-9_])gh[ \t\n\r]+api([^A-Za-z0-9_]|$)")
  ;

def gh_api_pair_index($argv):
  ($argv | length) as $n
  | [range(0; ([$n-1,0] | max)) | select(($argv[.] | test("(^|.*/)gh$")) and $argv[.+1] == "api")]
  | first
  ;

# Flag table transcribed from `gh api --help`. Keep this in sync if gh adds, renames, or
# changes the arity of an `api` flag — an unrecognized flag is ignored rather than guessed at.
def VALUE_SHORT: ["F","H","q","X","p","f","t"];
def VALUE_LONG: ["field","header","hostname","input","jq","method","preview","raw-field","template","cache"];
def BOOL_FLAGS: ["--allow-escape-sequences","-i","--include","--paginate","--silent","--slurp","--verbose","--help"];
def LONG_ALT: (VALUE_LONG | join("|"));

def is_get_or_head: ascii_downcase | . == "get" or . == "head";

# One name for a value-taking flag, whatever its spelling (-f, -F, --field, --raw-field): what
# the classifier below actually cares about. Anything else value-taking (-H, -q, -p, -t,
# --header, --hostname, --jq, --preview, --template, --cache) is "other" — recognized well
# enough to correctly skip its value, but otherwise irrelevant to read/write classification.
def flag_name($raw):
  if $raw == "f" or $raw == "F" or $raw == "field" or $raw == "raw-field" then "field"
  elif $raw == "X" or $raw == "method" then "method"
  elif $raw == "input" then "input"
  else "other"
  end
  ;

# Normalize argv into a flat list of {name, value} flag events plus {name: "positional"}
# entries, resolving every flag spelling gh accepts (bare short + next token, attached short
# -fVALUE, bare long + next token, attached long --field=VALUE) to the same shape, so the
# classifier below only has to handle each concern (method, field data, endpoint) once instead
# of once per spelling.
def normalize_events($rest):
  ($rest | length) as $n
  | (reduce range(0; $n) as $i
      ( {events: [], skip: false}
      ; if .skip then .skip = false
        else
          ($rest[$i]) as $tok
          | if ($tok|length) == 2 and $tok[0:1] == "-" and (VALUE_SHORT | index($tok[1:2])) then
              .events += [{name: flag_name($tok[1:2]), value: ($rest[$i+1] // "")}]
              | .skip = true
            elif ($tok | test("^--(" + LONG_ALT + ")$")) then
              .events += [{name: flag_name($tok[2:]), value: ($rest[$i+1] // "")}]
              | .skip = true
            elif ($tok|length) > 2 and $tok[0:1] == "-" and $tok[1:2] != "-"
                 and (VALUE_SHORT | index($tok[1:2])) then
              .events += [{name: flag_name($tok[1:2]), value: $tok[2:]}]
            elif ($tok | test("^--(" + LONG_ALT + ")=")) then
              ($tok | capture("^--(?<name>[a-z-]+)=(?<val>.*)$")) as $m
              | .events += [{name: flag_name($m.name), value: $m.val}]
            elif (BOOL_FLAGS | index($tok)) then
              .
            elif ($tok | startswith("-")) then
              .   # unrecognized flag: ignored, not treated as the endpoint
            else
              .events += [{name: "positional", value: $tok}]
            end
        end
      )
    ).events
  ;

# Per `gh api --help`, the default method is GET normally but POST if any parameters were
# added — so a REST write can have no -X/--method at all — while a graphql call is always a
# POST regardless, even for reads: only the operation type inside the query document says
# which. No permission-rule prefix can express either distinction; this is why it has to be a
# hook. Returns null (no ask) or an ask reason string.
def classify_rest($rest):
  (reduce normalize_events($rest)[] as $e
    ( {endpoint: null, methodBad: false, hasExplicitGet: false, hasFieldFlag: false,
       queryValue: null, hasFileOrStdinQuery: false}
    ; if $e.name == "positional" then
        (if .endpoint == null then .endpoint = $e.value else . end)
      elif $e.name == "method" then
        (if ($e.value | is_get_or_head) then .hasExplicitGet = true else .methodBad = true end)
      elif $e.name == "field" then
        .hasFieldFlag = true
        | (if ($e.value | startswith("query=")) then .queryValue = $e.value[6:] else . end)
      elif $e.name == "input" then
        .hasFieldFlag = true | .hasFileOrStdinQuery = true
      else
        .
      end
    )
  ) as $r
  | if $r.endpoint == "graphql" then
      if $r.hasFileOrStdinQuery then
        "gh api graphql query supplied from a file, stdin, or --input; cannot verify it is read-only"
      elif $r.queryValue == null then
        "gh api graphql call has no inline query text to verify; cannot confirm it is read-only"
      elif ($r.queryValue | startswith("@")) or $r.queryValue == "-" then
        "gh api graphql query supplied from a file or stdin; cannot verify it is read-only"
      elif ($r.queryValue | test("(^|[^A-Za-z0-9_])mutation([^A-Za-z0-9_]|$)")) then
        "gh api graphql call contains a mutation operation"
      else
        null
      end
    else
      if $r.methodBad then
        "gh api call uses a non-GET HTTP method"
      elif $r.hasFieldFlag and ($r.hasExplicitGet | not) then
        "gh api call includes field data, which defaults the request to POST"
      else
        null
      end
    end
  ;

def ask_obj($reason):
  {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}
  ;

(.tool_input.command // "") as $command
| if ($command | looks_like_gh_api | not) then
    empty
  else
    ($command | tokenize) as $tok
    | if $tok.opReason != null then
        ask_obj("gh api call combined with other shell operators (" + $tok.opReason + ")")
      else
        ( gh_api_pair_index($tok.argv) ) as $ghIdx
        | (if $ghIdx != null then classify_rest($tok.argv[($ghIdx+2):]) else null end) as $primaryReason
        | (if $tok.pipeRest != null
             and ( ($tok.pipeRest | looks_like_gh_api) or ($tok.pipeRest | test("mutation")) )
           then "gh api call piped into, or downstream of a pipe from, something mentioning"
                + " a mutation or another gh api call"
           else null end) as $pipeReason
        | if $ghIdx == null and $pipeReason == null then
            # The raw pre-filter saw "gh api" somewhere, but the tokenized primary command has
            # no literal, adjacent gh/api invocation and nothing past a pipe explains it either
            # — most likely gh api is wrapped inside something this cannot see into (bash -c,
            # sh -c, eval, a shell function or alias). Cannot positively clear it, so ask.
            ask_obj("gh api mentioned but not found as a direct invocation — it may be"
              + " wrapped (bash -c, sh -c, eval, ...) where this cannot verify it is read-only")
          elif ($primaryReason // $pipeReason) != null then
            ask_obj(($primaryReason // $pipeReason))
          else
            empty
          end
      end
  end
JQEOF
)

exec jq -c "$program"
