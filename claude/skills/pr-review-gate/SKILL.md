---
name: pr-review-gate
description: Independent full-diff code review required before opening or updating a PR - or, in a repo with no forge remote, before pushing. Load before any of those actions.
---

# Code review before "ready for a human"

Before any action that signals a branch is ready for a human to look at it — opening a PR, updating an existing PR
(body, force-push after a rebase), etc. — run an independent code review of the entire PR diff, not just the
newly-edited files, as if seeing it for the first time / as another reviewer would. Use the `code-review` skill at
high effort against the full diff (e.g. `main...HEAD` for a feature branch), not just `git diff` of uncommitted
changes. Don't stop at the diff's own lines — pull in whatever surrounding context from the rest of the project is
needed to judge it properly (how a changed function is called elsewhere, how a config interacts with files it
didn't touch, etc.); the diff is the review's subject, not the limit of what it may read.

A plain `git push` of a branch that has no PR yet and isn't about to get one — e.g. pushing up before stopping for
the night just to have a non-local copy — is not that signal and doesn't require a review first. The PR (opening
one, or updating one that exists) is what marks "ready for a human"; pushing a branch by itself doesn't.

**Exception:** for a repo with no forge remote (no GitHub/GitLab/etc. `origin` — a bare repo on Keith's own
server, reached over SSH, is the case in mind), there's no PR to gate on, so the push itself is the only point
before the commits leave the local machine. Run the review before that push instead, on the diff that's about to
go out (e.g. `origin/main...HEAD` or equivalent), even for a routine end-of-session push.

**Why:** The user wants a self-check gate between "I made the fixes" and "this goes out the door," treating the
review as a fresh outside party rather than trusting the same reasoning that produced the changes. The gate is tied
to the PR because that's the actual signal of readiness for human review in a forge workflow — not to pushing,
which a branch can do for backup purposes long before it's ready for anyone to look at it. Where there's no forge
and no PR at all, the push to the remote is the only remaining moment that plays that role, so it has to carry the
gate itself.

**How to apply:** Treat this as a standing step in the workflow: implement → verify → independent code review of the
full diff → then open/update the PR (or push, for a no-forge repo). In a written plan, place the review as the step
immediately before "open PR" / "update PR" — or before "push" in a no-forge repo — not before every push in a repo
that does have PRs. Don't skip it because the diff is small or because the individual pieces were already tested —
the point is to catch what the implementing pass couldn't see, including issues spanning files that were reviewed
individually but not as a whole.
