# PR review flow

The agent reviews a PR in its own checkout and leaves every finding as a
comment on a **pending** GitHub review. Only you see it. You triage it next to
the code in octo.nvim and submit it yourself.

## 1. Review in the background

```sh
review-pr 4718          # or the PR URL
```

`scripts/review-pr`, linked into `~/.local/bin`:

1. Prunes `~/worktrees/frame/pr-*` worktrees whose PR is merged or closed when the checkout is clean and pushed. `review-pr --prune` runs only this step.
2. Stops if you already have a pending review on the PR. GitHub allows one per user per PR.
3. Calls `wt switch --no-cd pr:<N>` with `worktree-path` set to `~/worktrees/frame/pr-<N>/frame`. This reuses an existing worktree on the PR branch or creates a new one and runs the `pre-start` hooks to link `.env.local` files and `AGENTS.local.md`, run `pnpm i`, and generate `mkcert` certificates.
4. Runs `claude -p` with the `pr-review` skill at `~/.claude/skills/pr-review/SKILL.md`. The skill fetches the Jira ticket as the spec, runs `code-review`, and writes one self-contained comment per finding.
5. Posts the findings with `scripts/post-pending-review.py`. Comments on lines shown in the diff become inline threads; the rest go into the review body.
6. Sends a macOS notification when the review is ready. Log lives at `~/frame-scratch/pr-reviews/<N>.log`.

You can also paste a PR link into any agent session; the `pr-review` skill runs steps 4 and 5 if you are in the PR's checkout.

## 2. Jump into the PR worktree and triage in nvim

Once the macOS notification arrives, switch to the PR worktree from any shell with `wt switch pr:<N>`, or open it as a Herdr workspace with `prefix+shift+o` or `<Leader>gw`, then open `nvim`:

| Key | Action |
|---|---|
| `<Leader>gpr` | Open the pending review: diff with comment threads |
| `<Leader>gpq` | All pending comments in Trouble |
| `]t` / `[t` | Next / previous thread in the review diff |
| `\cd` | Delete the comment under the cursor |
| `<Leader>gpS` | Submit the review |
| `<Leader>gpX` | Discard the pending review |

Edit a comment in its thread buffer and `:w`. Octo loads threads once; close
the review tab with `<C-c>` and reopen it to see comments added since.
