#!/usr/bin/env python3
"""Post review findings to a GitHub PR as a *pending* review (never submitted).

Findings file: JSON array of {"path": "<repo-relative>", "line": <int>, "body": "<markdown>"}.
Findings on a line shown in the PR diff become inline threads; the rest go into
the review body, quoted with their file:line. If you already have a pending
review on the PR, threads are added to it (GitHub allows one per user per PR).

Usage:
  post-pending-review.py --pr 4718 findings.json            # dry run
  post-pending-review.py --pr 4718 findings.json --post
"""

import argparse
import json
import subprocess
import sys


def gh(*args):
    p = subprocess.run(["gh", *args], capture_output=True, text=True)
    if p.returncode:
        sys.exit(f"gh {' '.join(args[:3])}...: {p.stderr.strip()}")
    return p.stdout


def graphql(query, **variables):
    args = ["api", "graphql", "-f", f"query={query}"]
    for k, v in variables.items():
        args += ["-F" if isinstance(v, int) else "-f", f"{k}={v}"]
    data = json.loads(gh(*args))
    if data.get("errors"):
        sys.exit(f"graphql: {data['errors']}")
    return data["data"]


def commentable_lines(diff_text):
    """{path: set(new-side line numbers shown in the diff)}."""
    lines, cur, new_line = {}, None, 0
    for row in diff_text.splitlines():
        if row.startswith("+++ "):
            p = row[4:].strip()
            cur = None if p == "/dev/null" else p.removeprefix("b/")
            if cur:
                lines.setdefault(cur, set())
        elif row.startswith("@@ ") and cur:
            new = next(x for x in row.split(" ") if x.startswith("+"))[1:]
            new_line = int(new.split(",")[0])
        elif cur and row[:1] in (" ", "+"):
            lines[cur].add(new_line)
            new_line += 1
    return lines


PR_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id headRefOid
      reviews(states: PENDING, first: 10) { nodes { id viewerDidAuthor url } }
    }
  }
}"""

ADD_REVIEW = """
mutation($pr: ID!, $commit: GitObjectID!, $body: String!) {
  addPullRequestReview(input: {pullRequestId: $pr, commitOID: $commit, body: $body}) {
    pullRequestReview { id url }
  }
}"""

ADD_THREAD = """
mutation($review: ID!, $path: String!, $line: Int!, $body: String!) {
  addPullRequestReviewThread(input: {pullRequestReviewId: $review, path: $path, line: $line, side: RIGHT, body: $body}) {
    thread { id }
  }
}"""


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("findings", help="JSON findings file")
    ap.add_argument("--pr", required=True, help="PR number")
    ap.add_argument("--repo", default="frame-rnd/frame", help="owner/name")
    ap.add_argument("--post", action="store_true", help="actually post; default is dry run")
    args = ap.parse_args()

    with open(args.findings) as f:
        findings = json.load(f)
    owner, name = args.repo.split("/")
    pr = graphql(PR_QUERY, owner=owner, name=name, number=int(args.pr))["repository"]["pullRequest"]
    shown = commentable_lines(gh("pr", "diff", args.pr, "--repo", args.repo))

    inline = [f for f in findings if f["line"] in shown.get(f["path"], set())]
    outside = [f for f in findings if f not in inline]
    body = "\n\n".join(f"**`{f['path']}:{f['line']}`**\n\n{f['body']}" for f in outside)
    existing = next((r for r in pr["reviews"]["nodes"] if r["viewerDidAuthor"]), None)

    print(f"{'POST' if args.post else 'DRY RUN'}: {len(inline)} inline, {len(outside)} in review body, "
          f"{'adding to existing' if existing else 'new'} pending review")
    for f in inline:
        print(f"  inline  {f['path']}:{f['line']}")
    for f in outside:
        print(f"  body    {f['path']}:{f['line']} (not a diff line)")
    if not args.post:
        return

    if existing:
        review = existing
        if body:
            print("  note: existing review keeps its body; out-of-diff findings were not added", file=sys.stderr)
    else:
        review = graphql(ADD_REVIEW, pr=pr["id"], commit=pr["headRefOid"], body=body)[
            "addPullRequestReview"]["pullRequestReview"]
    for f in inline:
        graphql(ADD_THREAD, review=review["id"], path=f["path"], line=int(f["line"]), body=f["body"])
    print(review["url"])


if __name__ == "__main__":
    main()
