Split the current working tree into atomic Git commits.

## Execution

One-shot LazyGit hotkey, no follow-up. Decide, act, report.
Use noninteractive commands: `git --no-pager` for diffs and `git commit -m`.
Only stage and commit changes. Keep remotes and existing history unchanged.
Use Read for surrounding code. If a required permission is denied, report it
and stop rather than trying another way to run the same operation.

## Steps

1. Confirm a Git repo with `git rev-parse --show-toplevel`. Stop during a
   merge, rebase, cherry-pick, or when there are conflicts.
2. Inspect `git status --short`, `git --no-pager diff --cached`,
   `git --no-pager diff`, and `git ls-files --others --exclude-standard`.
   Classify every path as staged, unstaged, untracked, or empty.
3. Empty tree: report nothing to commit and stop.
4. Group by intent. Each commit must be independently reviewable. Use the
   smallest sensible number; one logical change stays one commit.
   Assign every changed path to one group or list it as leftover.
5. Already-staged changes are group one. Commit that exact index without
   adding unstaged hunks. For later groups, use `git add -- <paths>`.
   Leave secrets, `.env` files, credentials, and build artifacts unstaged.
   Stop if a selected group contains secrets or conflict markers.
   Files with unrelated mixed hunks stay uncommitted, except for their
   already-staged changes. Report remaining hunks as leftover.
6. Order later groups by dependency: shared utility before callers, schema
   before consumers.
7. Message: `scope: Imperative summary`. Scope names a subsystem such as
   `web`, `auth`, `parser`, or `api`, not a path. Use an imperative verb, no
   trailing period, and a subject under 72 characters. Add a body only when
   needed to explain why.
8. Per group, inspect the staged diff, use `git commit -m ...`, and confirm
   the new hash before the next group. If a hook rewrites files, re-stage
   only that group's changes and retry once, preserving unrelated unstaged
   hunks. If that cannot be done safely or the hook still fails, stop and
   report it, leaving remaining groups uncommitted.
9. Run verification only if permitted, obvious, and finished in seconds.
10. Report in at most eight lines: each hash, message, files, plus leftover.
