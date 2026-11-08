Create one tight Git commit from the current working tree.

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
4. Choose the commit set:
   - If changes are staged, commit exactly that index. Preserve partially
     staged files without adding their unstaged hunks.
   - Otherwise, `git add -- <paths>` for one tight logical change. Leave
     secrets, `.env` files, credentials, build artifacts, and unrelated work
     unstaged. Stop if the chosen set contains secrets or conflict markers.
   Confirm `git --no-pager diff --cached --stat` matches the intended set.
5. Read enough surrounding code to name the change. Run verification only
   if permitted, obvious, and finished in seconds.
6. Message: `type(scope): imperative summary`. Type is one of `feat`, `fix`,
   `refactor`, `docs`, `test`, `build`, `ci`, `perf`, `chore`. Subject under
   72 characters; body only when needed to explain why.
7. Use `git commit -m ...`. If a hook rewrites files, re-stage only this
   commit's changes and retry once, preserving unrelated unstaged hunks.
   If that cannot be done safely or the hook still fails, stop and report it.
8. Report in at most five lines: hash, message, files, leftover.

For multiple concerns, commit the tightest group, leave the rest, and suggest
the atomic-commit hotkey.
